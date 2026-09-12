require "rails_helper"

RSpec.describe Simulation, type: :model do
  # Chaque page est un contexte de validation : elle ne juge que ses propres champs.
  describe "validations" do
    it { is_expected.to validate_presence_of(:city).on(:property) }
    it { is_expected.to validate_numericality_of(:surface).is_greater_than(0).on(:property) }
    it { is_expected.to validate_inclusion_of(:property_type).in_array(described_class::PROPERTY_TYPES).on(:property) }
    it { is_expected.to validate_inclusion_of(:energy_rating).in_array(described_class::ENERGY_RATINGS).allow_blank.on(:property) }

    it { is_expected.to validate_presence_of(:purchase_date).on(:purchase) }
    it { is_expected.to validate_numericality_of(:purchase_price).is_greater_than(0).on(:purchase) }
    it { is_expected.to validate_numericality_of(:initial_works).is_greater_than_or_equal_to(0).on(:purchase) }
    it { is_expected.to validate_numericality_of(:furniture).is_greater_than_or_equal_to(0).on(:purchase) }

    # Sans crédit la page n'existe pas : apport, taux et durée sont remis à zéro avant validation.
    context "of a purchase financed by a credit" do
      subject { build(:simulation, :with_credit) }

      it { is_expected.to validate_numericality_of(:down_payment).is_greater_than_or_equal_to(0).on(:purchase) }
      it { is_expected.to validate_numericality_of(:loan_rate).is_greater_than_or_equal_to(0).is_less_than(100).on(:credit) }
      it { is_expected.to validate_numericality_of(:loan_duration_years).only_integer.is_greater_than(0).on(:credit) }
      it { is_expected.to validate_numericality_of(:loan_insurance).is_greater_than_or_equal_to(0).on(:credit) }
      it { is_expected.to validate_numericality_of(:loan_guarantee_fees).is_greater_than_or_equal_to(0).on(:credit) }
      it { is_expected.to validate_numericality_of(:loan_application_fees).is_greater_than_or_equal_to(0).on(:credit) }

      # Un apport qui couvrirait tout le projet ne laisserait rien à emprunter.
      it "refuses a down payment that leaves nothing to borrow" do
        simulation = build(:simulation, :with_credit, purchase_price: 200_000, initial_works: 0,
                                                      down_payment: 216_612)

        expect(simulation).not_to be_valid(:purchase)
        expect(simulation.errors[:down_payment]).to be_present
      end
    end

    # Chaque carte de la liste coûte le balayage des quatre régimes : un compte a sa limite.
    context "of an account already at its quota" do
      let(:user) { create(:user) }

      before do
        stub_const("Simulation::MAX_PER_USER", 2)
        2.times { create(:simulation, user: user) }
      end

      it "refuses one more simulation" do
        simulation = build(:simulation, user: user)

        expect(simulation).not_to be_valid
        expect(simulation.errors[:base])
          .to eq(["Vous avez atteint la limite de 2 simulations : supprimez-en une pour en ajouter une autre."])
      end

      # La limite ne vaut qu'à la création : un chiffre de la fiche se corrige toujours.
      it "still lets an existing simulation be corrected" do
        expect(user.simulations.first.update(monthly_rent: 900)).to be(true)
      end
    end

    it "asks nothing of the credit of a purchase paid outright" do
      expect(build(:simulation, credit: false, loan_rate: 0, loan_duration_years: 0)).to be_valid(:credit)
    end

    it { is_expected.to validate_numericality_of(:monthly_rent).is_greater_than_or_equal_to(0).on(:rental) }
    it { is_expected.to validate_numericality_of(:monthly_charges).is_greater_than_or_equal_to(0).on(:rental) }
    it { is_expected.to validate_numericality_of(:occupancy_months).is_greater_than(0).is_less_than_or_equal_to(12).on(:rental) }

    it { is_expected.to validate_numericality_of(:property_tax).is_greater_than_or_equal_to(0).on(:charges) }

    it { is_expected.to validate_numericality_of(:purchase_discount).is_greater_than_or_equal_to(0).on(:update) }

    # La tranche marginale se choisit dans le barème : un taux inventé n'y a pas de place.
    it { is_expected.to validate_inclusion_of(:marginal_tax_rate).in_array(Taxation::MARGINAL_TAX_RATES).on(:update) }

    it "leaves the pages that have not been reached alone" do
      draft = described_class.new(user: build(:user), property_type: "house", city: "Nantes", surface: 50)

      expect(draft).to be_valid(:property)
      expect(draft).not_to be_valid(:purchase)
    end

    # Une simulation enregistrée, elle, doit avoir traversé les quatre pages.
    it "demands every page at once when the record is saved" do
      draft = described_class.new(user: build(:user), property_type: "house", city: "Nantes", surface: 50)

      expect(draft).not_to be_valid
    end
  end

  # La page du crédit ne s'ouvre qu'à qui en a coché un sur la page de l'achat.
  describe "#steps" do
    it "walks the credit page only when there is a credit" do
      expect(build(:simulation, :with_credit).steps).to eq(%w[property purchase credit rental charges])
      expect(build(:simulation, credit: false).steps).to eq(%w[property purchase rental charges])
    end
  end

  # Personne ne nomme une simulation : elle se lit sur son bien, et rien n'est stocké.
  describe "#name" do
    # L'icône du type, cinq lettres de ville et la surface : de quoi s'y retrouver en un coup d'œil.
    it "reads the property itself" do
      simulation = build(:simulation, property_type: "house", city: "Rennes", surface: 62.5)

      expect(simulation.name).to eq("🏠 Renne-63")
    end

    # Une ville longue s'arrête à sa cinquième lettre, et chaque type porte son icône.
    it "cuts a long city name and marks the kind of property" do
      simulation = build(:simulation, property_type: "apartment",
                         city: "Saint-Étienne-du-Rouvray", surface: 71)

      expect(simulation.name).to eq("🏢 Saint-71")
    end
  end

  describe "#annual_rent" do
    # Onze mois loués ne font pas douze loyers : la vacance locative se paie.
    it "counts only the months actually let" do
      expect(build(:simulation, monthly_rent: 800, occupancy_months: 11).annual_rent).to eq(8_800)
    end

    # La provision est encaissée avec le loyer et compte dans le cash-flow : 800 + 60, onze fois.
    it "collects the provision for charges next to the rent" do
      let_out = build(:simulation, monthly_rent: 800, monthly_charges: 60, occupancy_months: 11)

      expect(let_out.annual_rent).to eq(9_460)
    end
  end

  # L'assiette de l'impôt, et rien d'autre : la provision pour charges n'en fait pas partie.
  describe "#annual_rent_excluding_charges" do
    it "counts the rent alone, the provision for charges left out" do
      let_out = build(:simulation, monthly_rent: 800, monthly_charges: 60, occupancy_months: 11)

      expect(let_out.annual_rent_excluding_charges).to eq(8_800)
    end
  end

  # Un meublé se loue 5 % plus cher qu'un nu : les deux régimes du meublé en tiennent compte.
  describe "#monthly_rent_under" do
    let(:simulation) { build(:simulation, monthly_rent: 800, occupancy_months: 11) }

    it "leaves the entered rent to the bare regimes" do
      expect(simulation.monthly_rent_under(:micro_foncier)).to eq(800)
      expect(simulation.annual_rent_excluding_charges_under(:foncier_reel)).to eq(8_800)
    end

    # 800 € majorés de 5 % font 840 €, et onze mois loués 9 240 €.
    it "adds the furnished premium under the micro-BIC and the LMNP" do
      expect(simulation.monthly_rent_under(:micro_bic)).to eq(840)
      expect(simulation.monthly_rent_under(:lmnp)).to eq(840)
      expect(simulation.annual_rent_excluding_charges_under(:lmnp)).to eq(9_240)
    end
  end

  # La simulation ne fait que passer aux régimes son assiette, ses charges, ses intérêts et sa tranche.
  describe "#annual_taxes" do
    it "taxes the rent excluding charges at the bracket of the household" do
      taxed = build(:simulation, monthly_rent: 1_000, monthly_charges: 100, occupancy_months: 12,
                                 marginal_tax_rate: 30)

      # 12 000 € de loyers hors charges, 8 400 € imposables après abattement, 47,2 % dessus.
      expect(taxed.taxation).to have_attributes(rent_excluding_charges: 12_000, taxable_income: 8_400)
      expect(taxed.annual_taxes).to eq(BigDecimal("3964.80"))
    end

    # Les prélèvements sociaux ne se choisissent pas : 12,04 % des loyers restent dus.
    it "still owes the social charges when the bracket is nil" do
      expect(build(:simulation, monthly_rent: 1_000, occupancy_months: 12, marginal_tax_rate: 0).annual_taxes)
        .to eq(BigDecimal("1444.80"))
    end

    # Le forfait ignore ce que l'année a dépensé ; le réel déduit charges et intérêts.
    it "deducts the real charges and the loan interest where the forfait does not" do
      on_credit = build(:simulation, :with_credit, monthly_rent: 1_000, occupancy_months: 12,
                                                  property_tax: 700)

      expect(on_credit.taxation(:foncier_reel).taxable_income)
        .to eq(12_000 - 700 - on_credit.loan.annual_interest.fetch(1))
      expect(on_credit.annual_taxes(:foncier_reel)).to be < on_credit.annual_taxes
    end
  end

  describe "#annual_charges" do
    it "adds up every charge the property carries" do
      simulation = build(:simulation, property_tax: 700, insurance: 150, maintenance: 1_000,
                                      condominium_fees: 1_200, management_fees: 600, rent_guarantee: 300,
                                      other_charges: 100)

      expect(simulation.annual_charges).to eq(4_050)
    end
  end

  # 30 % d'un loyer meublé de 840 €, que le total des charges saisies ne compte pas.
  describe "#annual_business_tax" do
    it "reads the CFE off the furnished regime and leaves the entered charges alone" do
      simulation = build(:simulation, monthly_rent: 800, property_tax: 700)

      expect(simulation.annual_business_tax).to eq(252)
      expect(simulation.annual_charges).to eq(700)
    end
  end

  describe "#notary_fees" do
    # 7,42 % de 200 000 € font 14 840 €, que la part fixe porte à 16 612 €.
    it "is a share of the price raised by a fixed part" do
      expect(build(:simulation, purchase_price: 200_000).notary_fees).to eq(16_612)
    end

    it "follows the price and nothing else" do
      expect(build(:simulation, purchase_price: 100_000).notary_fees).to eq(9_192)
    end

    # Sans prix, pas de part fixe toute seule : un bien à zéro euro ne coûte pas 1 772 € de notaire.
    it "is nothing as long as no price has been named" do
      expect(build(:simulation, purchase_price: nil).notary_fees).to eq(0)
    end

  end

  # Le plan du LMNP lit le prix, les frais de notaire, les travaux et les meubles de la simulation.
  describe "#depreciation_plan" do
    it "hands the plan what the purchase cost, notary fees included" do
      simulation = build(:simulation, purchase_price: 200_000, initial_works: 12_000, furniture: 2_100,
                                      maintenance: 1_200, furniture_maintenance: 350)

      expect(simulation.depreciation_plan.bases)
        .to eq(building: BigDecimal("184120.20"), works: 12_000, furniture: 2_100)
      expect(simulation.depreciation_plan.capitalized(1)).to eq(works: 600, furniture: 280)
      expect(simulation.taxation(:lmnp).capitalized_lines).to eq(works: 600, furniture: 280)
      expect(simulation.taxation(:lmnp).depreciation_lines).to eq(building: BigDecimal("5753.76"), works: 1_050,
                                                                  furniture: 340)
      expect(simulation.taxation(:foncier_reel).depreciation_lines).to eq({})
    end
  end

  # Une décote de 20 000 € sur 200 000 € payés : le bien en vaut 220 000, et la revente part de là.
  describe "#market_value" do
    it "adds the discount obtained to the price paid" do
      expect(build(:simulation, purchase_price: 200_000, purchase_discount: 20_000).market_value).to eq(220_000)
    end

    it "is the price itself when the property was bought at its value" do
      expect(build(:simulation, purchase_price: 200_000).market_value).to eq(200_000)
    end
  end

  describe "#total_investment" do
    it "adds the notary fees and the initial works to the price" do
      expect(build(:simulation, purchase_price: 200_000, initial_works: 15_000).total_investment).to eq(231_612)
    end
  end

  # Les meubles ne se paient que sous un régime du meublé : 231 612 € nus, 233 612 € meublés.
  describe "#total_investment_under" do
    subject(:simulation) { build(:simulation, purchase_price: 200_000, initial_works: 15_000, furniture: 2_000) }

    it "adds the furniture to the cost of the project under the furnished regimes alone" do
      expect(simulation.total_investment_under(:micro_foncier)).to eq(231_612)
      expect(simulation.total_investment_under(:foncier_reel)).to eq(231_612)
      expect(simulation.total_investment_under(:micro_bic)).to eq(233_612)
      expect(simulation.total_investment_under(:lmnp)).to eq(233_612)
    end
  end

  describe "the credit" do
    subject(:simulation) do
      build(:simulation, :with_credit, purchase_price: 200_000, initial_works: 0, down_payment: 23_388)
    end

    # Le coût du projet moins l'apport : 216 612 − 23 388.
    it "borrows what the down payment does not cover" do
      expect(simulation.borrowed_capital).to eq(193_224)
    end

    # La simulation déduit le crédit de ses colonnes ; Loan sait ce qu'il prélève et ce qu'il coûte.
    it "hands the loan what the columns answered" do
      expect(simulation.loan).to have_attributes(capital: 193_224, annual_rate: 3, duration_years: 20,
                                                 signed_on: simulation.purchase_date)
    end

    # Cautionnement et frais de dossier vont au crédit, qui sait qu'ils se paient à la signature.
    it "hands the loan the fees the signature costs" do
      with_fees = build(:simulation, :with_credit, loan_guarantee_fees: 3_220, loan_application_fees: 1_932)

      expect(with_fees.loan).to have_attributes(guarantee_fees: 3_220, application_fees: 1_932)
    end

    it "borrows nothing when the purchase is paid outright" do
      paid_outright = build(:simulation, credit: false)

      expect(paid_outright.borrowed_capital).to eq(0)
      expect(paid_outright.loan.schedule).to be_nil
    end

    # Le capital emprunté se rend par les annuités : le compter aussi ferait payer le bien deux fois.
    it "immobilizes the down payment alone, where a purchase paid outright immobilizes it all" do
      expect(simulation.initial_outlay).to eq(23_388)
      expect(build(:simulation, credit: false, purchase_price: 200_000, initial_works: 0).initial_outlay)
        .to eq(216_612)
    end

    # Les meubles se paient comptant, jamais à crédit : 23 388 € d'apport et 2 000 € de meubles.
    it "immobilizes the furniture on top, and only under a furnished regime" do
      furnished = build(:simulation, :with_credit, purchase_price: 200_000, initial_works: 0,
                                                   down_payment: 23_388, furniture: 2_000)

      expect(furnished.initial_outlay(:micro_bic)).to eq(25_388)
      expect(furnished.initial_outlay(:foncier_reel)).to eq(23_388)
      expect(furnished.borrowed_capital).to eq(193_224)
    end

    # Ils sortent de la même poche que l'apport, le même jour : 23 388 + 3 220 + 1 932.
    it "immobilizes the fees the signature costs next to the down payment" do
      with_fees = build(:simulation, :with_credit, purchase_price: 200_000, initial_works: 0,
                                                   down_payment: 23_388, loan_guarantee_fees: 3_220,
                                                   loan_application_fees: 1_932)

      expect(with_fees.initial_outlay).to eq(28_540)
    end

    # Le crédit déjà lu ne doit pas survivre à la case qui le déclarait.
    it "clears what a purchase paid outright no longer answers" do
      saved = create(:simulation, :with_credit, loan_insurance: 19.32, loan_guarantee_fees: 3_220,
                                                loan_application_fees: 1_932)
      saved.loan

      saved.update(credit: false)

      expect(saved.reload).to have_attributes(down_payment: 0, loan_rate: 0, loan_duration_years: 0,
                                              loan_insurance: 0, loan_guarantee_fees: 0,
                                              loan_application_fees: 0)
      expect(saved.loan.schedule).to be_nil
    end
  end

  # La provision n'est pas un revenu et la dépense qu'elle rembourse n'est pas déductible.
  describe "#annual_charges_excluding_provision" do
    it "takes the provision the tenant reimburses out of the charges" do
      let_out = build(:simulation, monthly_charges: 100, occupancy_months: 12,
                                   property_tax: 700, condominium_fees: 1_500)

      expect(let_out.annual_provision_for_charges).to eq(1_200)
      expect(let_out.annual_charges_excluding_provision).to eq(1_000)
    end

    it "is what the foncier réel deducts from the rent excluding charges" do
      let_out = build(:simulation, monthly_rent: 1_000, monthly_charges: 100, occupancy_months: 12,
                                   condominium_fees: 1_500)

      expect(let_out.taxation(:foncier_reel).taxable_income).to eq(12_000 - 300)
    end
  end

  describe "#annual_cash_flow" do
    # Une année pleine : l'impôt y pèse comme les charges et l'annuité, 12,04 % de 9 600 € de loyers.
    it "takes the taxes and the annuity out of what the charges leave of the rent" do
      simulation = build(:simulation, :with_credit, purchase_price: 200_000, initial_works: 0,
                                                    down_payment: 23_388, monthly_rent: 800,
                                                    occupancy_months: 12, property_tax: 700)

      expect(simulation.annual_taxes).to eq(BigDecimal("1155.84"))
      expect(simulation.annual_cash_flow)
        .to eq(9_600 - 700 - BigDecimal("1155.84") - BigDecimal("1071.62") * 12)
    end
  end

  describe "#projection" do
    it "hands the projection this simulation" do
      expect(build(:simulation).projection(:micro_foncier)).to be_a(Projection)
    end
  end
end
