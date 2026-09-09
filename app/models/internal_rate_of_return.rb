# Le taux annuel qui annule la valeur actualisée d'une suite de flux : le premier est
# l'investissement du premier jour, les suivants tombent chacun sur un anniversaire. On le
# cherche par dichotomie, la formule n'ayant pas de solution littérale ; faute d'un flux
# négatif et d'un flux positif il n'y a pas de taux, et #percentage rend nil.
class InternalRateOfReturn
  LOWEST_RATE = BigDecimal("-0.9999")

  HIGHEST_RATE = BigDecimal("10")

  # Le cent-millième : deux chiffres sous la décimale de pourcentage qui se lit.
  PRECISION = BigDecimal("0.00001")

  # Vingt chiffres significatifs par opération : sans quoi l'actualisation en traîne mille.
  DIGITS = 20

  attr_reader :cash_flows

  def initialize(cash_flows)
    @cash_flows = cash_flows.map(&:to_d)
  end

  def rate
    return @rate if defined?(@rate)

    @rate = solve
  end

  # Le taux dépasse-t-il celui-là ? La valeur actualisée décroît quand le taux monte, donc elle est
  # positive ici exactement quand le taux cherché est plus haut — une actualisation au lieu d'une dichotomie.
  def above?(rate) = net_present_value(rate).positive?

  # En pourcentage, comme les taux que l'utilisateur saisit.
  def percentage
    found = rate

    (found * 100).round(1) if found
  end

  # Le facteur d'actualisation se compose d'une année sur l'autre, plutôt que de s'élever à la puissance.
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
