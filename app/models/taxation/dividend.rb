module Taxation
  # L'impôt d'une somme que la société distribue : le prélèvement forfaitaire, ou le barème
  # après abattement quand la tranche du foyer y gagne. Les sociaux sont les mêmes.
  class Dividend
    FLAT_TAX_RATE = BigDecimal("12.8")

    ALLOWANCE_RATE = BigDecimal("40")

    attr_reader :amount, :marginal_tax_rate

    def initialize(amount:, marginal_tax_rate:)
      @amount = amount.to_d
      @marginal_tax_rate = marginal_tax_rate.to_d
    end

    def flat? = progressive_rate >= FLAT_TAX_RATE

    def income_tax_rate = flat? ? FLAT_TAX_RATE : progressive_rate

    def social_charges_rate = CAPITAL_INCOME_SOCIAL_CHARGES_RATE

    def income_tax = share(amount, income_tax_rate)

    def social_charges = share(amount, social_charges_rate)

    def total = income_tax + social_charges

    private

    def progressive_rate = marginal_tax_rate * (100 - ALLOWANCE_RATE) / 100

    def share(amount, rate) = (amount * rate / 100).round(2)
  end
end
