require "rails_helper"

RSpec.describe Taxation::Lmnp do
  subject(:taxation) { described_class.new(**attributes) }

  describe "#own_charges" do
    it "pays the accountant on top of the charges the furnished letting already owes" do
      expect(taxation.own_charge_lines).to eq(business_tax: BigDecimal("300"),
                                              furniture_maintenance: BigDecimal("400"),
                                              accounting_fees: BigDecimal("500"))
      expect(taxation.own_charges).to eq(1_200)
    end
  end

  describe "#taxable_income" do
    it "deducts everything it really pays and the whole depreciation when the result holds it" do
      expect(taxation.receipts).to eq(13_200)
      expect(taxation.allowance).to eq(0)
      expect(taxation.result_before_depreciation).to eq(10_000)
      expect(taxation.deducted_depreciation_lines).to eq(building: 6_000, works: 1_000, furniture: 300)
      expect(taxation.depreciation).to eq(7_300)
      expect(taxation.taxable_income).to eq(2_700)
      expect(taxation.carried_forward_depreciation).to eq({})
    end

    it "caps the depreciation at the result and carries the excess forward, the building first" do
      indebted = described_class.new(**attributes, loan_interest: 5_000)

      expect(indebted.deducted_depreciation_lines).to eq(building: 5_000)
      expect(indebted.carried_forward_depreciation).to eq(building: 1_000, works: 1_000, furniture: 300)
      expect(indebted.taxable_income).to eq(0)
      expect(indebted.total).to eq(0)
    end

    it "adds the carry-forward to the annuity and keeps deferring what still does not fit" do
      following = described_class.new(**attributes, loan_interest: 4_000,
                                                    deferred_depreciation: { building: 1_000, works: 1_000,
                                                                             furniture: 300 })

      expect(following.available_depreciation).to eq(building: 7_000, works: 2_000, furniture: 600)
      expect(following.deducted_depreciation_lines).to eq(building: 6_000)
      expect(following.carried_forward_depreciation).to eq(building: 1_000, works: 2_000, furniture: 600)
      expect(following.taxable_income).to eq(0)
    end

    it "consumes the carry-forward in a year the result leaves room for it" do
      comfortable = described_class.new(**attributes, deferred_depreciation: { building: 1_000, works: 1_000,
                                                                               furniture: 300 })

      expect(comfortable.depreciation).to eq(9_600)
      expect(comfortable.taxable_income).to eq(400)
      expect(comfortable.carried_forward_depreciation).to eq({})
    end

    it "gives back to the result the upkeep that the plan depreciates instead" do
      capitalizing = described_class.new(**attributes, capitalized: { works: 600, furniture: 280 })

      expect(capitalizing.capitalized).to eq(880)
      expect(capitalizing.result_before_depreciation).to eq(10_880)
      expect(capitalizing.taxable_income).to eq(3_580)
    end

    it "defers the whole depreciation when the charges have swallowed the receipts" do
      loss = described_class.new(**attributes, loan_interest: 12_000)

      expect(loss.result_before_depreciation).to eq(0)
      expect(loss.deducted_depreciation_lines).to eq({})
      expect(loss.carried_forward_depreciation).to eq(building: 6_000, works: 1_000, furniture: 300)
    end
  end

  describe "the two levies" do
    it "applies the bracket of the household and the social charges of the furnished letting" do
      expect(taxation.income_tax).to eq(810)
      expect(taxation.social_charges_rate).to eq(BigDecimal("18.6"))
      expect(taxation.social_charges).to eq(BigDecimal("502.20"))
      expect(taxation.total).to eq(BigDecimal("1312.20"))
    end
  end

  it "costs less than the micro-BIC on the same year, the depreciation making the difference" do
    expect(taxation.total).to be < Taxation::MicroBic.new(**attributes).total
  end

  it "is the only regime to pay an accountant and to depreciate anything" do
    expect(Taxation::MicroBic.new(**attributes).own_charge_lines)
      .to eq(business_tax: BigDecimal("300"), furniture_maintenance: BigDecimal("400"))
    expect(Taxation::MicroBic.new(**attributes).depreciation).to eq(0)
    expect(Taxation::FoncierReel.new(**attributes).own_charges).to eq(0)
    expect(Taxation::FoncierReel.new(**attributes).depreciation_lines).to eq({})
    expect(Taxation::FoncierReel.new(**attributes, capitalized: { works: 600 }).capitalized).to eq(0)
    expect(Taxation::FoncierReel.new(**attributes).carried_forward_depreciation).to eq({})
  end

  def attributes
    { rent_excluding_charges: 12_000, provision_for_charges: 1_200, marginal_tax_rate: 30, charges: 2_000,
      monthly_rent: 1_000, accounting_fees: 500, furniture_maintenance: 400,
      depreciation: { building: 6_000, works: 1_000, furniture: 300 } }
  end
end
