# Un crédit à mensualités constantes : ce que la banque prête, à quelles conditions,
# l'assurance emprunteur qui s'ajoute à chaque échéance sans rien amortir, et les frais
# qu'il coûte à la signature. Le détail échéance par échéance est dans AmortizationSchedule.
class Loan
  MONTHS_PER_YEAR = 12

  PAYMENT_DAY = 5

  DEFAULT_RATE = BigDecimal("3.5")

  DEFAULT_DURATION_YEARS = 20

  # La prime proposée : un dix-millième du capital emprunté par mois, soit 0,12 % par an.
  DEFAULT_INSURANCE_DIVISOR = 10_000

  # Un soixantième du capital emprunté : l'ordre de grandeur d'une caution bancaire comme d'une hypothèque.
  DEFAULT_GUARANTEE_FEES_DIVISOR = 60

  DEFAULT_APPLICATION_FEES_DIVISOR = 100

  # Aucune banque n'ouvre un dossier pour moins : la proposition ne descend pas sous ce plancher.
  MIN_APPLICATION_FEES = 500

  # Ce que la banque prend d'un crédit soldé avant terme : 3 % du capital rendu, sans dépasser
  # six mois de ses intérêts. Sous 6 % l'an, c'est toujours le plafond qui s'applique.
  EARLY_REPAYMENT_RATE = BigDecimal("3")

  EARLY_REPAYMENT_CAP_MONTHS = 6

  attr_reader :capital, :annual_rate, :duration_years, :insurance, :guarantee_fees, :application_fees,
              :signed_on

  def self.default_insurance(capital) = (capital.to_d / DEFAULT_INSURANCE_DIVISOR).round(2)

  def self.default_guarantee_fees(capital) = (capital.to_d / DEFAULT_GUARANTEE_FEES_DIVISOR).round(2)

  # Rien à emprunter, rien à instruire : le plancher ne s'applique qu'à un dossier qui existe.
  def self.default_application_fees(capital)
    return 0 unless capital.to_d.positive?

    [(capital.to_d / DEFAULT_APPLICATION_FEES_DIVISOR).round(2), BigDecimal(MIN_APPLICATION_FEES)].max
  end

  def initialize(capital:, annual_rate:, duration_years:, insurance:, signed_on:,
                 guarantee_fees: 0, application_fees: 0)
    # Décimaux d'office : un taux entier diviserait en entiers, et un prêt à 3 % ne coûterait rien.
    @capital = capital.to_d
    @annual_rate = annual_rate.to_d
    @duration_years = duration_years.to_i
    @insurance = insurance.to_d
    @guarantee_fees = guarantee_fees.to_d
    @application_fees = application_fees.to_d
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

  # Le 5 du mois de l'acte quand il est signé du 1er au 5, le 5 du mois d'après sinon.
  def first_payment_on
    month = signed_on.day <= PAYMENT_DAY ? signed_on : signed_on >> 1

    Date.new(month.year, month.month, PAYMENT_DAY)
  end

  # Comptée depuis la première et non depuis la précédente : toutes tombent le même jour du mois.
  def payment_due_on(number) = first_payment_on >> (number - 1)

  def monthly_payment = schedule&.monthly_payment || 0

  # La banque appelle la mensualité et la prime ensemble.
  def total_monthly_payment = schedule&.total_monthly_payment || 0

  def annual_payment = total_monthly_payment * MONTHS_PER_YEAR

  def annual_payments = schedule&.annual_payments || {}

  # Le compte de résultat sépare les deux : les intérêts et la prime sont une charge, le capital non.
  def annual_interest = schedule&.annual_interest || {}

  def annual_principal = schedule&.annual_principal || {}

  # Ce qu'une revente aurait à rembourser par anticipation, année par année.
  def annual_remaining_capital = schedule&.annual_remaining_capital || {}

  def early_repayment_fee(remaining_capital)
    remaining = remaining_capital.to_d

    [remaining * EARLY_REPAYMENT_RATE / 100, remaining * monthly_rate * EARLY_REPAYMENT_CAP_MONTHS].min.round(2)
  end

  def total_interest = schedule&.total_interest || 0

  def total_insurance = schedule&.total_insurance || 0

  # Cautionnement et frais de dossier : payés à la signature, une fois, et non étalés.
  def upfront_fees
    return 0 unless amortizable?

    guarantee_fees + application_fees
  end

  # Les intérêts seuls sous-estiment le crédit : l'assurance et les frais de signature comptent.
  def total_cost = total_interest + total_insurance + upfront_fees
end
