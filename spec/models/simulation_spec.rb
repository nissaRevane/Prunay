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

  describe ".estimate" do
    # Racine carrée, et non proportion : un logement quatre fois plus grand se loue deux
    # fois plus cher, pas quatre.
    it "scales a reference amount by the square root of the surface" do
      expect(described_class.estimate(:monthly_rent, 50)).to eq(650)
      expect(described_class.estimate(:monthly_rent, 200)).to eq(1_300)
    end

    it "rounds to the nearest ten euros" do
      expect(described_class.estimate(:property_tax, 30)).to eq(540)
      expect(described_class.estimate(:maintenance, 30)).to eq(770)
      expect(described_class.estimate(:insurance, 30)).to eq(120)
      expect(described_class.estimate(:other_charges, 30)).to eq(80)
    end

    it "has nothing to propose without a surface" do
      expect(described_class.estimate(:monthly_rent, nil)).to eq(0)
      expect(described_class.estimate(:monthly_rent, 0)).to eq(0)
    end
  end

  describe ".defaults_for" do
    it "proposes nothing on the first page: the surface is what it asks for" do
      expect(described_class.defaults_for("property")).to eq({})
    end

    it "dates the purchase three months out and assumes no works" do
      defaults = described_class.defaults_for("purchase")

      expect(defaults["purchase_date"]).to eq(Date.current >> 3)
      expect(defaults["initial_works"]).to eq(0)
    end

    it "leaves a month of vacancy a year" do
      expect(described_class.defaults_for("rental", surface: 50)["occupancy_months"]).to eq(11)
    end

    it "estimates every annual charge from the surface" do
      expect(described_class.defaults_for("charges", surface: 50)).to eq(
        "property_tax" => 700, "maintenance" => 1_000, "insurance" => 150, "other_charges" => 100
      )
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
    it "adds up the four annual charges" do
      simulation = build(:simulation, property_tax: 700, maintenance: 1_000, insurance: 150, other_charges: 100)

      expect(simulation.annual_charges).to eq(1_950)
    end
  end

  describe "#total_investment" do
    it "adds the initial works to the price" do
      expect(build(:simulation, purchase_price: 200_000, initial_works: 15_000).total_investment).to eq(215_000)
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

    # Les travaux initiaux s'immobilisent avec le prix : ils sont engagés avant le premier
    # loyer, et c'est de leur somme que les cash-flows se déduisent.
    it "deducts the cash flows accumulated since the purchase from the price and the works" do
      expect(projection.first.immobilized_capital).to eq(220_000 - 9_000)
      expect(projection.second.immobilized_capital).to eq(220_000 - 18_000)
      expect(projection.last.immobilized_capital).to eq(220_000 - 270_000)
    end

    it "marks a line as recovered once the capital has come back" do
      recovered = projection.select(&:recovered?)

      expect(recovered.first.number).to eq(25)
      expect(projection.take(24).map(&:recovered?)).to all(be(false))
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
