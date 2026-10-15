require "rails_helper"

RSpec.describe Taxation::Dividend do
  it "takes the flat tax at a 30 % bracket, 60 % of which would cost 18 %: 128 + 186 on 1 000" do
    dividend = described_class.new(amount: 1_000, marginal_tax_rate: 30)

    expect(dividend).to be_flat
    expect(dividend.income_tax).to eq(128)
    expect(dividend.social_charges).to eq(186)
    expect(dividend.total).to eq(314)
  end

  it "opts for the bracket at 11 %, on 60 % of the dividend: 66 + 186 on 1 000" do
    dividend = described_class.new(amount: 1_000, marginal_tax_rate: 11)

    expect(dividend).not_to be_flat
    expect(dividend.income_tax_rate).to eq(BigDecimal("6.6"))
    expect(dividend.total).to eq(252)
  end

  it "leaves only the social charges to a household without income tax" do
    expect(described_class.new(amount: 1_000, marginal_tax_rate: 0).total).to eq(186)
  end
end
