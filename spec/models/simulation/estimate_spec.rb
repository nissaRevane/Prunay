require "rails_helper"

RSpec.describe Simulation::Estimate do
  subject(:estimate) { described_class.new(Assumptions.new) }

  describe "#for" do
    it "scales a reference amount by the square root of the surface" do
      expect(estimate.for(:monthly_rent, 50)).to eq(650)
      expect(estimate.for(:monthly_rent, 200)).to eq(1_300)
    end

    it "rounds to the nearest ten euros" do
      expect(estimate.for(:property_tax, 30)).to eq(540)
      expect(estimate.for(:insurance, 30)).to eq(120)
      expect(estimate.for(:maintenance, 30)).to eq(770)
      expect(estimate.for(:condominium_fees, 30)).to eq(770)
      expect(estimate.for(:other_charges, 30)).to eq(80)
    end

    it "leaves the amounts that do not follow the surface where they are" do
      expect(estimate.for(:management_fees, 200)).to eq(0)
      expect(estimate.for(:rent_guarantee, 200)).to eq(0)
    end

    it "scales the furniture and its upkeep like the rest" do
      expect(estimate.for(:furniture, 50)).to eq(2_110)
      expect(estimate.for(:furniture, 200)).to eq(4_220)
      expect(estimate.for(:furniture_maintenance, 50)).to eq(370)
      expect(estimate.for(:furniture_maintenance, 200)).to eq(740)
    end

    it "has nothing to propose without a surface" do
      expect(estimate.for(:monthly_rent, nil)).to eq(0)
      expect(estimate.for(:monthly_rent, 0)).to eq(0)
    end

    it "reads the references of the account" do
      raised = described_class.new(Assumptions.new(monthly_rent: 900, management_fees: 40))

      expect(raised.for(:monthly_rent, 50)).to eq(900)
      expect(raised.for(:management_fees, 50)).to eq(40)
    end
  end

  describe "#down_payment" do
    it "is the share of the project cost the account expects, rounded like the rest" do
      expect(estimate.down_payment(BigDecimal("216612"))).to eq(21_660)
      expect(described_class.new(Assumptions.new(down_payment_share: 20)).down_payment(BigDecimal("216612")))
        .to eq(43_320)
    end
  end
end
