require "rails_helper"

RSpec.describe Taxation::MicroBic do
  subject(:taxation) do
    described_class.new(rent_excluding_charges: 12_000, provision_for_charges: 1_200, marginal_tax_rate: 30,
                        monthly_rent: 1_000)
  end

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

  describe "the two levies" do
    it "applies the bracket of the household to what is taxable" do
      expect(taxation.income_tax).to eq(1_980)
    end

    it "adds the social charges at the rate the furnished letting pays" do
      expect(taxation.social_charges_rate).to eq(BigDecimal("18.6"))
      expect(taxation.social_charges).to eq(BigDecimal("1227.60"))
    end

    it "asks for both at once, the business tax left to the charges of the year" do
      expect(taxation.total).to eq(BigDecimal("3207.60"))
    end
  end

  describe "#business_tax" do
    it "takes its share of a monthly rent, whatever the allowance left of the receipts" do
      expect(taxation.business_tax).to eq(300)
      expect(described_class::BUSINESS_TAX_RATE).to eq(30)
    end

    it "is owed by the furnished letting alone" do
      expect(Taxation::MicroFoncier.new(rent_excluding_charges: 12_000, marginal_tax_rate: 30,
                                        monthly_rent: 1_000).business_tax).to eq(0)
    end
  end

  it "deducts neither the real charges nor the loan interest" do
    with_charges = described_class.new(rent_excluding_charges: 12_000, provision_for_charges: 1_200,
                                      marginal_tax_rate: 30, charges: 2_000, loan_interest: 5_000,
                                      monthly_rent: 1_000)

    expect(with_charges.taxable_income).to eq(6_600)
    expect(with_charges.total).to eq(BigDecimal("3207.60"))
  end

  it "costs less than the micro-foncier on the same rent, its allowance being twice as large" do
    furnished = described_class.new(rent_excluding_charges: 12_000, marginal_tax_rate: 0, monthly_rent: 1_000)

    expect(furnished.taxable_income).to eq(6_000)
    expect(furnished.total).to eq(1_116)
    expect(furnished.total).to be < Taxation::MicroFoncier.new(rent_excluding_charges: 12_000,
                                                               marginal_tax_rate: 0).total
  end

  it "asks nothing of a property that was never let" do
    expect(described_class.new(rent_excluding_charges: 0, marginal_tax_rate: 45).total).to eq(0)
  end

  it "reads an integer bracket as a rate and not as a division" do
    expect(described_class.new(rent_excluding_charges: 10_000, marginal_tax_rate: 45).income_tax).to eq(2_250)
  end
end
