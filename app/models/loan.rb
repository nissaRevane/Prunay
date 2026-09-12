# Un crédit à mensualités constantes : ce que la banque prête, l'assurance qui s'ajoute sans
# rien amortir, et les frais de signature. Le détail est dans AmortizationSchedule.
class Loan
  MONTHS_PER_YEAR = 12

  # Le 5 du mois de l'acte, ou du mois suivant s'il est signé après le 5.
  PAYMENT_DAY = 5

  # 3 % du capital rendu, plafonné à six mois de ses intérêts.
  EARLY_REPAYMENT_RATE = BigDecimal("3")

  EARLY_REPAYMENT_CAP_MONTHS = 6

  attr_reader :capital, :annual_rate, :duration_years, :insurance, :guarantee_fees, :application_fees,
              :signed_on

  def self.default_insurance(capital, annual_rate) = share(capital, annual_rate.to_d / MONTHS_PER_YEAR)

  def self.default_guarantee_fees(capital, rate) = share(capital, rate)

  def self.default_application_fees(capital, rate, floor)
    return 0 unless capital.to_d.positive?

    [share(capital, rate), floor.to_d].max
  end

  def self.share(capital, rate) = (capital.to_d * rate.to_d / 100).round(2)

  def initialize(capital:, annual_rate:, duration_years:, insurance:, signed_on:,
                 guarantee_fees: 0, application_fees: 0, early_repayment_fee: true)
    # Un taux entier diviserait en entiers : un prêt à 3 % ne coûterait rien.
    @capital = capital.to_d
    @annual_rate = annual_rate.to_d
    @duration_years = duration_years.to_i
    @insurance = insurance.to_d
    @guarantee_fees = guarantee_fees.to_d
    @application_fees = application_fees.to_d
    @early_repayment_fee = early_repayment_fee
    @signed_on = signed_on
  end

  def duration_months = duration_years * MONTHS_PER_YEAR

  def monthly_rate
    @monthly_rate ||= annual_rate / 100 / MONTHS_PER_YEAR
  end

  def amortizable? = signed_on.present? && capital.positive? && duration_months.positive?

  def schedule
    return nil unless amortizable?

    @schedule ||= AmortizationSchedule.new(self)
  end

  def first_payment_on
    month = signed_on.day <= PAYMENT_DAY ? signed_on : signed_on >> 1

    Date.new(month.year, month.month, PAYMENT_DAY)
  end

  def payment_due_on(number) = first_payment_on >> (number - 1)

  def monthly_payment = schedule&.monthly_payment || 0

  def total_monthly_payment = schedule&.total_monthly_payment || 0

  def annual_payment = total_monthly_payment * MONTHS_PER_YEAR

  def annual_payments = schedule&.annual_payments || {}

  def annual_interest = schedule&.annual_interest || {}

  def annual_insurance = schedule&.annual_insurance || {}

  def annual_principal = schedule&.annual_principal || {}

  def annual_remaining_capital = schedule&.annual_remaining_capital || {}

  def early_repayment_fee? = @early_repayment_fee

  def early_repayment_fee(remaining_capital)
    return 0 unless early_repayment_fee?

    remaining = remaining_capital.to_d

    [remaining * EARLY_REPAYMENT_RATE / 100, remaining * monthly_rate * EARLY_REPAYMENT_CAP_MONTHS].min.round(2)
  end

  def total_interest = schedule&.total_interest || 0

  def total_insurance = schedule&.total_insurance || 0

  def upfront_fees
    return 0 unless amortizable?

    guarantee_fees + application_fees
  end

  def total_cost = total_interest + total_insurance + upfront_fees
end
