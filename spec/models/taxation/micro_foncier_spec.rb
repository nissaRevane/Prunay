require "rails_helper"

# Le micro-foncier tient en trois nombres : un abattement de 30 %, la tranche du foyer et
# 17,2 % de prélèvements sociaux. Les exemples les prennent un par un, puis ensemble.
RSpec.describe Taxation::MicroFoncier do
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
    end

    it "asks for both at once" do
      expect(taxation.total).to eq(BigDecimal("3964.80"))
    end
  end

  # Le forfait tient lieu des charges réelles : les lui donner ne change rien à l'assiette.
  it "deducts neither the real charges nor the loan interest" do
    with_charges = described_class.new(rent_excluding_charges: 12_000, marginal_tax_rate: 30,
                                       charges: 2_000, loan_interest: 5_000)

    expect(with_charges.taxable_income).to eq(8_400)
    expect(with_charges.total).to eq(BigDecimal("3964.80"))
  end

  # Une tranche à zéro n'exonère de rien : les prélèvements sociaux, eux, ne connaissent pas
  # le barème — 17,2 % des 70 % imposables, soit 12,04 % du loyer.
  it "still levies the social charges on a household the scale does not reach" do
    untaxed = described_class.new(rent_excluding_charges: 12_000, marginal_tax_rate: 0)

    expect(untaxed.income_tax).to eq(0)
    expect(untaxed.total).to eq(BigDecimal("1444.80"))
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
