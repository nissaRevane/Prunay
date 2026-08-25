require "rails_helper"

RSpec.describe Simulation, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:purchase_date) }
    it { is_expected.to validate_numericality_of(:purchase_price).is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:monthly_rent).is_greater_than_or_equal_to(0) }
  end

  describe "#annual_rent" do
    it "is twelve monthly rents" do
      expect(build(:simulation, monthly_rent: 800).annual_rent).to eq(9_600)
    end
  end

  describe "#projection" do
    subject(:projection) { simulation.projection }

    let(:simulation) do
      build(:simulation, purchase_date: Date.new(2025, 3, 10), purchase_price: 200_000, monthly_rent: 800)
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

    it "collects a full year of rent on every line" do
      expect(projection.map(&:annual_rent).uniq).to eq([9_600])
    end

    # Tant qu'il n'y a ni prêt ni charges, le cash-flow EST le loyer : la distinction se lit
    # dans le tableau, et les sorties futures n'auront qu'un endroit où se soustraire.
    it "is nothing but the rent as long as there are no outgoings" do
      expect(projection.map(&:cash_flow).uniq).to eq([9_600])
    end

    it "deducts the cash flows accumulated since the purchase from the immobilized capital" do
      expect(projection.first.immobilized_capital).to eq(200_000 - 9_600)
      expect(projection.second.immobilized_capital).to eq(200_000 - 19_200)
      expect(projection.last.immobilized_capital).to eq(200_000 - 288_000)
    end

    it "marks a line as recovered once the capital has come back" do
      recovered = projection.select(&:recovered?)

      expect(recovered.first.number).to eq(21)
      expect(projection.take(20).map(&:recovered?)).to all(be(false))
    end

    it "keeps a 29 February purchase on a real date" do
      leap = build(:simulation, purchase_date: Date.new(2024, 2, 29))

      expect(leap.projection.first.date).to eq(Date.new(2025, 2, 28))
    end
  end

  describe "#final_immobilized_capital" do
    it "is what the last line of the projection shows" do
      simulation = build(:simulation, purchase_price: 200_000, monthly_rent: 800)

      expect(simulation.final_immobilized_capital).to eq(simulation.projection.last.immobilized_capital)
    end
  end
end
