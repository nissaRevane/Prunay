module Taxation
  # Ce que la SCI rend à l'associé dans l'année : le compte courant d'abord, sans impôt, puis
  # des dividendes dans la limite du bénéfice distribuable. Un trou se comble en compte courant.
  class Distribution
    attr_reader :company_cash_flow, :net_income, :marginal_tax_rate, :opening_treasury, :opening_current_account,
                :opening_retained_earnings

    def initialize(company_cash_flow:, net_income:, marginal_tax_rate:, treasury: 0, current_account: 0,
                   retained_earnings: 0)
      @company_cash_flow = company_cash_flow.to_d
      @net_income = net_income.to_d
      @marginal_tax_rate = marginal_tax_rate.to_d
      @opening_treasury = treasury.to_d
      @opening_current_account = current_account.to_d
      @opening_retained_earnings = retained_earnings.to_d
    end

    def contribution = [-(opening_treasury + company_cash_flow), 0].max

    def current_account_repayment = [available, opening_current_account + contribution].min

    def dividends = [available - current_account_repayment, [distributable, 0].max].min

    def dividend
      @dividend ||= Dividend.new(amount: dividends, marginal_tax_rate: marginal_tax_rate)
    end

    def dividend_tax = dividend.total

    def paid = current_account_repayment + dividends - contribution

    def cash_flow = paid - dividend_tax

    def treasury = available - current_account_repayment - dividends

    def treasury_change = treasury - opening_treasury

    def current_account = opening_current_account + contribution - current_account_repayment

    def retained_earnings = distributable - dividends

    def balances = { treasury: treasury, current_account: current_account, retained_earnings: retained_earnings }

    private

    def available = opening_treasury + company_cash_flow + contribution

    def distributable = opening_retained_earnings + net_income
  end
end
