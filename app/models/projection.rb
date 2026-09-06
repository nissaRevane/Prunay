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

  # Le compte de résultat d'une année : la provision remboursée n'est ni un revenu ni une charge déductible.
  Year = Struct.new(:number, :date, :rent_excluding_charges, :charges_excluding_provision,
                    :provision_for_charges, :loan_interest, :capital_repayment, :taxes, :business_tax,
                    :immobilized_capital, :property_value, :capital_gain, :capital_gain_tax,
                    :remaining_loan_capital, keyword_init: true) do
    # Les intérêts sont une charge ; le capital rendu, non — il ne passe qu'au cash-flow.
    def pre_tax_result = rent_excluding_charges - charges_excluding_provision - loan_interest

    def net_result = pre_tax_result - taxes

    def cash_flow = net_result - capital_repayment

    def loan_payments = loan_interest + capital_repayment

    def recovered? = immobilized_capital <= 0

    def sale_proceeds = property_value - capital_gain_tax - remaining_loan_capital

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

  def total_rent = years.sum(&:rent_excluding_charges)

  def total_charges = years.sum(&:charges_excluding_provision)

  def total_taxes = years.sum(&:taxes)

  def total_cash_flow = years.sum(&:cash_flow)

  # Négatif, l'investissement est récupéré.
  def final_immobilized_capital = years.last.immobilized_capital

  def final_property_value = years.last.property_value

  private

  # Les montants saisis courent sur douze mois ; le prix du bien, lui, a déjà pris une année au premier anniversaire.
  def build_years
    outlay = @simulation.initial_outlay
    interest = @simulation.loan.annual_interest
    principal = @simulation.loan.annual_principal
    remaining = @simulation.loan.annual_remaining_capital
    cumulative_cash_flow = 0

    [origin_year] + (1..HORIZON_YEARS).map do |number|
      rent = compound(@simulation.annual_rent_excluding_charges, @simulation.rent_growth_rate, number - 1)
      monthly_rent = compound(@simulation.monthly_rent, @simulation.rent_growth_rate, number - 1)
      provision = compound(@simulation.annual_provision_for_charges, @simulation.inflation_rate, number - 1)
      charges = compound(@simulation.annual_charges_excluding_provision, @simulation.inflation_rate, number - 1)
      loan_interest = interest.fetch(number, 0)
      property_value = compound(@simulation.purchase_price, @simulation.property_growth_rate, number)
      gain = @simulation.capital_gain_taxation(property_value, number)
      taxation = taxation_for(rent, provision, charges, loan_interest, monthly_rent)

      year = Year.new(
        number: number,
        date: @simulation.purchase_date + number.years,
        rent_excluding_charges: rent,
        charges_excluding_provision: charges + taxation.business_tax,
        provision_for_charges: provision,
        loan_interest: loan_interest,
        capital_repayment: principal.fetch(number, 0),
        taxes: taxation.total,
        business_tax: taxation.business_tax,
        property_value: property_value,
        capital_gain: gain.amount,
        capital_gain_tax: gain.total,
        remaining_loan_capital: remaining.fetch(number, 0)
      )
      cumulative_cash_flow += year.cash_flow
      year.immobilized_capital = outlay - cumulative_cash_flow

      year
    end
  end

  # C'est le régime qui sait quels montants il retient — la provision, par exemple, en meublé seulement.
  # La CFE qu'il rend ne lui est pas repassée : seul un régime réel déduirait ses charges, et le
  # meublé n'a que son forfait, qui tient déjà lieu de toutes.
  def taxation_for(rent, provision, charges, loan_interest, monthly_rent)
    @simulation.taxation(regime, rent_excluding_charges: rent, provision_for_charges: provision,
                                 charges: charges, loan_interest: loan_interest, monthly_rent: monthly_rent)
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
      capital_repayment: 0,
      taxes: 0,
      business_tax: 0,
      immobilized_capital: @simulation.initial_outlay,
      property_value: @simulation.purchase_price,
      capital_gain: 0,
      capital_gain_tax: 0,
      remaining_loan_capital: @simulation.loan.capital
    )
  end

  # `to_d` : un taux qu'un formulaire invalide vient de vider se lit comme une absence d'évolution.
  def compound(amount, annual_rate, years) = (amount.to_d * (1 + annual_rate.to_d / 100)**years).round(2)
end
