# Le tableau d'amortissement d'un Loan, une ligne par échéance jusqu'au solde. La mensualité
# sort de la formule de l'annuité constante — M = C × i / (1 − (1 + i)^−n) —, les intérêts se
# lisent sur le capital restant dû, et la dernière échéance solde le résidu d'arrondi.
class AmortizationSchedule
  # Vingt chiffres significatifs : de quoi dépasser de loin le centime où tout s'arrondit.
  PRECISION = 20

  Row = Struct.new(:number, :due_on, :payment, :interest, :principal, :insurance, :remaining_capital,
                   keyword_init: true)

  def initialize(loan)
    @loan = loan
  end

  # Un prêt à taux zéro n'a pas d'intérêts à étaler : il se rend en parts égales.
  def monthly_payment
    @monthly_payment ||=
      if monthly_rate.zero?
        (capital / months).round(2)
      else
        (capital * monthly_rate / (1 - (1 + monthly_rate).power(-months, PRECISION))).round(2)
      end
  end

  def total_monthly_payment = monthly_payment + insurance

  def rows
    @rows ||= build_rows
  end

  def total_interest = rows.sum(&:interest)

  def total_insurance = rows.sum(&:insurance)

  def total_payments = rows.sum(&:payment)

  def annual_payments
    @annual_payments ||= yearly_rows.transform_values { |yearly| yearly.sum(&:payment) }
  end

  # L'assurance se range avec les intérêts : elle se paie sans rien rendre du capital.
  def annual_interest
    @annual_interest ||= yearly_rows.transform_values { |yearly| yearly.sum { |row| row.interest + row.insurance } }
  end

  # La fiche d'une année sépare ce que l'annuité mêle : la prime, seule, n'est pas un intérêt.
  def annual_insurance
    @annual_insurance ||= yearly_rows.transform_values { |yearly| yearly.sum(&:insurance) }
  end

  def annual_principal
    @annual_principal ||= yearly_rows.transform_values { |yearly| yearly.sum(&:principal) }
  end

  # Ce qu'une revente aurait à solder à la banque, année par année.
  def annual_remaining_capital
    @annual_remaining_capital ||= yearly_rows.transform_values { |yearly| yearly.last.remaining_capital }
  end

  private

  def yearly_rows
    @yearly_rows ||= rows.group_by { |row| ((row.number - 1) / Loan::MONTHS_PER_YEAR) + 1 }
  end

  def capital = @loan.capital

  def months = @loan.duration_months

  def monthly_rate = @loan.monthly_rate

  # La même prime à chaque échéance : elle ne se lit pas sur le capital restant dû et n'en rend rien.
  def insurance = @loan.insurance

  def build_rows
    remaining = capital

    (1..months).map do |number|
      interest = (remaining * monthly_rate).round(2)
      principal = (monthly_payment - interest).round(2)
      principal = remaining if last_payment?(number, principal, remaining)

      remaining = (remaining - principal).round(2)

      Row.new(
        number: number,
        due_on: @loan.payment_due_on(number),
        payment: (interest + principal + insurance).round(2),
        interest: interest,
        principal: principal,
        insurance: insurance,
        remaining_capital: remaining
      )
    end
  end

  # L'arrondi de la mensualité au centime ne doit pas déplacer la fin du tableau d'une ligne.
  def last_payment?(number, principal, remaining) = number == months || principal >= remaining
end
