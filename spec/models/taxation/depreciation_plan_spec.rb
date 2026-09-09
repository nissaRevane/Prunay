require "rails_helper"

# Le plan inscrit chaque composant en ligne droite sur sa durée : il dit ce que l'année
# amortit, pas ce qu'elle déduit — le plafond et le report sont l'affaire de Taxation::Lmnp.
RSpec.describe Taxation::DepreciationPlan do
  # 200 000 € de prix et 16 612 € de frais, dont 15 % de terrain ; 12 000 € de travaux, 2 100 € de meubles.
  subject(:plan) { described_class.new(price: 200_000, acquisition_fees: 16_612, works: 12_000, furniture: 2_100) }

  describe "#bases" do
    it "leaves the land out of the building, notary fees included, and takes the rest whole" do
      expect(described_class::LAND_SHARE).to eq(BigDecimal("0.15"))
      expect(plan.bases).to eq(building: BigDecimal("184120.20"), works: 12_000, furniture: 2_100)
    end
  end

  # 184 120,20 € sur 32 ans, 12 000 € sur 12 ans, 2 100 € sur 7 ans.
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

    # Rien le jour de l'achat ; les meubles s'éteignent après sept ans, les travaux après douze.
    it "drops each component once its years are over" do
      expect(plan.lines(0)).to eq({})
      expect(plan.lines(7)).to eq(building: BigDecimal("5753.76"), works: 1_000, furniture: 300)
      expect(plan.lines(8)).to eq(building: BigDecimal("5753.76"), works: 1_000)
      expect(plan.lines(13)).to eq(building: BigDecimal("5753.76"))
      expect(plan.lines(33)).to eq({})
    end

    # 31 annuités arrondies à 5 753,76 € laissent 5 753,64 € : la dernière solde la base au centime.
    it "settles the base to the cent with the last annuity" do
      expect(plan.lines(32)).to eq(building: BigDecimal("5753.64"))
    end

    it "writes nothing for a component that was not bought" do
      bare = described_class.new(price: 200_000, acquisition_fees: 16_612, works: 0, furniture: 0)

      expect(bare.lines(1)).to eq(building: BigDecimal("5753.76"))
    end
  end
end
