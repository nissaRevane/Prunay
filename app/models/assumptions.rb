class Assumptions < ApplicationRecord
  RATES = %i[rent_growth_rate property_growth_rate inflation_rate].freeze

  ECONOMIC = [*RATES, :marginal_tax_rate].freeze

  # Les montants proposés valent pour Estimate::REFERENCE_SURFACE.
  SCALED_AMOUNTS = %i[monthly_rent property_tax insurance maintenance condominium_fees other_charges
                      furniture furniture_maintenance].freeze

  FIXED_AMOUNTS = %i[monthly_charges management_fees rent_guarantee accounting_fees].freeze

  PROPOSED_AMOUNTS = (SCALED_AMOUNTS + FIXED_AMOUNTS).freeze

  LOAN = %i[loan_rate loan_duration_years loan_insurance_rate loan_guarantee_rate
            loan_application_rate loan_application_fees_floor].freeze

  SALE = %i[sale_diagnostics sale_refurbishment].freeze

  PURCHASE = %i[purchase_delay_months down_payment_share].freeze

  EDITABLE = [*ECONOMIC, *PROPOSED_AMOUNTS, *PURCHASE, *LOAN, :occupancy_months, *SALE].freeze

  # Au-delà, ce n'est plus une hypothèse : un loyer doublerait en deux ans.
  MIN_RATE = -50

  MAX_RATE = 50

  POSITIVE_AMOUNTS = [*PROPOSED_AMOUNTS, :loan_application_fees_floor, *SALE].freeze

  SHARES = %i[down_payment_share loan_rate loan_insurance_rate loan_guarantee_rate
              loan_application_rate].freeze

  belongs_to :user

  validates(*RATES, presence: true,
            numericality: { greater_than_or_equal_to: MIN_RATE, less_than_or_equal_to: MAX_RATE })

  validates :marginal_tax_rate, presence: true, inclusion: { in: Taxation::MARGINAL_TAX_RATES }

  validates(*POSITIVE_AMOUNTS, presence: true, numericality: { greater_than_or_equal_to: 0 })

  validates(*SHARES, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 })

  validates :occupancy_months, presence: true,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: Simulation::MONTHS_PER_YEAR }

  validates :loan_duration_years, presence: true,
            numericality: { greater_than: 0, less_than_or_equal_to: Simulation::MAX_LOAN_DURATION_YEARS }

  validates :purchase_delay_months, presence: true, numericality: { greater_than_or_equal_to: 0 }

  def self.whole(value) = value.is_a?(BigDecimal) && value.frac.zero? ? value.to_i : value

  def self.for(user)
    return new if user.nil?

    user.assumptions || user.build_assumptions
  end

  # Mêmes noms de colonnes des deux côtés : une simulation s'en habille.
  def economic = ECONOMIC.index_with { |name| public_send(name) }.stringify_keys
end
