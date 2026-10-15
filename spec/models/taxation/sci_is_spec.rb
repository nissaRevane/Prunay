require "rails_helper"

RSpec.describe Taxation::SciIs do
  subject(:taxation) { described_class.new(**attributes) }

  it "pays the accountant and depreciates neither furniture nor its renewal, the letting being unfurnished" do
    capitalizing = described_class.new(**attributes, capitalized: { works: 600, furniture: 280 })

    expect(taxation.own_charge_lines).to eq(accounting_fees: BigDecimal("500"))
    expect(taxation.depreciation_lines).to eq(building: 6_000, works: 1_000)
    expect(capitalizing.capitalized_lines).to eq(works: 600)
  end

  it "deducts the charges, the accountant, the interest and the depreciation: 30 000 - 2 000 - 500 - 3 000 - 7 000" do
    expect(taxation.result).to eq(17_500)
    expect(taxation.taxable_income).to eq(17_500)
    expect(taxation.corporate_tax).to eq(2_625)
    expect(taxation.net_income).to eq(14_875)
  end

  it "owes no income tax nor social charges, whatever the household's bracket" do
    expect(taxation.income_tax).to eq(0)
    expect(taxation.social_charges).to eq(0)
    expect(taxation.total).to eq(2_625)
  end

  it "gives back to the result the heavy works the plan depreciates instead: 17 500 + 600" do
    expect(described_class.new(**attributes, capitalized: { works: 600 }).result).to eq(18_100)
  end

  it "deducts the formation costs from the year that bears them: 17 500 - 1 000" do
    expect(described_class.new(**attributes, formation_costs: 1_000).result).to eq(16_500)
  end

  it "never caps the depreciation and carries the loss forward: 30 000 - 2 000 - 500 - 40 000 - 7 000" do
    indebted = described_class.new(**attributes, loan_interest: 40_000)

    expect(indebted.result).to eq(-19_500)
    expect(indebted.carried_forward_deficit).to eq(19_500)
    expect(indebted.total).to eq(0)
    expect(indebted.net_income).to eq(-19_500)
  end

  it "consumes the deficit of past years before taxing: 17 500 - 10 000" do
    following = described_class.new(**attributes, deferred_deficit: 10_000)

    expect(following.taxable_income).to eq(7_500)
    expect(following.corporate_tax).to eq(1_125)
    expect(following.carried_forward_deficit).to eq(0)
  end

  it "carries what the year could not absorb: 20 000 of deficit against 17 500" do
    expect(described_class.new(**attributes, deferred_deficit: 20_000).carried_forward_deficit).to eq(2_500)
  end

  it "taxes 15 % up to 42 500 and 25 % beyond: 6 375 + 1 875 on 50 000" do
    expect(described_class.corporate_tax_on(50_000)).to eq(8_250)
    expect(described_class.corporate_tax_on(-1_000)).to eq(0)
  end

  def attributes
    { rent_excluding_charges: 30_000, marginal_tax_rate: 45, charges: 2_000, loan_interest: 3_000,
      accounting_fees: 500, furniture_maintenance: 400, depreciation: { building: 6_000, works: 1_000, furniture: 300 } }
  end
end
