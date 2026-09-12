# Le taux annuel qui annule la valeur actualisée d'une suite de flux, cherché par dichotomie.
# Sans un flux négatif et un flux positif il n'y a pas de taux : #percentage rend nil.
class InternalRateOfReturn
  LOWEST_RATE = BigDecimal("-0.9999")

  HIGHEST_RATE = BigDecimal("10")

  # Deux chiffres sous la décimale du pourcentage affiché.
  PRECISION = BigDecimal("0.00001")

  DIGITS = 20

  attr_reader :cash_flows

  def initialize(cash_flows)
    @cash_flows = cash_flows.map(&:to_d)
  end

  def rate
    return @rate if defined?(@rate)

    @rate = solve
  end

  def above?(rate) = net_present_value(rate).positive?

  def percentage
    found = rate

    (found * 100).round(1) if found
  end

  def net_present_value(rate)
    discount = 1 + rate.to_d
    factor = BigDecimal(1)

    cash_flows.sum do |flow|
      present = flow.div(factor, DIGITS)
      factor = factor.mult(discount, DIGITS)

      present
    end
  end

  private

  def solve
    return if cash_flows.size < 2

    low = LOWEST_RATE
    high = HIGHEST_RATE
    low_positive = net_present_value(low).positive?
    return unless low_positive ^ net_present_value(high).positive?

    while high - low > PRECISION
      middle = (low + high) / 2
      net_present_value(middle).positive? == low_positive ? low = middle : high = middle
    end

    (low + high) / 2
  end
end
