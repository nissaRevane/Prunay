require "rails_helper"

RSpec.describe SaleCosts do
  it "charges the flat diagnostics and the reference refurbishment at the reference surface" do
    costs = described_class.new(surface: 50)

    expect(costs.diagnostics).to eq(400)
    expect(costs.refurbishment).to eq(500)
    expect(costs.total).to eq(900)
  end

  it "scales the refurbishment by the square root of the surface" do
    expect(described_class.new(surface: 200).refurbishment).to eq(1_000)
    expect(described_class.new(surface: 200).total).to eq(1_400)
  end

  it "still owes the whole diagnostics on a small surface" do
    expect(described_class.new(surface: 12.5).total).to eq(650)
  end

  it "charges what the account has settled" do
    costs = described_class.new(surface: 50, diagnostics: 600, refurbishment: 1_200)

    expect(costs.total).to eq(1_800)
  end
end
