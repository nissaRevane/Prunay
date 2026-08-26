# Un crédit à mensualités constantes : ce que la banque prête, à quelles conditions, et
# l'assurance emprunteur qui s'ajoute à chaque échéance sans rien amortir. Le détail
# échéance par échéance est dans AmortizationSchedule.
class Loan
  MONTHS_PER_YEAR = 12

  # Le jour du mois où la banque prélève.
  PAYMENT_DAY = 5

  DEFAULT_RATE = BigDecimal("3.5")

  DEFAULT_DURATION_YEARS = 20

  # La prime proposée : un dix-millième du capital emprunté par mois, soit 0,12 % par an.
  DEFAULT_INSURANCE_DIVISOR = 10_000

  attr_reader :capital, :annual_rate, :duration_years, :insurance, :signed_on

  def self.default_insurance(capital)
    (capital.to_d / DEFAULT_INSURANCE_DIVISOR).round(2)
  end

  def initialize(capital:, annual_rate:, duration_years:, insurance:, signed_on:)
    # Décimaux d'office : un taux entier diviserait en entiers, et un prêt à 3 % ne coûterait rien.
    @capital = capital.to_d
    @annual_rate = annual_rate.to_d
    @duration_years = duration_years.to_i
    @insurance = insurance.to_d
    @signed_on = signed_on
  end

  def duration_months
    duration_years * MONTHS_PER_YEAR
  end

  def monthly_rate
    @monthly_rate ||= annual_rate / 100 / MONTHS_PER_YEAR
  end

  # De quoi produire un tableau : une signature, une durée, et quelque chose à emprunter.
  def amortizable?
    signed_on.present? && capital.positive? && duration_months.positive?
  end

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
  def payment_due_on(number)
    first_payment_on >> (number - 1)
  end

  def monthly_payment
    schedule&.monthly_payment || 0
  end

  # Ce que la banque prélève réellement : la mensualité et la prime, qu'elle appelle ensemble.
  def total_monthly_payment
    schedule&.total_monthly_payment || 0
  end

  # Douze échéances, assurance comprise : ce que le crédit prélève sur une année pleine.
  def annual_payment
    total_monthly_payment * MONTHS_PER_YEAR
  end

  # Ce que le crédit prélève sur chaque année de la projection, indexé par numéro d'année.
  def annual_payments
    schedule&.annual_payments || {}
  end

  def total_interest
    schedule&.total_interest || 0
  end

  def total_insurance
    schedule&.total_insurance || 0
  end

  # Le chiffre à comparer au capital emprunté : les intérêts sans l'assurance le sous-estiment.
  def total_cost
    total_interest + total_insurance
  end
end
