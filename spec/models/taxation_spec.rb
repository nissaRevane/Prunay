require "rails_helper"

# Le micro-foncier tient en trois nombres : un abattement de 30 %, la tranche du foyer et
# 17,2 % de prélèvements sociaux. Les exemples les prennent un par un, puis ensemble.
RSpec.describe Taxation do
  subject(:taxation) { described_class.new(rent_excluding_charges: 12_000, marginal_tax_rate: 30) }

  # L'abattement tient lieu de toute charge déductible : c'est ce que le régime a de simple.
  describe "#allowance" do
    it "takes 30 per cent of the rent, whatever the charges really were" do
      expect(taxation.allowance).to eq(3_600)
      expect(described_class::ALLOWANCE_RATE).to eq(30)
    end
  end

  describe "#taxable_income" do
    it "is what the allowance leaves of the rent" do
      expect(taxation.taxable_income).to eq(8_400)
    end
  end

  # 8 400 € imposables : 30 % de barème, et 17,2 % de prélèvements sociaux par-dessus.
  describe "the two levies" do
    it "applies the bracket of the household to what is taxable" do
      expect(taxation.income_tax).to eq(2_520)
    end

    it "adds the social charges, which no bracket governs" do
      expect(taxation.social_charges).to eq(BigDecimal("1444.80"))
      expect(described_class::SOCIAL_CHARGES_RATE).to eq(BigDecimal("17.2"))
    end

    it "asks for both at once" do
      expect(taxation.total).to eq(BigDecimal("3964.80"))
    end
  end

  # Une tranche à zéro n'exonère de rien : les prélèvements sociaux, eux, ne connaissent pas
  # le barème — 17,2 % des 70 % imposables, soit 12,04 % du loyer.
  it "still levies the social charges on a household the scale does not reach" do
    untaxed = described_class.new(rent_excluding_charges: 12_000, marginal_tax_rate: 0)

    expect(untaxed.income_tax).to eq(0)
    expect(untaxed.total).to eq(BigDecimal("1444.80"))
  end

  # Le barème n'a que cinq tranches : c'est une liste, non une échelle.
  it "knows the five brackets of the scale, and supposes the one most investors are in" do
    expect(described_class::MARGINAL_TAX_RATES).to eq([0, 11, 30, 41, 45])
    expect(described_class::DEFAULT_MARGINAL_TAX_RATE).to eq(30)
  end

  it "asks nothing of a property that was never let" do
    expect(described_class.new(rent_excluding_charges: 0, marginal_tax_rate: 45).total).to eq(0)
  end

  # `to_d` comme dans Loan : un taux entier ferait une division entière, et l'impôt tomberait
  # à zéro sur les 45 % du barème comme sur les 30 % de l'abattement.
  it "reads an integer bracket as a rate and not as a division" do
    expect(described_class.new(rent_excluding_charges: 10_000, marginal_tax_rate: 45).income_tax).to eq(3_150)
  end
end
