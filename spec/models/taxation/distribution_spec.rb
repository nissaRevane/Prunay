require "rails_helper"

RSpec.describe Taxation::Distribution do
  it "repays the current account first, untaxed, while there is some left" do
    distribution = described_class.new(company_cash_flow: 4_000, net_income: 1_000, marginal_tax_rate: 30,
                                       current_account: 20_000)

    expect(distribution.current_account_repayment).to eq(4_000)
    expect(distribution.dividends).to eq(0)
    expect(distribution.cash_flow).to eq(4_000)
    expect(distribution.current_account).to eq(16_000)
    expect(distribution.retained_earnings).to eq(1_000)
  end

  it "pays the rest out as dividends once the account is settled: 1 500 + 2 500 - 785" do
    distribution = described_class.new(company_cash_flow: 4_000, net_income: 2_000, marginal_tax_rate: 30,
                                       current_account: 1_500, retained_earnings: 10_000)

    expect(distribution.current_account_repayment).to eq(1_500)
    expect(distribution.dividends).to eq(2_500)
    expect(distribution.dividend_tax).to eq(785)
    expect(distribution.cash_flow).to eq(3_215)
    expect(distribution.retained_earnings).to eq(9_500)
    expect(distribution.treasury).to eq(0)
  end

  it "distributes no more than the profit and keeps the rest: 3 000 earned on 1 000 of past losses" do
    distribution = described_class.new(company_cash_flow: 4_000, net_income: 3_000, marginal_tax_rate: 0,
                                       retained_earnings: -1_000)

    expect(distribution.dividends).to eq(2_000)
    expect(distribution.treasury).to eq(2_000)
    expect(distribution.treasury_change).to eq(2_000)
    expect(distribution.cash_flow).to eq(1_628)
  end

  it "has the associate lend the shortfall, which raises the current account" do
    distribution = described_class.new(company_cash_flow: -3_000, net_income: -500, marginal_tax_rate: 30,
                                       current_account: 20_000)

    expect(distribution.contribution).to eq(3_000)
    expect(distribution.cash_flow).to eq(-3_000)
    expect(distribution.current_account).to eq(23_000)
    expect(distribution.treasury).to eq(0)
  end

  it "covers a shortfall from the treasury before asking the associate" do
    distribution = described_class.new(company_cash_flow: -3_000, net_income: -500, marginal_tax_rate: 30,
                                       treasury: 5_000, retained_earnings: -1_000)

    expect(distribution.contribution).to eq(0)
    expect(distribution.cash_flow).to eq(0)
    expect(distribution.treasury).to eq(2_000)
  end
end
