# Le tableau de bord à une année de revente : les régimes classés par leur taux, ce que la mise
# de départ recouvre, ce qu'une année laisse, et ce qui cloche.
class Simulation::Dashboard
  # En dessous, les loyers ne couvrent pas l'usure du bien.
  GROSS_YIELD_FLOOR = BigDecimal("5")

  POOR_ENERGY_RATINGS = %w[F G].freeze

  CREDIT_OUTLAY = %i[down_payment loan_guarantee_fees loan_application_fees].freeze

  CASH_OUTLAY = %i[purchase_price notary_fees initial_works].freeze

  Alert = Struct.new(:key, :values, keyword_init: true)

  Row = Struct.new(:regime, :projection, :year, keyword_init: true) do
    def rate = projection.internal_rate_of_return(year)

    def monthly_cash_flow = (year.cash_flow / Simulation::MONTHS_PER_YEAR).round(2)

    def taxes = projection.tax_lines(year).values.sum

    def immobilized_capital = year.immobilized_capital

    def sale_profit = year.sale_profit

    def initial_outlay = projection.initial_outlay
  end

  attr_reader :simulation, :projections, :exit_year

  def initialize(simulation, projections, exit_year)
    @simulation = simulation
    @projections = projections
    @exit_year = exit_year
  end

  def rows
    @rows ||= projections.map { |regime, projection|
      Row.new(regime: regime, projection: projection, year: projection.year(exit_year))
    }.sort_by { |row| [row.rate ? 0 : 1, -(row.rate || 0)] }
  end

  def best = rows.first

  def regime = best.regime

  def exit_date = best.year.date

  def annual_cash_flow = best.year.cash_flow

  def gross_yield
    investment = simulation.total_investment_under(regime)
    return 0 if investment.zero?

    (best.year.rent_excluding_charges / investment * 100).round(2)
  end

  def outlay_lines
    fields = simulation.credit? ? CREDIT_OUTLAY : CASH_OUTLAY
    lines = fields.index_with { |field| simulation.public_send(field) }

    without_zeros(lines.merge(furniture: simulation.furniture_under(regime)))
  end

  def annual_lines
    year = best.year

    without_zeros({ rent: year.rent_including_charges, charges: -year.charges_including_provision,
                    loan_interest: -year.loan_interest, taxes: -year.taxes,
                    capital_repayment: -year.capital_repayment })
  end

  def alerts
    [energy_alert, return_alert, yield_alert].compact
  end

  private

  def energy_alert
    return unless POOR_ENERGY_RATINGS.include?(simulation.energy_rating)

    Alert.new(key: :energy_rating, values: { rating: simulation.energy_rating })
  end

  # Un taux refusé revient vide : la projection le lit déjà comme zéro.
  def return_alert
    return Alert.new(key: :no_return, values: {}) if best.rate.nil?

    inflation = simulation.inflation_rate.to_d
    return unless best.rate < inflation

    Alert.new(key: :below_inflation, values: { rate: inflation })
  end

  def yield_alert
    return unless gross_yield < GROSS_YIELD_FLOOR

    Alert.new(key: :low_gross_yield, values: { rate: gross_yield })
  end

  def without_zeros(lines) = lines.reject { |_, amount| amount.zero? }
end
