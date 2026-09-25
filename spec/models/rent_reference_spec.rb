require "rails_helper"

RSpec.describe RentReference do
  subject(:table) { described_class.parse(File.read(Rails.root.join("spec/fixtures/barometre_pierria.csv"))) }

  let(:orleans) { table["orleans"] }
  let(:bourges) { table["bourges"] }

  describe ".parse" do
    it "reads a file that opens on a byte order mark and counts in commas" do
      expect(orleans.city).to eq("Orléans")
      expect(orleans.department).to eq("Loiret")
      expect(orleans.code_insee).to eq("45234")
      expect(orleans.listings).to eq(27_399)
    end
  end

  describe "#rent_per_square_meter" do
    it "reads the small apartments up to 50 m² and the larger ones beyond" do
      expect(orleans.rent_per_square_meter("apartment", 50)).to eq(BigDecimal("14.75"))
      expect(orleans.rent_per_square_meter("apartment", BigDecimal("50.01"))).to eq(BigDecimal("11.59"))
    end

    it "reads the house column whatever the surface" do
      expect(orleans.rent_per_square_meter("house", 30)).to eq(BigDecimal("11.46"))
      expect(orleans.rent_per_square_meter("house", 120)).to eq(BigDecimal("11.46"))
    end

    it "falls back on the whole market when the column is empty" do
      expect(bourges.rent_per_square_meter("apartment", 30)).to eq(BigDecimal("10"))
      expect(bourges.rent_per_square_meter("house", 120)).to eq(BigDecimal("10"))
    end

    it "has nothing for what the barometer does not observe" do
      expect(orleans.rent_per_square_meter("parking", 12)).to be_nil
      expect(orleans.rent_per_square_meter("building", 300)).to be_nil
      expect(orleans.rent_per_square_meter("apartment", 0)).to be_nil
      expect(orleans.rent_per_square_meter("apartment", nil)).to be_nil
    end
  end

  describe "#monthly_rent" do
    it "multiplies the square meter by the surface, to the euro" do
      expect(orleans.monthly_rent("apartment", 30)).to eq(443)
      expect(orleans.monthly_rent("house", 90)).to eq(1_031)
      expect(orleans.monthly_rent("parking", 12)).to be_nil
    end
  end

  describe "the edition shipped with the code" do
    it "covers the hundred largest cities, accents and case aside" do
      expect(described_class.all.size).to eq(100)
      expect(described_class.for("ORLEANS").code_insee).to eq("45234")
      expect(described_class.for("Orléans").monthly_rent("apartment", 30)).to eq(443)
    end

    it "knows nothing of the communes it does not cover" do
      expect(described_class.for("Prunay-le-Temple")).to be_nil
      expect(described_class.for("")).to be_nil
      expect(described_class.for(nil)).to be_nil
    end
  end
end
