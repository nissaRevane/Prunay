module Taxation
  # Ce que les régimes ont en commun : la même année leur est donnée, et barème et sociaux
  # frappent ensuite de la même façon. Seules trois méthodes les distinguent.
  class Regime
    attr_reader :rent_excluding_charges, :provision_for_charges, :marginal_tax_rate, :charges, :loan_interest,
                :monthly_rent

    def initialize(rent_excluding_charges:, marginal_tax_rate:, provision_for_charges: 0, charges: 0,
                   loan_interest: 0, monthly_rent: 0, accounting_fees: 0, furniture_maintenance: 0,
                   depreciation: {}, deferred_depreciation: {}, capitalized: {})
      @rent_excluding_charges = rent_excluding_charges.to_d
      @provision_for_charges = provision_for_charges.to_d
      @marginal_tax_rate = marginal_tax_rate.to_d
      @charges = charges.to_d
      @loan_interest = loan_interest.to_d
      @monthly_rent = monthly_rent.to_d
      @accounting_fees = accounting_fees.to_d
      @furniture_maintenance = furniture_maintenance.to_d
      @depreciation_lines = depreciation.transform_values(&:to_d)
      @deferred_depreciation = deferred_depreciation.transform_values(&:to_d)
      @capitalized_lines = capitalized.transform_values(&:to_d)
    end

    def self.provision_in_receipts? = false

    def self.rent_premium_rate = 0

    def self.furnished? = false

    # Ce que le régime déclare avant tout abattement.
    def taxable_income = raise NotImplementedError

    def receipts = rent_excluding_charges

    def allowance = 0

    def allowance_rate = 0

    def social_charges_rate = SOCIAL_CHARGES_RATE

    def income_tax = share(taxable_income, marginal_tax_rate)

    def social_charges = share(taxable_income, social_charges_rate)

    def depreciation_lines = {}

    def deferred_depreciation = {}

    def capitalized_lines = {}

    def capitalized = 0

    def depreciation = 0

    def deducted_depreciation_lines = {}

    def carried_forward_depreciation = {}

    # Les charges que le régime paie seul : CFE du meublé, comptable du LMNP.
    def own_charge_lines = {}

    def own_charges = own_charge_lines.values.sum

    def business_tax = 0

    def total = income_tax + social_charges

    private

    attr_reader :accounting_fees, :furniture_maintenance

    def share(amount, rate) = (amount * rate / 100).round(2)
  end
end
