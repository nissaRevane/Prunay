require "rails_helper"

RSpec.describe Simulation, type: :model do
  # Chaque page de la création est un contexte de validation : elle ne juge que ses propres
  # champs, pour qu'une étape puisse être validée sans exiger les réponses des suivantes.
  describe "validations" do
    it { is_expected.to validate_presence_of(:city).on(:property) }
    it { is_expected.to validate_numericality_of(:surface).is_greater_than(0).on(:property) }
    it { is_expected.to validate_inclusion_of(:property_type).in_array(described_class::PROPERTY_TYPES).on(:property) }
    it { is_expected.to validate_inclusion_of(:energy_rating).in_array(described_class::ENERGY_RATINGS).allow_blank.on(:property) }

    it { is_expected.to validate_presence_of(:purchase_date).on(:purchase) }
    it { is_expected.to validate_numericality_of(:purchase_price).is_greater_than(0).on(:purchase) }
    it { is_expected.to validate_numericality_of(:initial_works).is_greater_than_or_equal_to(0).on(:purchase) }

    # Le crédit ne se juge qu'à qui en prend un : sans crédit, la page n'existe pas, et
    # l'apport comme le taux et la durée sont remis à zéro avant même d'être validés.
    context "of a purchase financed by a credit" do
      subject { build(:simulation, :with_credit) }

      it { is_expected.to validate_numericality_of(:down_payment).is_greater_than_or_equal_to(0).on(:purchase) }
      it { is_expected.to validate_numericality_of(:loan_rate).is_greater_than_or_equal_to(0).is_less_than(100).on(:credit) }
      it { is_expected.to validate_numericality_of(:loan_duration_years).only_integer.is_greater_than(0).on(:credit) }

      # Un apport qui couvrirait tout le projet ne laisserait rien à emprunter.
      it "refuses a down payment that leaves nothing to borrow" do
        simulation = build(:simulation, :with_credit, purchase_price: 200_000, initial_works: 0,
                                                      down_payment: 216_612)

        expect(simulation).not_to be_valid(:purchase)
        expect(simulation.errors[:down_payment]).to be_present
      end
    end

    it "asks nothing of the credit of a purchase paid outright" do
      expect(build(:simulation, credit: false, loan_rate: 0, loan_duration_years: 0)).to be_valid(:credit)
    end

    it { is_expected.to validate_numericality_of(:monthly_rent).is_greater_than_or_equal_to(0).on(:rental) }
    it { is_expected.to validate_numericality_of(:occupancy_months).is_greater_than(0).is_less_than_or_equal_to(12).on(:rental) }
    it { is_expected.to validate_inclusion_of(:rental_type).in_array(described_class::RENTAL_TYPES).on(:rental) }

    it { is_expected.to validate_numericality_of(:property_tax).is_greater_than_or_equal_to(0).on(:charges) }

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

  # Le parcours n'est pas le même pour tout le monde : la page du crédit ne s'ouvre qu'à qui
  # en a coché un sur la page de l'achat.
  describe "#steps" do
    it "walks the credit page only when there is a credit" do
      expect(build(:simulation, :with_credit).steps).to eq(%w[property purchase credit rental charges])
      expect(build(:simulation, credit: false).steps).to eq(%w[property purchase rental charges])
    end
  end

  describe ".estimate" do
    # Racine carrée, et non proportion : un logement quatre fois plus grand se loue deux
    # fois plus cher, pas quatre.
    it "scales a reference amount by the square root of the surface" do
      expect(described_class.estimate(:monthly_rent, 50)).to eq(650)
      expect(described_class.estimate(:monthly_rent, 200)).to eq(1_300)
    end

    it "rounds to the nearest ten euros" do
      expect(described_class.estimate(:property_tax, 30)).to eq(540)
      expect(described_class.estimate(:insurance, 30)).to eq(120)
      expect(described_class.estimate(:condominium_fees, 30)).to eq(770)
      expect(described_class.estimate(:business_tax, 30)).to eq(150)
      expect(described_class.estimate(:other_charges, 30)).to eq(80)
    end

    # L'entretien se lit à deux références : la copropriété porte déjà la façade, la toiture
    # et les communs, et le propriétaire seul les porte toutes.
    it "doubles the maintenance of a property no condominium looks after" do
      expect(described_class.estimate(:maintenance, 50, condominium: true)).to eq(1_000)
      expect(described_class.estimate(:maintenance, 50)).to eq(2_000)
    end

    # Un bilan de meublé se paie au forfait, et une gestion déléguée comme une garantie des
    # loyers impayés ne se supposent pas : on les propose à zéro.
    it "leaves the amounts that do not follow the surface where they are" do
      expect(described_class.estimate(:accounting_fees, 200)).to eq(500)
      expect(described_class.estimate(:management_fees, 200)).to eq(0)
      expect(described_class.estimate(:rent_guarantee, 200)).to eq(0)
    end

    it "has nothing to propose without a surface" do
      expect(described_class.estimate(:monthly_rent, nil)).to eq(0)
      expect(described_class.estimate(:monthly_rent, 0)).to eq(0)
    end
  end

  describe "#defaults_for" do
    def draft(**answers)
      described_class.new(user: build(:user), **answers)
    end

    it "proposes nothing on the first page: the surface is what it asks for" do
      expect(draft(surface: 50).defaults_for("property")).to eq({})
    end

    it "dates the purchase three months out and assumes no works" do
      defaults = draft.defaults_for("purchase")

      expect(defaults["purchase_date"]).to eq(Date.current >> 3)
      expect(defaults["initial_works"]).to eq(0)
    end

    # Un dixième du coût du projet — 216 612 € font 21 660 €, arrondis à la dizaine d'euros
    # comme les autres montants proposés. La page de l'achat s'ouvre avant que le prix n'y
    # soit tapé : elle ne peut alors rien proposer.
    it "proposes a tenth of the project cost as a down payment" do
      expect(draft(purchase_price: 200_000, initial_works: 0).defaults_for("purchase")["down_payment"]).to eq(21_660)
      expect(draft.defaults_for("purchase")["down_payment"]).to eq(0)
    end

    it "proposes twenty years at 3.5 % for the credit" do
      expect(draft.defaults_for("credit")).to eq("loan_rate" => BigDecimal("3.5"), "loan_duration_years" => 20)
    end

    it "leaves a month of vacancy a year" do
      expect(draft(surface: 50).defaults_for("rental")["occupancy_months"]).to eq(11)
    end

    # Un bien meublé hors copropriété : pas de charges de copro, un entretien doublé, et les
    # deux charges que le meublé impose.
    it "estimates every charge the property is asked for" do
      defaults = draft(surface: 50, condominium: false, rental_type: "furnished").defaults_for("charges")

      expect(defaults).to eq(
        "property_tax" => 700, "insurance" => 150, "maintenance" => 2_000,
        "management_fees" => 0, "rent_guarantee" => 0,
        "business_tax" => 200, "accounting_fees" => 500,
        "other_charges" => 100
      )
    end

    it "asks a condominium for its fees, and halves the maintenance it no longer carries alone" do
      defaults = draft(surface: 50, condominium: true, rental_type: "unfurnished").defaults_for("charges")

      expect(defaults).to include("condominium_fees" => 1_000, "maintenance" => 1_000)
      expect(defaults.keys).not_to include("business_tax", "accounting_fees")
    end
  end

  # Le nom peut se donner dès la première page, mais rien n'y oblige : à l'enregistrement,
  # une simulation sans nom prend celui de son bien.
  describe "the name" do
    it "keeps the one the first page was given" do
      expect(create(:simulation, name: "Le studio du port").name).to eq("Le studio du port")
    end

    it "reads the property itself when nobody named the simulation" do
      simulation = create(:simulation, name: "", property_type: "house", city: "Rennes", surface: 62.5)

      expect(simulation.name).to eq("Maison à Rennes, 62,5 m²")
    end

    it "names the simulation again when its name is emptied by hand" do
      simulation = create(:simulation, name: "Le studio du port")

      simulation.update(name: "  ")

      expect(simulation.reload.name).to eq(simulation.default_name)
    end

    # Valider une étape, ce n'est pas enregistrer : la page du bien ne doit pas remplir à
    # l'utilisateur un champ qu'il a laissé vide.
    it "leaves the field empty while a page is being validated" do
      draft = described_class.new(user: build(:user), property_type: "house", city: "Rennes", surface: 50)

      draft.valid?(:property)

      expect(draft.name).to be_blank
    end
  end

  describe "#annual_rent" do
    # Onze mois loués ne font pas douze loyers : la vacance locative se paie.
    it "counts only the months actually let" do
      expect(build(:simulation, monthly_rent: 800, occupancy_months: 11).annual_rent).to eq(8_800)
    end
  end

  describe "#annual_charges" do
    it "adds up the charges the property is asked for" do
      simulation = build(:simulation, condominium: true, rental_type: "furnished",
                                      property_tax: 700, insurance: 150, maintenance: 1_000,
                                      condominium_fees: 1_200, management_fees: 600, rent_guarantee: 300,
                                      business_tax: 200, accounting_fees: 500, other_charges: 100)

      expect(simulation.annual_charges).to eq(4_750)
    end

    # Une charge qu'aucune condition ne justifie ne pèse pas sur la projection : elle est
    # ramenée à zéro avant l'enregistrement, et le total ne la compte pas.
    it "ignores what the property is not asked for" do
      simulation = create(:simulation, condominium: false, rental_type: "unfurnished",
                                       property_tax: 700, condominium_fees: 1_200,
                                       business_tax: 200, accounting_fees: 500)

      expect(simulation.annual_charges).to eq(700)
      expect(simulation).to have_attributes(condominium_fees: 0, business_tax: 0, accounting_fees: 0)
    end
  end

  # Trois charges ne se demandent que sous condition, et ne survivent pas à sa disparition :
  # les charges de copropriété à un bien en copropriété, la CFE et le comptable à un meublé.
  describe "the charges a condition governs" do
    it "asks a condominium for its fees, and a property outside one for nothing of the sort" do
      expect(build(:simulation, condominium: true).applicable_charges).to include(:condominium_fees)
      expect(build(:simulation, condominium: false).applicable_charges).not_to include(:condominium_fees)
    end

    it "asks a furnished letting for its business tax and its accountant, and an unfurnished one for neither" do
      expect(build(:simulation, rental_type: "furnished").applicable_charges).to include(:business_tax, :accounting_fees)
      expect(build(:simulation, rental_type: "unfurnished").applicable_charges).not_to include(:business_tax, :accounting_fees)
    end

    # Sortir de copropriété, c'est cesser d'en payer les charges : un montant que le
    # formulaire ne montre plus ne doit pas continuer de peser sur la projection.
    it "clears an amount its condition no longer justifies" do
      simulation = create(:simulation, condominium: true, condominium_fees: 1_200)

      simulation.update(condominium: false)

      expect(simulation.reload.condominium_fees).to eq(0)
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

    # La page de l'achat s'affiche avant qu'un prix n'y soit tapé : elle ne doit pas
    # annoncer la part fixe toute seule, comme si un bien à zéro euro coûtait 1 772 € de notaire.
    it "is nothing as long as no price has been named" do
      expect(build(:simulation, purchase_price: nil).notary_fees).to eq(0)
    end
  end

  describe "#total_investment" do
    it "adds the notary fees and the initial works to the price" do
      expect(build(:simulation, purchase_price: 200_000, initial_works: 15_000).total_investment).to eq(231_612)
    end
  end

  describe "the credit" do
    subject(:simulation) do
      build(:simulation, :with_credit, purchase_price: 200_000, initial_works: 0, down_payment: 23_388)
    end

    # Le coût du projet moins l'apport : 216 612 − 23 388.
    it "borrows what the down payment does not cover" do
      expect(simulation.borrowed_capital).to eq(193_224)
      expect(simulation.monthly_payment).to eq(BigDecimal("1071.62"))
      expect(simulation.annual_loan_payment).to eq(BigDecimal("1071.62") * 12)
    end

    it "borrows nothing when the purchase is paid outright" do
      paid_outright = build(:simulation, credit: false)

      expect(paid_outright.borrowed_capital).to eq(0)
      expect(paid_outright.monthly_payment).to eq(0)
      expect(paid_outright.amortization_schedule).to be_nil
    end

    # Le capital emprunté n'est pas immobilisé : il se rembourse par les annuités, que la
    # projection retranche du cash-flow. Le compter deux fois ferait payer le bien deux fois.
    it "immobilizes the down payment alone, where a purchase paid outright immobilizes it all" do
      expect(simulation.initial_outlay).to eq(23_388)
      expect(build(:simulation, credit: false, purchase_price: 200_000, initial_works: 0).initial_outlay)
        .to eq(216_612)
    end

    # Renoncer au crédit, c'est cesser d'en porter les conditions : un taux et une durée que
    # le formulaire ne montre plus ne doivent pas continuer de produire un tableau.
    it "clears what a purchase paid outright no longer answers" do
      saved = create(:simulation, :with_credit)

      saved.update(credit: false)

      expect(saved.reload).to have_attributes(down_payment: 0, loan_rate: 0, loan_duration_years: 0)
      expect(saved.amortization_schedule).to be_nil
    end
  end

  describe "#projection" do
    subject(:projection) { simulation.projection }

    let(:simulation) do
      build(:simulation, purchase_date: Date.new(2025, 3, 10), purchase_price: 200_000, initial_works: 20_000,
                         monthly_rent: 1_000, occupancy_months: 11,
                         property_tax: 700, maintenance: 1_000, insurance: 150, other_charges: 150)
    end

    it "runs over the whole horizon, one line per year" do
      expect(projection.size).to eq(described_class::HORIZON_YEARS)
      expect(projection.map(&:number)).to eq((1..30).to_a)
    end

    # La première ligne est le premier anniversaire, pas le jour de l'achat : elle porte les
    # loyers des douze mois écoulés, et une ligne à zéro le jour de la signature n'en dirait rien.
    it "dates each line on an anniversary of the purchase" do
      expect(projection.first.date).to eq(Date.new(2026, 3, 10))
      expect(projection.second.date).to eq(Date.new(2027, 3, 10))
      expect(projection.last.date).to eq(Date.new(2055, 3, 10))
    end

    it "collects the same rent and pays the same charges on every line" do
      expect(projection.map(&:annual_rent).uniq).to eq([11_000])
      expect(projection.map(&:annual_charges).uniq).to eq([2_000])
    end

    it "is the rent less the charges as long as there is no loan" do
      expect(projection.map(&:cash_flow).uniq).to eq([9_000])
    end

    # Les frais de notaire et les travaux initiaux s'immobilisent avec le prix : ils sont
    # engagés avant le premier loyer, et c'est de leur somme que les cash-flows se déduisent.
    it "deducts the cash flows accumulated since the purchase from the price, the fees and the works" do
      expect(projection.first.immobilized_capital).to eq(236_612 - 9_000)
      expect(projection.second.immobilized_capital).to eq(236_612 - 18_000)
      expect(projection.last.immobilized_capital).to eq(236_612 - 270_000)
    end

    it "marks a line as recovered once the capital has come back" do
      recovered = projection.select(&:recovered?)

      expect(recovered.first.number).to eq(27)
      expect(projection.take(26).map(&:recovered?)).to all(be(false))
    end

    # Le crédit pèse sur chaque année tant qu'il court, et cesse de peser le jour où il est
    # soldé : une projection de trente ans porte vingt annuités d'un prêt de vingt ans.
    describe "of a purchase financed by a credit" do
      subject(:projection) do
        build(:simulation, :with_credit, purchase_price: 200_000, initial_works: 0, down_payment: 23_388,
                                         monthly_rent: 800, occupancy_months: 12).projection
      end

      it "deducts the annuity from the cash flow for as long as the loan runs" do
        expect(projection.first.loan_payments).to eq(BigDecimal("1071.62") * 12)
        expect(projection.first.cash_flow).to eq(9_600 - BigDecimal("1071.62") * 12)
      end

      it "stops deducting anything once the loan is cleared" do
        expect(projection[19].loan_payments).to be_positive
        expect(projection[20].loan_payments).to eq(0)
        expect(projection[20].cash_flow).to eq(9_600)
      end

      # L'apport seul est immobilisé le premier jour, et les annuités le creusent avant que
      # les loyers ne le comblent.
      it "starts from the down payment and not from the whole project" do
        expect(projection.first.immobilized_capital).to eq(23_388 - projection.first.cash_flow)
      end
    end

    it "keeps a 29 February purchase on a real date" do
      leap = build(:simulation, purchase_date: Date.new(2024, 2, 29))

      expect(leap.projection.first.date).to eq(Date.new(2025, 2, 28))
    end
  end

  describe "#final_immobilized_capital" do
    it "is what the last line of the projection shows" do
      simulation = build(:simulation, purchase_price: 200_000, initial_works: 20_000, monthly_rent: 800,
                                      occupancy_months: 11, property_tax: 700)

      expect(simulation.final_immobilized_capital).to eq(simulation.projection.last.immobilized_capital)
    end
  end
end
