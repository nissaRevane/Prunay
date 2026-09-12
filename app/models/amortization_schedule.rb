# Le tableau d'amortissement d'un Loan, une ligne par échéance : mensualité constante
# M = C × i / (1 − (1 + i)^−n), et la dernière échéance solde le résidu d'arrondi.
class AmortizationSchedule
  # Vingt chiffres : bien au-delà du centime où tout s'arrondit.
  PRECISION = 20

  Row = Struct.new(:number, :due_on, :payment, :interest, :principal, :insurance, :remaining_capital,
                   keyword_init: true)

  def initialize(loan)
    @loan = loan
  end

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

  def annual_interest
    @annual_interest ||= yearly_rows.transform_values { |yearly| yearly.sum { |row| row.interest + row.insurance } }
  end

  def annual_insurance
    @annual_insurance ||= yearly_rows.transform_values { |yearly| yearly.sum(&:insurance) }
  end

  def annual_principal
    @annual_principal ||= yearly_rows.transform_values { |yearly| yearly.sum(&:principal) }
  end

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

  def last_payment?(number, principal, remaining) = number == months || principal >= remaining
end
