require "rails_helper"

RSpec.describe Taxation::DepreciationPlan do
  subject(:plan) { described_class.new(price: 200_000, acquisition_fees: 16_612, works: 12_000, furniture: 2_100) }

  describe "#bases" do
    it "leaves the land out of the building, notary fees included, and takes the rest whole" do
      expect(described_class::LAND_SHARE).to eq(BigDecimal("0.15"))
      expect(plan.bases).to eq(building: BigDecimal("184120.20"), works: 12_000, furniture: 2_100)
    end
  end

  describe "#annuity" do
    it "spreads each base over the years of its component" do
      expect(described_class::COMPONENTS).to eq(building: 32, works: 12, furniture: 7)
      expect(plan.annuity(:building)).to eq(BigDecimal("5753.76"))
      expect(plan.annuity(:works)).to eq(1_000)
      expect(plan.annuity(:furniture)).to eq(300)
    end
  end

  describe "#lines" do
    it "writes the three components in the first year" do
      expect(plan.lines(1)).to eq(building: BigDecimal("5753.76"), works: 1_000, furniture: 300)
      expect(plan.total(1)).to eq(BigDecimal("7053.76"))
    end

    it "drops each component once its years are over" do
      expect(plan.lines(0)).to eq({})
      expect(plan.lines(7)).to eq(building: BigDecimal("5753.76"), works: 1_000, furniture: 300)
      expect(plan.lines(8)).to eq(building: BigDecimal("5753.76"), works: 1_000)
      expect(plan.lines(13)).to eq(building: BigDecimal("5753.76"))
      expect(plan.lines(33)).to eq({})
    end

    it "settles the base to the cent with the last annuity" do
      expect(plan.lines(32)).to eq(building: BigDecimal("5753.64"))
    end

    it "writes nothing for a component that was not bought" do
      bare = described_class.new(price: 200_000, acquisition_fees: 16_612, works: 0, furniture: 0)

      expect(bare.lines(1)).to eq(building: BigDecimal("5753.76"))
    end
  end

  describe "the upkeep the years capitalize" do
    subject(:plan) do
      described_class.new(price: 200_000, acquisition_fees: 16_612, works: 12_000, furniture: 2_100,
                          maintenance: 1_200, furniture_maintenance: 350)
    end

    it "opens a tranche of works and one of furniture every year, none on the day of the purchase" do
      expect(described_class::CAPITALIZED_SHARES).to eq(works: BigDecimal("0.5"), furniture: BigDecimal("0.8"))
      expect(plan.capitalized(0)).to eq({})
      expect(plan.capitalized(1)).to eq(works: 600, furniture: 280)
      expect(plan.capitalized(9)).to eq(works: 600, furniture: 280)
    end

    it "tells the annuity a tranche of the first year will carry" do
      expect(plan.capitalized_annuity(:works)).to eq(50)
      expect(plan.capitalized_annuity(:furniture)).to eq(40)
    end

    it "adds the annuity of each living tranche to the initial line" do
      expect(plan.lines(1)).to eq(building: BigDecimal("5753.76"), works: 1_050, furniture: 340)
      expect(plan.lines(2)).to eq(building: BigDecimal("5753.76"), works: 1_100, furniture: 380)
    end

    it "reaches the pace of the upkeep once as many tranches live as the component has years" do
      expect(plan.lines(8)[:furniture]).to eq(280)
      expect(plan.lines(20)[:furniture]).to eq(280)
      expect(plan.lines(12)[:works]).to eq(1_000 + 600)
      expect(plan.lines(13)[:works]).to eq(600)
    end

    it "opens each tranche at the price of its year" do
      inflating = described_class.new(price: 200_000, acquisition_fees: 16_612, works: 0, furniture: 0,
                                      maintenance: 1_200, furniture_maintenance: 350, inflation_rate: 2)

      expect(inflating.capitalized(2)).to eq(works: 612, furniture: BigDecimal("285.60"))
      expect(inflating.lines(2)[:works]).to eq(50 + 51)
    end

    it "capitalizes nothing without upkeep" do
      bare = described_class.new(price: 200_000, acquisition_fees: 16_612, works: 0, furniture: 0)

      expect(bare.capitalized(1)).to eq({})
    end
  end
end
