require "rails_helper"

RSpec.describe InternalRateOfReturn do
  it "is the rate a single repayment implies" do
    expect(described_class.new([-1_000, 1_100]).percentage).to eq(10)
  end

  it "compounds the rate over the years the flows wait" do
    expect(described_class.new([-1_000, 0, 1_210]).percentage).to eq(10)
  end

  it "is negative when the flows give back less than what they cost" do
    expect(described_class.new([-1_000, 900]).percentage).to eq(-10)
  end

  it "annuls the present value of the flows it is read on" do
    irr = described_class.new([-10_000, -500, 1_200, 1_200, 12_000])

    expect(irr.net_present_value(irr.rate).abs).to be < 0.2
  end

  it "tells whether its rate is above another one" do
    irr = described_class.new([-1_000, 1_100])

    expect(irr).to be_above(BigDecimal("0.09"))
    expect(irr).not_to be_above(BigDecimal("0.11"))
  end

  it "has no rate when nothing ever comes back" do
    expect(described_class.new([-1_000, -100]).percentage).to be_nil
  end

  it "has no rate when nothing was ever engaged" do
    expect(described_class.new([1_000, 100]).percentage).to be_nil
  end

  it "has no rate on a lone flow" do
    expect(described_class.new([-1_000]).percentage).to be_nil
    expect(described_class.new([]).percentage).to be_nil
  end
end
