require "rails_helper"

# Le micro-BIC est le forfait du meublé : la moitié des recettes échappe à l'impôt, mais les
# recettes comptent la provision pour charges et les prélèvements sociaux montent à 18,6 %.
RSpec.describe Taxation::MicroBic do
  subject(:taxation) do
    described_class.new(rent_excluding_charges: 12_000, provision_for_charges: 1_200, marginal_tax_rate: 30)
  end

  # C'est là que le meublé s'écarte du nu : ce que le locataire verse est une recette, quel
  # qu'en soit le titre.
  describe "#receipts" do
    it "counts the provision for charges the tenant pays on top of the rent" do
      expect(taxation.receipts).to eq(13_200)
    end
  end

  describe "#allowance" do
    it "takes half of the receipts, whatever the charges really were" do
      expect(taxation.allowance).to eq(6_600)
      expect(described_class::ALLOWANCE_RATE).to eq(50)
    end
  end

  describe "#taxable_income" do
    it "is what the allowance leaves of the receipts" do
      expect(taxation.taxable_income).to eq(6_600)
    end
  end

  # 6 600 € imposables : 30 % de barème, et 18,6 % de prélèvements sociaux par-dessus.
  describe "the two levies" do
    it "applies the bracket of the household to what is taxable" do
      expect(taxation.income_tax).to eq(1_980)
    end

    # La LFSS 2026 n'épargne que le foncier et la plus-value : un loyer meublé est un BIC.
    it "adds the social charges at the rate the furnished letting pays" do
      expect(taxation.social_charges_rate).to eq(BigDecimal("18.6"))
      expect(taxation.social_charges).to eq(BigDecimal("1227.60"))
    end

    it "asks for both at once" do
      expect(taxation.total).to eq(BigDecimal("3207.60"))
    end
  end

  # Le forfait tient lieu des charges réelles : les lui donner ne change rien à l'assiette.
  it "deducts neither the real charges nor the loan interest" do
    with_charges = described_class.new(rent_excluding_charges: 12_000, provision_for_charges: 1_200,
                                      marginal_tax_rate: 30, charges: 2_000, loan_interest: 5_000)

    expect(with_charges.taxable_income).to eq(6_600)
    expect(with_charges.total).to eq(BigDecimal("3207.60"))
  end

  # Le taux plus lourd ne rattrape pas l'abattement doublé : sur le même loyer nu, le
  # micro-foncier impose 8 400 € à 17,2 % — 1 444,80 € — quand le micro-BIC n'en impose que
  # 6 000 € à 18,6 %.
  it "costs less than the micro-foncier on the same rent, its allowance being twice as large" do
    furnished = described_class.new(rent_excluding_charges: 12_000, marginal_tax_rate: 0)

    expect(furnished.taxable_income).to eq(6_000)
    expect(furnished.total).to eq(1_116)
    expect(furnished.total).to be < Taxation::MicroFoncier.new(rent_excluding_charges: 12_000,
                                                               marginal_tax_rate: 0).total
  end

  it "asks nothing of a property that was never let" do
    expect(described_class.new(rent_excluding_charges: 0, marginal_tax_rate: 45).total).to eq(0)
  end

  # `to_d` comme dans Loan : un taux entier ferait une division entière, et l'impôt tomberait
  # à zéro sur les 45 % du barème comme sur les 50 % de l'abattement.
  it "reads an integer bracket as a rate and not as a division" do
    expect(described_class.new(rent_excluding_charges: 10_000, marginal_tax_rate: 45).income_tax).to eq(2_250)
  end
end
