require "rails_helper"

RSpec.describe Projection do
  subject(:projection) { described_class.new(simulation, :micro_foncier) }

  let(:simulation) do
    build(:simulation, purchase_date: Date.new(2025, 3, 10), purchase_price: 200_000, initial_works: 20_000,
                       monthly_rent: 1_000, occupancy_months: 11,
                       property_tax: 700, maintenance: 1_000, insurance: 150, other_charges: 150)
  end

  it "runs over the whole horizon, one line per year, the purchase included" do
    expect(projection.years.size).to eq(described_class::HORIZON_YEARS + 1)
    expect(projection.years.map(&:number)).to eq((0..30).to_a)
  end

  # Le jour de la signature ne porte que le capital engagé : rien n'a encore couru.
  it "opens on the purchase date, nothing collected and everything immobilized" do
    origin = projection.years.first

    expect(origin.number).to eq(0)
    expect(origin.date).to eq(Date.new(2025, 3, 10))
    expect(origin.rent_excluding_charges).to eq(0)
    expect(origin.charges_excluding_provision).to eq(0)
    expect(origin.loan_payments).to eq(0)
    expect(origin.taxes).to eq(0)
    expect(origin.cash_flow).to eq(0)
    expect(origin.immobilized_capital).to eq(236_612)
    expect(origin.property_value).to eq(200_000)
  end

  # Une année se lit par son numéro et non par son rang : l'année zéro occupe la première place.
  it "gives back a year by its number" do
    expect(projection.year(15).number).to eq(15)
    expect(projection.year(0).date).to eq(Date.new(2025, 3, 10))
  end

  # Chaque anniversaire porte les loyers des douze mois écoulés, et non ceux du jour où il tombe.
  it "dates each line that follows on an anniversary of the purchase" do
    expect(projection.years[1].date).to eq(Date.new(2026, 3, 10))
    expect(projection.years[2].date).to eq(Date.new(2027, 3, 10))
    expect(projection.years.last.date).to eq(Date.new(2055, 3, 10))
  end

  it "collects the same rent and pays the same charges on every line" do
    expect(projection.years.drop(1).map(&:rent_excluding_charges).uniq).to eq([11_000])
    expect(projection.years.drop(1).map(&:charges_excluding_provision).uniq).to eq([2_000])
  end

  # Le barème n'atteint pas ce foyer : 17,2 % des 7 700 € imposables que laissent 11 000 € de loyers.
  it "taxes the rent excluding charges of every year, allowance deducted" do
    expect(projection.years.drop(1).map(&:taxes).uniq).to eq([BigDecimal("1324.40")])
    expect(projection.total_taxes).to eq(BigDecimal("1324.40") * described_class::HORIZON_YEARS)
  end

  it "is what the charges and the taxes leave of the rent as long as there is no loan" do
    expect(projection.years.drop(1).map(&:cash_flow).uniq).to eq([BigDecimal("7675.60")])
  end

  # Frais de notaire et travaux s'immobilisent avec le prix : les cash-flows se déduisent de leur somme.
  it "deducts the cash flows accumulated since the purchase from the price, the fees and the works" do
    expect(projection.years[1].immobilized_capital).to eq(236_612 - BigDecimal("7675.60"))
    expect(projection.years[2].immobilized_capital).to eq(236_612 - BigDecimal("15351.20"))
    expect(projection.years.last.immobilized_capital).to eq(236_612 - BigDecimal("230268.00"))
  end

  # À 1 600 € par mois, 13 480,96 € par an : dix-huit années pour couvrir les 236 612 € engagés.
  it "marks a line as recovered once the capital has come back" do
    recovering = described_class.new(build(:simulation, purchase_price: 200_000, initial_works: 20_000,
                                                        monthly_rent: 1_600, occupancy_months: 11,
                                                        property_tax: 700, maintenance: 1_000,
                                                        insurance: 150, other_charges: 150),
                                     :micro_foncier)

    expect(recovering.years.select(&:recovered?).first.number).to eq(18)
    expect(recovering.years.take(18).map(&:recovered?)).to all(be(false))
  end

  # Une projection de trente ans porte les vingt annuités d'un prêt de vingt ans, et rien après.
  describe "of a purchase financed by a credit" do
    subject(:projection) { described_class.new(simulation, :micro_foncier) }

    let(:simulation) do
      build(:simulation, :with_credit, purchase_price: 200_000, initial_works: 0, down_payment: 23_388,
                                       monthly_rent: 800, occupancy_months: 12)
    end

    it "deducts the annuity from the cash flow for as long as the loan runs" do
      expect(projection.years[1].loan_payments).to eq(BigDecimal("1071.62") * 12)
      expect(projection.years[1].cash_flow)
        .to eq(9_600 - BigDecimal("1155.84") - BigDecimal("1071.62") * 12)
    end

    # Intérêts et prime entament le résultat avant impôt ; le capital rendu ne se lit qu'au cash-flow.
    it "charges the interest to the pre-tax result and the capital to the cash flow alone" do
      year = projection.years[1]

      expect(year.loan_interest + year.capital_repayment).to eq(year.loan_payments)
      expect(year.pre_tax_result).to eq(9_600 - year.loan_interest)
      expect(year.net_result).to eq(year.pre_tax_result - BigDecimal("1155.84"))
      expect(year.cash_flow).to eq(year.net_result - year.capital_repayment)
    end

    it "stops deducting anything once the loan is cleared" do
      expect(projection.years[20].loan_payments).to be_positive
      expect(projection.years[21].loan_payments).to eq(0)
      # Le crédit soldé, il ne reste que l'impôt sur les 9 600 € de loyers.
      expect(projection.years[21].cash_flow).to eq(9_600 - BigDecimal("1155.84"))
    end

    # L'apport seul est immobilisé le premier jour : le capital emprunté se rend par les annuités.
    it "starts from the down payment and not from the whole project" do
      expect(projection.years.first.immobilized_capital).to eq(23_388)
      expect(projection.years[1].immobilized_capital).to eq(23_388 - projection.years[1].cash_flow)
    end

    # Le jour de la signature la revente solderait tout le prêt ; le crédit éteint, plus rien.
    it "would have to clear the whole loan on the day it is signed, and nothing once it is over" do
      expect(projection.years.first.remaining_loan_capital).to eq(simulation.borrowed_capital)
      expect(projection.years[20].remaining_loan_capital).to eq(0)
      expect(projection.years[21].remaining_loan_capital).to eq(0)
    end

    # Vingt-quatre échéances passées, il reste à solder ce que les deux premières annuités n'ont pas rendu.
    it "owes what the annual principal has not yet repaid" do
      repaid = projection.years[1].capital_repayment + projection.years[2].capital_repayment

      expect(projection.years[2].remaining_loan_capital).to eq(simulation.borrowed_capital - repaid)
    end

    # Le prix ne bougeant pas, la revente ne rapporte que ce que le crédit a déjà remboursé, frais déduits.
    it "sells for the market price less what is still owed, and profits by what is not immobilized" do
      year = projection.years[2]

      # 178 684,91 € restant dus : à 3 % l'an, six mois d'intérêts plafonnent l'indemnité à 1,5 %.
      expect(year.remaining_loan_capital).to eq(BigDecimal("178_684.91"))
      expect(year.early_repayment_fee).to eq(BigDecimal("2680.27"))
      expect(year.sale_proceeds)
        .to eq(200_000 - 900 - BigDecimal("178_684.91") - BigDecimal("2680.27"))
      expect(year.sale_profit).to eq(year.sale_proceeds - year.immobilized_capital)
    end

    # Indemnité négociée à la signature : la revente ne rend que le capital restant dû.
    it "keeps the indemnity out of the sale when the loan waives it" do
      simulation.early_repayment_fee = false
      year = projection.years[2]

      expect(year.early_repayment_fee).to eq(0)
      expect(year.sale_proceeds).to eq(200_000 - 900 - BigDecimal("178_684.91"))
    end
  end

  # Le réel déduit les charges et les intérêts là où le micro-foncier applique son forfait.
  describe "under the foncier réel regime" do
    subject(:projection) { described_class.new(simulation, :foncier_reel) }

    # 11 000 € moins 2 000 € de charges : 9 000 € à 17,2 %, plus cher que les 1 324,40 € du forfait.
    it "taxes what the real charges leave of the rent, where the forfait ignored them" do
      expect(projection.years[1].taxes).to eq(1_548)
      expect(projection.years[1].cash_flow).to eq(7_452)
    end

    # Tout le régime est là : les charges de l'année et ses intérêts, ôtés du loyer hors charges.
    it "taxes what the charges and the loan interest leave of the rent excluding charges" do
      on_credit = build(:simulation, :with_credit, monthly_rent: 800, occupancy_months: 12,
                                                   property_tax: 700)
      year = described_class.new(on_credit, :foncier_reel).years[1]
      taxable = on_credit.annual_rent_excluding_charges - year.charges_excluding_provision - year.loan_interest

      expect(taxable).to be_positive
      expect(year.taxes).to eq((taxable * Taxation::SOCIAL_CHARGES_RATE / 100).round(2))
    end

    # La provision rembourse une dépense : ni l'une ni l'autre ne se déclarent.
    it "deducts neither the provision for charges nor what it reimburses" do
      with_provision = described_class.new(build(:simulation, monthly_rent: 800, monthly_charges: 100,
                                                              occupancy_months: 12, condominium: true,
                                                              condominium_fees: 1_200), :foncier_reel)
      year = with_provision.years[1]

      # La provision couvre exactement les charges de copropriété : il ne reste rien à déduire.
      expect(year.charges_excluding_provision).to eq(0)
      expect(year.pre_tax_result).to eq(9_600)
      expect(year.taxes).to eq(BigDecimal("1651.20"))
    end

    # Une provision qu'aucune dépense ne justifie allège les charges au-delà de zéro : l'assiette grossit.
    it "taxes a provision that no charge reimburses" do
      unjustified = described_class.new(build(:simulation, monthly_rent: 800, monthly_charges: 100,
                                                           occupancy_months: 12), :foncier_reel)
      year = unjustified.years[1]

      expect(year.charges_excluding_provision).to eq(-1_200)
      expect(year.taxes).to eq(BigDecimal("1857.60"))
    end

    # Un déficit foncier ne se reporte pas : l'année qui n'a rien gagné ne doit rien.
    it "asks nothing of a year its charges and its interest have swallowed" do
      loss_making = described_class.new(build(:simulation, :with_credit, monthly_rent: 800,
                                                                        occupancy_months: 12,
                                                                        property_tax: 5_000), :foncier_reel)

      expect(loss_making.years[1].pre_tax_result).to be_negative
      expect(loss_making.years[1].taxes).to eq(0)
    end
  end

  # La moitié des recettes imposée, provision comprise, 18,6 % de prélèvements sociaux, et la CFE
  # rangée dans les charges de l'année.
  describe "under the micro-BIC regime" do
    subject(:projection) { described_class.new(simulation, :micro_bic) }

    # 5 500 € imposables à 18,6 % font 1 023 € : l'impôt de l'année, la CFE mise à part.
    it "taxes half of the receipts, where the micro-foncier left seventy per cent of the rent" do
      expect(projection.years[1].taxes).to eq(1_023)
    end

    # 300 € de CFE, qui pèsent sur les charges et non sur l'impôt : 2 000 € de charges deviennent 2 300 €.
    it "counts the business tax with the charges of the year and not with the tax" do
      year = projection.years[1]

      expect(year.business_tax).to eq(300)
      expect(year.charges_excluding_provision).to eq(2_300)
      expect(year.pre_tax_result).to eq(8_700)
      expect(year.cash_flow).to eq(7_677)
    end

    # 30 % d'un loyer mensuel qui progresse comme lui : 240 € la première année, 244,80 € la seconde.
    it "asks for a business tax that follows the rent through its growth" do
      growing = described_class.new(build(:simulation, monthly_rent: 800, occupancy_months: 12,
                                                       rent_growth_rate: 2), :micro_bic)

      expect(growing.years[1].business_tax).to eq(240)
      expect(growing.years[2].business_tax).to eq(BigDecimal("244.80"))
    end

    # 1 200 € de provision comptés en recettes : 600 € d'assiette de plus, et 111,60 € d'impôt.
    it "taxes the provision for charges that the foncier leaves out of the assessment" do
      with_provision = build(:simulation, monthly_rent: 800, monthly_charges: 100, occupancy_months: 12,
                                          condominium: true, condominium_fees: 1_200)
      rent_only = build(:simulation, monthly_rent: 800, occupancy_months: 12)

      expect(described_class.new(with_provision, :micro_bic).years[1].taxes).to eq(BigDecimal("1004.40"))
      expect(described_class.new(rent_only, :micro_bic).years[1].taxes).to eq(BigDecimal("892.80"))
    end

    # Ce que le meublé déclare : 10 800 € encaissés et 1 740 € de charges, CFE de 240 € comprise.
    it "reads the year charges included, the provision on both sides" do
      furnished = described_class.new(build(:simulation, monthly_rent: 800, monthly_charges: 100,
                                                        occupancy_months: 12, condominium: true,
                                                        condominium_fees: 1_500), :micro_bic)
      year = furnished.years[1]

      expect(furnished.rent_column).to eq("annual_rent_including_charges_column")
      expect(furnished.rent_of(year)).to eq(10_800)
      expect(furnished.charges_of(year)).to eq(1_740)
      # Les deux lectures d'une même année laissent le même résultat avant impôt.
      expect(furnished.rent_of(year) - furnished.charges_of(year)).to eq(year.pre_tax_result)
    end

    # La provision suit l'inflation : 1 236 € la deuxième année, dont la moitié entre dans l'assiette.
    it "follows the provision through the inflation into the assessment" do
      indexed = described_class.new(build(:simulation, monthly_rent: 800, monthly_charges: 100,
                                                      occupancy_months: 12, inflation_rate: 3), :micro_bic)
      year = indexed.years[2]

      expect(year.provision_for_charges).to eq(1_236)
      expect(year.taxes).to eq(BigDecimal("1007.75"))
    end
  end

  # Les loyers progressent, les charges suivent l'inflation, et le bien prend de la valeur.
  describe "under evolving economic conditions" do
    subject(:projection) { described_class.new(simulation, :micro_foncier) }

    let(:simulation) do
      build(:simulation, purchase_price: 200_000, monthly_rent: 1_000, occupancy_months: 12,
                         property_tax: 1_000, rent_growth_rate: 2, inflation_rate: 3,
                         property_growth_rate: 1, marginal_tax_rate: 30)
    end

    # La première année porte le loyer saisi : elle décrit les douze mois qui suivent l'achat.
    it "raises the rent from the second year on" do
      expect(projection.years[1].rent_excluding_charges).to eq(12_000)
      expect(projection.years[2].rent_excluding_charges).to eq(12_240)
      expect(projection.years[3].rent_excluding_charges).to eq(BigDecimal("12484.80"))
    end

    # 12 000 € puis 12 240 € de loyers, dont 70 % supportent 30 % de barème et 17,2 % de prélèvements.
    it "taxes an assessment that grows with the rent" do
      expect(projection.years[1].taxes).to eq(BigDecimal("3964.80"))
      expect(projection.years[2].taxes).to eq(BigDecimal("4044.10"))
    end

    it "lets the inflation weigh on the charges the same way" do
      expect(projection.years[1].charges_excluding_provision).to eq(1_000)
      expect(projection.years[2].charges_excluding_provision).to eq(1_030)
      expect(projection.years[3].charges_excluding_provision).to eq(BigDecimal("1060.90"))
    end

    # Une valeur à une date : au premier anniversaire le bien a déjà pris son année.
    it "values the property from its price alone, a year gained on each anniversary" do
      expect(projection.years.first.property_value).to eq(200_000)
      expect(projection.years[1].property_value).to eq(202_000)
      expect(projection.years[2].property_value).to eq(204_020)
      expect(projection.final_property_value).to eq(projection.years.last.property_value)
    end

    it "adds up what the years actually collected and paid" do
      expect(projection.total_rent).to eq(projection.years.sum(&:rent_excluding_charges))
      expect(projection.total_charges).to eq(projection.years.sum(&:charges_excluding_provision))
      expect(projection.total_rent).to be > 12_000 * described_class::HORIZON_YEARS
    end
  end

  # Des taux à zéro rendent les années égales : c'est ce que la fabrique pose.
  it "keeps every line equal when nothing evolves" do
    expect(projection.years.drop(1).map(&:rent_excluding_charges).uniq.size).to eq(1)
    expect(projection.years.map(&:property_value).uniq).to eq([200_000])
  end

  # Le loyer déclaré ne compte pas la provision, et les charges déclarées la retranchent.
  it "declares neither the provision for charges nor what it reimburses" do
    with_provision = described_class.new(build(:simulation, monthly_rent: 800, monthly_charges: 100,
                                                            occupancy_months: 12, condominium: true,
                                                            condominium_fees: 1_500), :micro_foncier)
    year = with_provision.years[1]

    expect(year).to have_attributes(rent_excluding_charges: 9_600, provision_for_charges: 1_200,
                                    charges_excluding_provision: 300)
    # 10 800 € encaissés moins 1 500 € de charges réelles : le solde reste celui du brut.
    expect(year.pre_tax_result).to eq(9_300)
    expect(year.taxes).to eq(BigDecimal("1155.84"))
  end

  it "keeps a 29 February purchase on a real date" do
    leap = described_class.new(build(:simulation, purchase_date: Date.new(2024, 2, 29)), :micro_foncier)

    expect(leap.years.first.date).to eq(Date.new(2024, 2, 29))
    expect(leap.years[1].date).to eq(Date.new(2025, 2, 28))
  end

  # Comptant, pas de banque à solder : le jour de l'achat les 236 612 € engagés dépassent de 36 612 € un bien à 200 000.
  # 50 m² hors copropriété : 400 € de diagnostics et 500 € de remise en état s'y ajoutent.
  describe "a sale simulated from a year" do
    it "owes nothing to a bank when the purchase was paid in cash" do
      origin = projection.years.first

      expect(origin.remaining_loan_capital).to eq(0)
      expect(origin.sale_costs).to eq(900)
      expect(origin.early_repayment_fee).to eq(0)
      expect(origin.sale_proceeds).to eq(199_100)
      expect(origin.sale_profit).to eq(-37_512)
    end

    # 3 % l'an sur dix ans : la plus-value ainsi faite est imposée, et la revente ne rend que le reste.
    it "sells at the price the year gives the property, the capital gain taxed" do
      growing = described_class.new(build(:simulation, purchase_price: 200_000, property_growth_rate: 3),
                                    :micro_foncier)
      year = growing.years[10]

      expect(year.property_value).to eq(BigDecimal("268_783.28"))
      expect(year.capital_gain_tax).to eq(BigDecimal("6447.63"))
      expect(year.sale_proceeds).to eq(BigDecimal("261_435.65"))
      expect(year.sale_profit).to eq(BigDecimal("261_435.65") - year.immobilized_capital)
    end

    # 200 000 € payés et 16 612 € de frais, plus 30 000 € de travaux forfaitaires dès la sixième année.
    it "wipes the gain out on the sixth year, when the flat works join the fiscal value" do
      growing = described_class.new(build(:simulation, purchase_price: 200_000, property_growth_rate: 3),
                                    :micro_foncier)

      expect(growing.years[5].property_value).to eq(BigDecimal("231_854.81"))
      expect(growing.years[5].capital_gain).to eq(BigDecimal("15242.81"))
      expect(growing.years[5].capital_gain_tax).to eq(BigDecimal("5517.89"))
      expect(growing.years[6].property_value).to eq(BigDecimal("238_810.46"))
      expect(growing.years[6].capital_gain).to eq(0)
      expect(growing.years[6].capital_gain_tax).to eq(0)
    end

    # 2 % d'inflation : les 900 € de frais d'aujourd'hui en valent 1 097,09 € à la dixième année.
    it "inflates the sale costs like every other expense" do
      inflating = described_class.new(build(:simulation, inflation_rate: 2), :micro_foncier)

      expect(inflating.years.first.sale_costs).to eq(900)
      expect(inflating.years[10].sale_costs).to eq(BigDecimal("1097.09"))
    end

    # L'état daté, que le syndic facture au vendeur, s'ajoute aux 900 € des autres frais.
    it "adds the condominium statement to the costs of an apartment in a condominium" do
      condominium = described_class.new(build(:simulation, condominium: true), :micro_foncier)

      expect(condominium.years.first.sale_costs).to eq(1_280)
    end

    # Trente ans de détention : l'abattement a tout effacé, barème comme prélèvements sociaux.
    it "taxes nothing of a gain the thirty years held have entirely abated" do
      growing = described_class.new(build(:simulation, purchase_price: 200_000, property_growth_rate: 3),
                                    :micro_foncier)
      year = growing.years.last

      expect(year.capital_gain).to be_positive
      expect(year.capital_gain_tax).to eq(0)
      expect(year.sale_proceeds).to eq(year.property_value - 900)
    end
  end

  describe "#final_immobilized_capital" do
    it "is what the last line shows" do
      expect(projection.final_immobilized_capital).to eq(projection.years.last.immobilized_capital)
    end
  end

  # Un crédit qui s'éteint avant l'horizon rend les années inégales : le cumul se lit sur les lignes.
  describe "#total_cash_flow" do
    it "adds up every line" do
      expect(projection.total_cash_flow).to eq(BigDecimal("7675.60") * 30)
    end
  end
end
