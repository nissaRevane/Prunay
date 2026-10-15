module Taxation
  # La revente par la SCI puis sa dissolution : la plus-value professionnelle rejoint le résultat
  # de l'année à l'IS, les dettes se paient, et le boni se taxe comme un dividende.
  class Liquidation
    # Sur l'actif partagé entre associés (art. 746 CGI).
    PARTITION_DUTY_RATE = BigDecimal("2.5")

    attr_reader :sale_price, :book_value, :costs, :remaining_loan, :treasury, :current_account, :result,
                :marginal_tax_rate

    def initialize(sale_price:, book_value:, costs:, remaining_loan:, treasury:, current_account:,
                   marginal_tax_rate:, result: 0)
      @sale_price = sale_price.to_d
      @book_value = book_value.to_d
      @costs = costs.to_d
      @remaining_loan = remaining_loan.to_d
      @treasury = treasury.to_d
      @current_account = current_account.to_d
      @marginal_tax_rate = marginal_tax_rate.to_d
      @result = result.to_d
    end

    def amount = [sale_price - book_value, 0].max

    # Ce que la revente ajoute à l'IS que l'année devait déjà.
    def corporate_tax
      SciIs.corporate_tax_on(result + sale_price - book_value - costs) - SciIs.corporate_tax_on(result)
    end

    def net_assets = treasury + sale_price - costs - remaining_loan - corporate_tax

    def bonus = [net_assets - current_account, 0].max

    def bonus_taxation
      @bonus_taxation ||= Dividend.new(amount: bonus, marginal_tax_rate: marginal_tax_rate)
    end

    def partition_duty = (bonus * PARTITION_DUTY_RATE / 100).round(2)

    def total = corporate_tax + bonus_taxation.total + partition_duty
  end
end
