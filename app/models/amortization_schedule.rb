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
#
# L'assurance emprunteur s'ajoute par-dessus, sans toucher au remboursement : sa prime est la
# même à chaque échéance, elle ne se calcule pas sur le capital restant dû et n'en rembourse
# rien. D'où deux montants distincts sur chaque ligne — +payment+ est ce que la banque
# prélève, assurance comprise, et +monthly_payment+ ce qui sert à amortir le capital.
class AmortizationSchedule
  # La précision des puissances intermédiaires. Vingt chiffres significatifs dépassent de
  # loin le centime où tout finit par s'arrondir.
  PRECISION = 20

  MONTHS_PER_YEAR = 12

  Row = Struct.new(:number, :due_on, :payment, :interest, :principal, :insurance, :remaining_capital,
                   keyword_init: true)

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

  # Ce que l'échéance prélève en tout : la mensualité du prêt et la prime d'assurance, que la
  # banque appelle ensemble.
  def total_monthly_payment
    monthly_payment + insurance
  end

  def rows
    @rows ||= build_rows
  end

  # Ce que le capital coûte : tout ce qui a été payé, moins le capital rendu et moins
  # l'assurance, qui ne se prête pas.
  def total_interest
    rows.sum(&:interest)
  end

  # Ce que l'assurance coûte sur toute la durée : la même prime, une fois par échéance.
  def total_insurance
    rows.sum(&:insurance)
  end

  # Tout ce qui a été prélevé, assurance comprise.
  def total_payments
    rows.sum(&:payment)
  end

  # Ce que le crédit prélève sur chaque année de la projection, assurance comprise, indexé par
  # le numéro de l'année. Les échéances 1 à 12 tombent dans la première année, les suivantes
  # douze par douze : une année pleine porte donc douze échéances, la dernière ce qu'il en reste, et
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

  # La prime d'assurance d'une échéance : celle que la simulation porte, identique du premier
  # prélèvement au dernier.
  def insurance
    @insurance ||= @simulation.loan_insurance
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
        payment: (interest + principal + insurance).round(2),
        interest: interest,
        principal: principal,
        insurance: insurance,
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
