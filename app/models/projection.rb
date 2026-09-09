# La projection d'un investissement locatif sur trente ans, une ligne par anniversaire de
# l'achat, précédée de l'année zéro : le jour de la signature, où rien n'a encore été encaissé
# et où le capital vient tout juste d'être immobilisé. Les anniversaires qui suivent portent
# chacun les loyers des douze mois écoulés, composés par les conditions économiques, et
# l'impôt que ces loyers-là valent au foyer, dans le régime qu'on lui donne (voir Taxation).
class Projection
  HORIZON_YEARS = 30

  # L'année où la liste des simulations les lit : un crédit de vingt ans y a rendu la moitié de son capital.
  REVIEW_YEAR = 15

  # Les deux lectures d'une année dans sa fiche : le nom sert d'onglet, de panneau, d'identifiant et de traduction.
  VIEWS = %w[result sale].freeze

  # Le compte de résultat d'une année : hors meublé, la provision remboursée n'est ni un revenu ni une charge.
  Year = Struct.new(:number, :date, :rent_excluding_charges, :charges_excluding_provision,
                    :provision_for_charges, :loan_interest, :loan_insurance, :capital_repayment,
                    :taxation, :gain, :immobilized_capital, :property_value,
                    :remaining_loan_capital, :sale_costs, :early_repayment_fee, keyword_init: true) do
    def taxes = taxation.total

    def capital_gain = gain.amount

    def capital_gain_tax = gain.total

    # L'annuité porte les deux ensemble ; la fiche, qui les détaille, les redemande séparés.
    def interest_excluding_insurance = loan_interest - loan_insurance

    # Les intérêts sont une charge ; le capital rendu, non — il ne passe qu'au cash-flow.
    def pre_tax_result = rent_excluding_charges - charges_excluding_provision - loan_interest

    def net_result = pre_tax_result - taxes

    def cash_flow = net_result - capital_repayment

    # Ce que le meublé déclare et déduit : la provision voyage alors des deux côtés du résultat.
    def rent_including_charges = rent_excluding_charges + provision_for_charges

    def charges_including_provision = charges_excluding_provision + provision_for_charges

    def loan_payments = loan_interest + capital_repayment

    def recovered? = immobilized_capital <= 0

    def sale_proceeds = property_value - sale_costs - capital_gain_tax - remaining_loan_capital -
                        early_repayment_fee

    # Les loyers déjà encaissés ont d'eux-mêmes entamé le capital qui reste engagé.
    def sale_profit = sale_proceeds - immobilized_capital
  end

  attr_reader :regime

  def initialize(simulation, regime)
    @simulation = simulation
    @regime = regime
  end

  def years
    @years ||= build_years
  end

  def year(number) = years.find { |year| year.number == number }

  # Le meublé déclare la provision et déduit tout ce qu'elle couvre ; le foncier la laisse dehors.
  def provision_in_receipts? = Taxation.regime(regime).provision_in_receipts?

  # Le libellé du loyer dit ce que l'année déclare, et sert de clé de traduction dans les deux sens.
  def rent_column = provision_in_receipts? ? "annual_rent_including_charges_column" : "annual_rent_column"

  def rent_of(year) = provision_in_receipts? ? year.rent_including_charges : year.rent_excluding_charges

  def charges_of(year)
    provision_in_receipts? ? year.charges_including_provision : year.charges_excluding_provision
  end

  def total_rent = years.sum(&:rent_excluding_charges)

  def total_charges = years.sum(&:charges_excluding_provision)

  def total_taxes = years.sum(&:taxes)

  # Négatif, l'investissement est récupéré.
  def final_immobilized_capital = years.last.immobilized_capital

  def purchase_price = @simulation.purchase_price

  def occupancy_months = @simulation.occupancy_months

  def initial_outlay = @simulation.initial_outlay(regime)

  # Ce que l'année a déjà rendu de l'investissement : le capital immobilisé s'en déduit.
  def cumulative_cash_flow(year) = years.take(year.number + 1).sum(&:cash_flow)

  # Le loyer de l'année tel qu'il se perçoit : au mois, la provision comptée à part.
  def monthly_rent_of(year) = indexed(@simulation.monthly_rent_under(regime), @simulation.rent_growth_rate, year)

  def monthly_provision_of(year) = indexed(@simulation.monthly_charges, @simulation.inflation_rate, year)

  # Chaque poste de charge tel que l'inflation l'a porté, et ce que le régime y ajoute de lui-même.
  def charge_lines(year)
    return {} if year.number.zero?

    lines = Simulation::ANNUAL_CHARGES.index_with do |field|
      indexed(@simulation.public_send(field), @simulation.inflation_rate, year)
    end

    without_zeros(lines.merge(year.taxation.own_charge_lines))
  end

  # Les frais de revente suivent l'inflation depuis la signature, l'année de vente comprise.
  def sale_cost_lines(year)
    costs = @simulation.sale_costs
    lines = { diagnostics: costs.diagnostics, refurbishment: costs.refurbishment }

    without_zeros(lines.transform_values { |amount| compound(amount, @simulation.inflation_rate, year.number) })
  end

  private

  # Les montants saisis courent sur douze mois ; le prix du bien, lui, a déjà pris une année au premier anniversaire.
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
      property_value = compound(@simulation.purchase_price, @simulation.property_growth_rate, number)
      taxation = taxation_for(rent, provision, charges, loan_interest, monthly_rent, number, deferred_depreciation)
      deferred_depreciation = taxation.carried_forward_depreciation
      # Revendre reprend le bâti déduit jusque-là, l'année en cours comprise — ni les travaux, ni
      # les meubles, ni ce qui attend encore en report.
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

  # C'est le régime qui sait quels montants il retient — la provision, par exemple, en meublé seulement.
  # Les charges qu'il ajoute lui-même ne lui sont pas repassées : il les connaît déjà, et les déduit
  # ou non selon qu'il est au réel ou au forfait.
  def taxation_for(rent, provision, charges, loan_interest, monthly_rent, number, deferred_depreciation = {})
    @simulation.taxation(regime, rent_excluding_charges: rent, provision_for_charges: provision,
                                 charges: charges, loan_interest: loan_interest, monthly_rent: monthly_rent,
                                 year: number, deferred_depreciation: deferred_depreciation)
  end

  # Le jour de l'achat : rien n'a couru, la ligne est là pour le capital immobilisé et le prix payé.
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
      gain: @simulation.capital_gain_taxation(@simulation.purchase_price, 0),
      immobilized_capital: initial_outlay,
      property_value: @simulation.purchase_price,
      remaining_loan_capital: @simulation.loan.capital,
      sale_costs: @simulation.sale_costs.total,
      early_repayment_fee: @simulation.loan.early_repayment_fee(@simulation.loan.capital)
    )
  end

  # Les montants saisis décrivent la première année : chaque anniversaire suivant les compose une fois de plus.
  def indexed(amount, rate, year) = compound(amount, rate, year.number - 1)

  def without_zeros(lines) = lines.reject { |_, amount| amount.zero? }

  # `to_d` : un taux qu'un formulaire invalide vient de vider se lit comme une absence d'évolution.
  def compound(amount, annual_rate, years) = (amount.to_d * (1 + annual_rate.to_d / 100)**years).round(2)
end
