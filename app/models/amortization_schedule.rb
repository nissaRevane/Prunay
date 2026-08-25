# Le tableau d'amortissement d'un crédit à mensualités constantes, déduit du capital
# emprunté, du taux et de la durée que porte la simulation.
#
# C'est l'inverse du tableau de Milly, qui recopie une mensualité déjà négociée : ici rien
# n'est signé, et la mensualité est le résultat, pas la donnée. Elle sort de la formule
# classique de l'annuité constante — M = C × i / (1 − (1 + i)^−n), où i est le taux mensuel
# et n le nombre d'échéances — puis s'arrondit au centime, comme une banque l'énonce.
#
# Le reste suit le même chemin que Milly : intérêts = CRD × i arrondis au centime, capital =
# mensualité − intérêts, et le CRD diminue du capital remboursé. La dernière échéance solde
# le résidu d'arrondi — quelques centimes que la mensualité arrondie laisse derrière elle —
# plutôt que de le laisser traîner sous une ligne à zéro.
class AmortizationSchedule
  # La précision des puissances intermédiaires. Vingt chiffres significatifs dépassent de
  # loin le centime où tout finit par s'arrondir.
  PRECISION = 20

  MONTHS_PER_YEAR = 12

  Row = Struct.new(:number, :due_on, :payment, :interest, :principal, :remaining_capital, keyword_init: true)

  def initialize(simulation)
    @simulation = simulation
  end

  # La mensualité qu'il faut payer pour rembourser le capital en +months+ échéances au taux
  # convenu. Un prêt à taux zéro n'a pas d'intérêts à étaler : il se rend en parts égales.
  def monthly_payment
    @monthly_payment ||=
      if monthly_rate.zero?
        (capital / months).round(2)
      else
        (capital * monthly_rate / (1 - (1 + monthly_rate).power(-months, PRECISION))).round(2)
      end
  end

  def rows
    @rows ||= build_rows
  end

  # Ce que le crédit coûte : tout ce qui a été payé, moins le capital rendu.
  def total_interest
    rows.sum(&:interest)
  end

  def total_payments
    rows.sum(&:payment)
  end

  # Ce que le crédit prélève sur chaque année de la projection, indexé par le numéro de
  # l'année. Les échéances 1 à 12 tombent dans la première année, les suivantes douze par
  # douze : une année pleine porte donc douze mensualités, la dernière ce qu'il en reste, et
  # les années d'après plus rien. Le crédit cesse ainsi de peser le jour où il est soldé,
  # sans que la projection ait à connaître les dates.
  def annual_payments
    @annual_payments ||= rows.group_by { |row| ((row.number - 1) / MONTHS_PER_YEAR) + 1 }
                             .transform_values { |yearly| yearly.sum(&:payment) }
  end

  private

  def capital
    @capital ||= @simulation.borrowed_capital
  end

  def months
    @months ||= @simulation.loan_duration_months
  end

  def monthly_rate
    @monthly_rate ||= @simulation.loan_rate / 100 / MONTHS_PER_YEAR
  end

  def build_rows
    remaining = capital

    (1..months).map do |number|
      interest = (remaining * monthly_rate).round(2)
      principal = (monthly_payment - interest).round(2)
      principal = remaining if last_payment?(number, principal, remaining)

      remaining = (remaining - principal).round(2)

      Row.new(
        number: number,
        due_on: @simulation.loan_payment_due_on(number),
        payment: (interest + principal).round(2),
        interest: interest,
        principal: principal,
        remaining_capital: remaining
      )
    end
  end

  # L'échéance qui solde le prêt : la dernière, et toute échéance dont le capital calculé
  # dépasserait le capital restant — l'arrondi de la mensualité au centime avance ou retarde
  # de quelques centimes la fin du tableau, il ne doit pas la déplacer d'une ligne.
  def last_payment?(number, principal, remaining)
    number == months || principal >= remaining
  end
end
