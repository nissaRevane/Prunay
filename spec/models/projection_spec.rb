require "rails_helper"

RSpec.describe Projection do
  subject(:projection) { described_class.new(simulation) }

  let(:simulation) do
    build(:simulation, purchase_date: Date.new(2025, 3, 10), purchase_price: 200_000, initial_works: 20_000,
                       monthly_rent: 1_000, occupancy_months: 11,
                       property_tax: 700, maintenance: 1_000, insurance: 150, other_charges: 150)
  end

  it "runs over the whole horizon, one line per year, the purchase included" do
    expect(projection.years.size).to eq(described_class::HORIZON_YEARS + 1)
    expect(projection.years.map(&:number)).to eq((0..30).to_a)
  end

  # Le jour de la signature ne porte ni loyer ni charge — rien n'a couru. Il porte ce qu'il est
  # seul à montrer : le capital engagé avant que quoi que ce soit ne le rembourse.
  it "opens on the purchase date, nothing collected and everything immobilized" do
    origin = projection.years.first

    expect(origin.number).to eq(0)
    expect(origin.date).to eq(Date.new(2025, 3, 10))
    expect(origin.annual_rent).to eq(0)
    expect(origin.annual_charges).to eq(0)
    expect(origin.loan_payments).to eq(0)
    expect(origin.taxes).to eq(0)
    expect(origin.cash_flow).to eq(0)
    expect(origin.immobilized_capital).to eq(236_612)
    expect(origin.property_value).to eq(200_000)
  end

  # Les lignes suivantes sont les anniversaires : chacune porte les loyers des douze mois
  # écoulés, et non ceux du jour où elle tombe.
  it "dates each line that follows on an anniversary of the purchase" do
    expect(projection.years[1].date).to eq(Date.new(2026, 3, 10))
    expect(projection.years[2].date).to eq(Date.new(2027, 3, 10))
    expect(projection.years.last.date).to eq(Date.new(2055, 3, 10))
  end

  it "collects the same rent and pays the same charges on every line" do
    expect(projection.years.drop(1).map(&:annual_rent).uniq).to eq([11_000])
    expect(projection.years.drop(1).map(&:annual_charges).uniq).to eq([2_000])
  end

  # Le foyer de la fabrique n'est pas imposé au barème, mais les prélèvements sociaux, eux,
  # ne se choisissent pas : 17,2 % des 7 700 € imposables que laissent 11 000 € de loyers.
  it "taxes the rent excluding charges of every year, allowance deducted" do
    expect(projection.years.drop(1).map(&:taxes).uniq).to eq([BigDecimal("1324.40")])
    expect(projection.total_taxes).to eq(BigDecimal("1324.40") * described_class::HORIZON_YEARS)
  end

  it "is what the charges and the taxes leave of the rent as long as there is no loan" do
    expect(projection.years.drop(1).map(&:cash_flow).uniq).to eq([BigDecimal("7675.60")])
  end

  # Les frais de notaire et les travaux initiaux s'immobilisent avec le prix : ils sont
  # engagés avant le premier loyer, et c'est de leur somme que les cash-flows se déduisent.
  it "deducts the cash flows accumulated since the purchase from the price, the fees and the works" do
    expect(projection.years[1].immobilized_capital).to eq(236_612 - BigDecimal("7675.60"))
    expect(projection.years[2].immobilized_capital).to eq(236_612 - BigDecimal("15351.20"))
    expect(projection.years.last.immobilized_capital).to eq(236_612 - BigDecimal("230268.00"))
  end

  # Le capital revient d'autant plus tard que l'impôt en prend sa part : à 1 000 € de loyer
  # mensuel il ne revient plus dans l'horizon, et il faut 1 600 € pour le ramener — 13 480,96 €
  # par an, soit dix-huit années pour couvrir les 236 612 € engagés.
  it "marks a line as recovered once the capital has come back" do
    recovering = described_class.new(build(:simulation, purchase_price: 200_000, initial_works: 20_000,
                                                        monthly_rent: 1_600, occupancy_months: 11,
                                                        property_tax: 700, maintenance: 1_000,
                                                        insurance: 150, other_charges: 150))

    expect(recovering.years.select(&:recovered?).first.number).to eq(18)
    expect(recovering.years.take(18).map(&:recovered?)).to all(be(false))
  end

  # Le crédit pèse sur chaque année tant qu'il court, et cesse de peser le jour où il est
  # soldé : une projection de trente ans porte vingt annuités d'un prêt de vingt ans.
  describe "of a purchase financed by a credit" do
    subject(:projection) { described_class.new(simulation) }

    let(:simulation) do
      build(:simulation, :with_credit, purchase_price: 200_000, initial_works: 0, down_payment: 23_388,
                                       monthly_rent: 800, occupancy_months: 12)
    end

    it "deducts the annuity from the cash flow for as long as the loan runs" do
      expect(projection.years[1].loan_payments).to eq(BigDecimal("1071.62") * 12)
      expect(projection.years[1].cash_flow)
        .to eq(9_600 - BigDecimal("1155.84") - BigDecimal("1071.62") * 12)
    end

    it "stops deducting anything once the loan is cleared" do
      expect(projection.years[20].loan_payments).to be_positive
      expect(projection.years[21].loan_payments).to eq(0)
      # Le crédit soldé, il ne reste que l'impôt sur les 9 600 € de loyers.
      expect(projection.years[21].cash_flow).to eq(9_600 - BigDecimal("1155.84"))
    end

    # L'apport seul est immobilisé le premier jour, et les annuités le creusent avant que les
    # loyers ne le comblent.
    it "starts from the down payment and not from the whole project" do
      expect(projection.years.first.immobilized_capital).to eq(23_388)
      expect(projection.years[1].immobilized_capital).to eq(23_388 - projection.years[1].cash_flow)
    end
  end

  # Les conditions économiques composent la projection année après année : les loyers
  # progressent, les charges suivent l'inflation, et le bien prend de la valeur.
  describe "under evolving economic conditions" do
    subject(:projection) { described_class.new(simulation) }

    let(:simulation) do
      build(:simulation, purchase_price: 200_000, monthly_rent: 1_000, occupancy_months: 12,
                         property_tax: 1_000, rent_growth_rate: 2, inflation_rate: 3,
                         property_growth_rate: 1, marginal_tax_rate: 30)
    end

    # La première année porte le loyer saisi : elle décrit les douze mois qui suivent l'achat.
    it "raises the rent from the second year on" do
      expect(projection.years[1].annual_rent).to eq(12_000)
      expect(projection.years[2].annual_rent).to eq(12_240)
      expect(projection.years[3].annual_rent).to eq(BigDecimal("12484.80"))
    end

    # L'assiette progresse comme le loyer, et l'impôt avec elle : 12 000 € puis 12 240 € de
    # loyers hors charges, dont 70 % supportent 30 % de barème et 17,2 % de prélèvements.
    it "taxes an assessment that grows with the rent" do
      expect(projection.years[1].taxes).to eq(BigDecimal("3964.80"))
      expect(projection.years[2].taxes).to eq(BigDecimal("4044.10"))
    end

    it "lets the inflation weigh on the charges the same way" do
      expect(projection.years[1].annual_charges).to eq(1_000)
      expect(projection.years[2].annual_charges).to eq(1_030)
      expect(projection.years[3].annual_charges).to eq(BigDecimal("1060.90"))
    end

    # Une valeur à une date, non un montant encaissé sur une période : le jour de l'achat le
    # bien vaut son prix, et au premier anniversaire il a déjà pris son année.
    it "values the property from its price alone, a year gained on each anniversary" do
      expect(projection.years.first.property_value).to eq(200_000)
      expect(projection.years[1].property_value).to eq(202_000)
      expect(projection.years[2].property_value).to eq(204_020)
      expect(projection.final_property_value).to eq(projection.years.last.property_value)
    end

    it "adds up what the years actually collected and paid" do
      expect(projection.total_rent).to eq(projection.years.sum(&:annual_rent))
      expect(projection.total_charges).to eq(projection.years.sum(&:annual_charges))
      expect(projection.total_rent).to be > 12_000 * described_class::HORIZON_YEARS
    end
  end

  # Des taux à zéro rendent les années égales entre elles : c'est ce que le reste des exemples
  # suppose, et ce que la fabrique pose.
  it "keeps every line equal when nothing evolves" do
    expect(projection.years.drop(1).map(&:annual_rent).uniq.size).to eq(1)
    expect(projection.years.map(&:property_value).uniq).to eq([200_000])
  end

  # La provision pour charges est encaissée avec le loyer, mais elle ne rembourse qu'une
  # dépense : elle grossit le cash-flow, jamais l'assiette de l'impôt.
  it "collects the provision for charges without taxing it" do
    with_provision = described_class.new(build(:simulation, monthly_rent: 800, monthly_charges: 100,
                                                            occupancy_months: 12))

    expect(with_provision.years[1].annual_rent).to eq(10_800)
    expect(with_provision.years[1].taxes).to eq(BigDecimal("1155.84"))
  end

  it "keeps a 29 February purchase on a real date" do
    leap = described_class.new(build(:simulation, purchase_date: Date.new(2024, 2, 29)))

    expect(leap.years.first.date).to eq(Date.new(2024, 2, 29))
    expect(leap.years[1].date).to eq(Date.new(2025, 2, 28))
  end

  describe "#final_immobilized_capital" do
    it "is what the last line shows" do
      expect(projection.final_immobilized_capital).to eq(projection.years.last.immobilized_capital)
    end
  end

  # Le cumul se lit sur les lignes et ne se multiplie plus : un crédit qui s'éteint avant
  # l'horizon rend les années inégales entre elles. L'année zéro n'y ajoute rien.
  describe "#total_cash_flow" do
    it "adds up every line" do
      expect(projection.total_cash_flow).to eq(BigDecimal("7675.60") * 30)
    end
  end
end
