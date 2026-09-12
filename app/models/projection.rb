# La projection sur trente ans, une ligne par anniversaire, précédée de l'année zéro : la
# signature, où rien n'est encaissé. L'impôt de chaque année revient à Taxation.
class Projection
  HORIZON_YEARS = 30

  REVIEW_YEAR = 15

  VIEWS = %w[result sale].freeze

  TAX_COMPONENTS = %i[notary_fees property_tax business_tax income_tax social_charges
                      capital_gain_tax].freeze

  Year = Struct.new(:number, :date, :rent_excluding_charges, :charges_excluding_provision,
                    :provision_for_charges, :loan_interest, :loan_insurance, :capital_repayment,
                    :taxation, :gain, :immobilized_capital, :property_value,
                    :remaining_loan_capital, :sale_costs, :early_repayment_fee, keyword_init: true) do
    def taxes = taxation.total

    def capital_gain = gain.amount

    def capital_gain_tax = gain.total

    def interest_excluding_insurance = loan_interest - loan_insurance

    # Les intérêts sont une charge, le capital rendu non : il va au cash-flow.
    def pre_tax_result = rent_excluding_charges - charges_excluding_provision - loan_interest

    def net_result = pre_tax_result - taxes

    def cash_flow = net_result - capital_repayment

    def rent_including_charges = rent_excluding_charges + provision_for_charges

    def charges_including_provision = charges_excluding_provision + provision_for_charges

    def loan_payments = loan_interest + capital_repayment

    def recovered? = immobilized_capital <= 0

    def sale_proceeds = property_value - sale_costs - capital_gain_tax - remaining_loan_capital -
                        early_repayment_fee

    def sale_profit = sale_proceeds - immobilized_capital
  end

  attr_reader :simulation, :regime

  def initialize(simulation, regime)
    @simulation = simulation
    @regime = regime
  end

  def years
    @years ||= build_years
  end

  def year(number) = years.find { |year| year.number == number }

  # Le meublé déclare la provision et déduit ce qu'elle couvre, le foncier non.
  def provision_in_receipts? = Taxation.regime(regime).provision_in_receipts?

  def rent_column = provision_in_receipts? ? "annual_rent_including_charges_column" : "annual_rent_column"

  def rent_of(year) = provision_in_receipts? ? year.rent_including_charges : year.rent_excluding_charges

  def charges_of(year)
    provision_in_receipts? ? year.charges_including_provision : year.charges_excluding_provision
  end

  def total_rent = years.sum(&:rent_excluding_charges)

  def total_charges = years.sum(&:charges_excluding_provision)

  def total_taxes = years.sum(&:taxes)

  def tax_lines(exit_year)
    lines = years.take(exit_year.number + 1).each_with_object(Hash.new(0)) do |year, totals|
      totals[:property_tax] += charge_lines(year).fetch(:property_tax, 0)
      totals[:business_tax] += year.taxation.business_tax
      totals[:income_tax] += year.taxation.income_tax
      totals[:social_charges] += year.taxation.social_charges
    end

    without_zeros({ notary_fees: @simulation.notary_fees }
                    .merge(lines).merge(capital_gain_tax: exit_year.capital_gain_tax))
  end

  def final_immobilized_capital = years.last.immobilized_capital

  def purchase_price = @simulation.purchase_price

  def market_value = @simulation.market_value

  def purchase_discount = @simulation.purchase_discount

  def occupancy_months = @simulation.occupancy_months

  def initial_outlay = @simulation.initial_outlay(regime)

  def cash_flows = @cash_flows ||= years.map(&:cash_flow)

  def cumulative_cash_flow(year) = cash_flows.take(year.number + 1).sum

  def internal_rate_of_return(year) = rate_of_return(year).percentage

  def rate_of_return(year)
    @rates_of_return ||= {}
    @rates_of_return[year.number] ||= InternalRateOfReturn.new(exit_cash_flows(year))
  end

  def monthly_rent_of(year) = indexed(@simulation.monthly_rent_under(regime), @simulation.rent_growth_rate, year)

  def monthly_provision_of(year) = indexed(@simulation.monthly_charges, @simulation.inflation_rate, year)

  def charge_lines(year)
    return {} if year.number.zero?

    lines = Simulation::ANNUAL_CHARGES.index_with do |field|
      indexed(@simulation.public_send(field), @simulation.inflation_rate, year)
    end

    without_zeros(lines.merge(year.taxation.own_charge_lines))
  end

  def sale_cost_lines(year)
    costs = @simulation.sale_costs
    lines = { diagnostics: costs.diagnostics, refurbishment: costs.refurbishment }

    without_zeros(lines.transform_values { |amount| compound(amount, @simulation.inflation_rate, year.number) })
  end

  private

  def exit_cash_flows(year)
    return [] if year.number.zero?

    flows = cash_flows.take(year.number + 1)
    flows[0] = -initial_outlay
    flows[-1] += year.sale_proceeds

    flows
  end

  def build_years
    outlay = initial_outlay
    interest = @simulation.loan.annual_interest
    insurance = @simulation.loan.annual_insurance
    principal = @simulation.loan.annual_principal
    remaining = @simulation.loan.annual_remaining_capital
    cumulative_cash_flow = 0
    cumulative_depreciation = 0
    deferred_depreciation = {}
    sale_costs = @simulation.sale_costs.total

    [origin_year] + (1..HORIZON_YEARS).map do |number|
      rent = compound(@simulation.annual_rent_excluding_charges_under(regime), @simulation.rent_growth_rate,
                      number - 1)
      monthly_rent = compound(@simulation.monthly_rent_under(regime), @simulation.rent_growth_rate, number - 1)
      provision = compound(@simulation.annual_provision_for_charges, @simulation.inflation_rate, number - 1)
      charges = compound(@simulation.annual_charges_excluding_provision, @simulation.inflation_rate, number - 1)
      loan_interest = interest.fetch(number, 0)
      property_value = compound(@simulation.market_value, @simulation.property_growth_rate, number)
      taxation = taxation_for(rent, provision, charges, loan_interest, monthly_rent, number, deferred_depreciation)
      deferred_depreciation = taxation.carried_forward_depreciation
      # Revendre ne reprend que le bâti déduit : ni travaux ni report.
      cumulative_depreciation += taxation.deducted_depreciation_lines.fetch(:building, 0)
      gain = @simulation.capital_gain_taxation(property_value, number, depreciation: cumulative_depreciation)

      year = Year.new(
        number: number,
        date: @simulation.purchase_date + number.years,
        rent_excluding_charges: rent,
        charges_excluding_provision: charges + taxation.own_charges,
        provision_for_charges: provision,
        loan_interest: loan_interest,
        loan_insurance: insurance.fetch(number, 0),
        capital_repayment: principal.fetch(number, 0),
        taxation: taxation,
        gain: gain,
        property_value: property_value,
        remaining_loan_capital: remaining.fetch(number, 0),
        sale_costs: compound(sale_costs, @simulation.inflation_rate, number),
        early_repayment_fee: @simulation.loan.early_repayment_fee(remaining.fetch(number, 0))
      )
      cumulative_cash_flow += year.cash_flow
      year.immobilized_capital = outlay - cumulative_cash_flow

      year
    end
  end

  def taxation_for(rent, provision, charges, loan_interest, monthly_rent, number, deferred_depreciation = {})
    elapsed = [number - 1, 0].max
    inflation = @simulation.inflation_rate

    @simulation.taxation(regime, rent_excluding_charges: rent, provision_for_charges: provision,
                                 charges: charges, loan_interest: loan_interest, monthly_rent: monthly_rent,
                                 accounting_fees: compound(@simulation.accounting_fees, inflation, elapsed),
                                 furniture_maintenance: compound(@simulation.furniture_maintenance, inflation, elapsed),
                                 year: number, deferred_depreciation: deferred_depreciation)
  end

  def origin_year
    Year.new(
      number: 0,
      date: @simulation.purchase_date,
      rent_excluding_charges: 0,
      charges_excluding_provision: 0,
      provision_for_charges: 0,
      loan_interest: 0,
      loan_insurance: 0,
      capital_repayment: 0,
      taxation: taxation_for(0, 0, 0, 0, 0, 0),
      gain: @simulation.capital_gain_taxation(@simulation.market_value, 0),
      immobilized_capital: initial_outlay,
      property_value: @simulation.market_value,
      remaining_loan_capital: @simulation.loan.capital,
      sale_costs: @simulation.sale_costs.total,
      early_repayment_fee: @simulation.loan.early_repayment_fee(@simulation.loan.capital)
    )
  end

  def indexed(amount, rate, year) = compound(amount, rate, year.number - 1)

  def without_zeros(lines) = lines.reject { |_, amount| amount.zero? }

  def compound(amount, annual_rate, years) = (amount.to_d * (1 + annual_rate.to_d / 100)**years).round(2)
end
