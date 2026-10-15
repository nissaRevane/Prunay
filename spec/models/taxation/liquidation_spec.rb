require "rails_helper"

RSpec.describe Taxation::Liquidation do
  subject(:liquidation) { described_class.new(**attributes) }

  it "taxes the gain over the book value at corporate tax, costs deducted: 6 375 + 5 625 on 65 000" do
    expect(liquidation.amount).to eq(70_000)
    expect(liquidation.corporate_tax).to eq(12_000)
  end

  it "pays the debts, then taxes the bonus like a dividend plus the partition duty" do
    expect(liquidation.net_assets).to eq(135_000)
    expect(liquidation.bonus).to eq(105_000)
    expect(liquidation.bonus_taxation.total).to eq(32_970)
    expect(liquidation.partition_duty).to eq(2_625)
    expect(liquidation.total).to eq(47_595)
  end

  it "taxes the gain at 25 % alone when the year's profit already fills the reduced rate" do
    expect(described_class.new(**attributes, result: 50_000).corporate_tax).to eq(16_250)
  end

  it "sets the deficit still carried against the gain: 6 375 + 625 on 45 000" do
    expect(described_class.new(**attributes, result: -20_000).corporate_tax).to eq(7_000)
  end

  it "leaves no bonus when the sale does not cover the loan and the current account" do
    underwater = described_class.new(**attributes, sale_price: 100_000, book_value: 100_000,
                                                   remaining_loan: 120_000)

    expect(underwater.net_assets).to eq(-23_000)
    expect(underwater.bonus).to eq(0)
    expect(underwater.total).to eq(0)
  end

  def attributes
    { sale_price: 250_000, book_value: 180_000, costs: 5_000, remaining_loan: 100_000, treasury: 2_000,
      current_account: 30_000, marginal_tax_rate: 30 }
  end
end
