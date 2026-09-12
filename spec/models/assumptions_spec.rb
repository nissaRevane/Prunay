require "rails_helper"

RSpec.describe Assumptions, type: :model do
  let(:user) { create(:user) }

  describe "validations" do
    subject { build(:assumptions) }

    it { is_expected.to validate_presence_of(:rent_growth_rate) }
    it { is_expected.to validate_presence_of(:property_growth_rate) }
    it { is_expected.to validate_presence_of(:inflation_rate) }

    it { is_expected.to validate_numericality_of(:rent_growth_rate).is_greater_than_or_equal_to(described_class::MIN_RATE).is_less_than_or_equal_to(described_class::MAX_RATE) }
    it { is_expected.to validate_numericality_of(:property_growth_rate).is_greater_than_or_equal_to(described_class::MIN_RATE).is_less_than_or_equal_to(described_class::MAX_RATE) }
    it { is_expected.to validate_numericality_of(:inflation_rate).is_greater_than_or_equal_to(described_class::MIN_RATE).is_less_than_or_equal_to(described_class::MAX_RATE) }

    it { is_expected.to validate_inclusion_of(:marginal_tax_rate).in_array(Taxation::MARGINAL_TAX_RATES) }

    it { is_expected.to validate_numericality_of(:monthly_rent).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:sale_diagnostics).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:down_payment_share).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(100) }
    it { is_expected.to validate_numericality_of(:occupancy_months).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(Simulation::MONTHS_PER_YEAR) }
    it { is_expected.to validate_numericality_of(:loan_duration_years).is_greater_than(0).is_less_than_or_equal_to(Simulation::MAX_LOAN_DURATION_YEARS) }
  end

  describe ".for" do
    it "is what Prunay assumes as long as the user has not decided otherwise" do
      assumptions = described_class.for(user)

      expect(assumptions).to be_new_record
      expect(assumptions).to have_attributes(rent_growth_rate: 1, property_growth_rate: 1, inflation_rate: 2,
                                             marginal_tax_rate: 30)
    end

    it "proposes the reference amounts, the credit and what a resale costs" do
      expect(described_class.for(user)).to have_attributes(monthly_rent: 650, furniture: 2_110, accounting_fees: 500,
                                                           occupancy_months: 11, down_payment_share: 10,
                                                           purchase_delay_months: 3, loan_rate: BigDecimal("3.6"),
                                                           loan_duration_years: 20, sale_diagnostics: 400,
                                                           sale_refurbishment: 500)
    end

    it "is what the user has decided once he has decided it" do
      create(:assumptions, user: user, rent_growth_rate: 3)

      expect(described_class.for(user.reload)).to be_persisted
      expect(described_class.for(user.reload).rent_growth_rate).to eq(3)
    end
  end

  describe "#economic" do
    it "reads as the simulation columns of the same name" do
      assumptions = build(:assumptions, rent_growth_rate: 3, property_growth_rate: 4, inflation_rate: 5,
                                        marginal_tax_rate: 41)

      expect(assumptions.economic).to eq("rent_growth_rate" => 3, "property_growth_rate" => 4,
                                         "inflation_rate" => 5, "marginal_tax_rate" => 41)
      expect(build(:simulation, assumptions.economic)).to have_attributes(rent_growth_rate: 3, inflation_rate: 5,
                                                                          marginal_tax_rate: 41)
    end
  end
end
