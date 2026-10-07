class Simulation < ApplicationRecord
  MONTHS_PER_YEAR = 12

  PROPERTY_TYPES = %w[apartment house parking building].freeze
  ENERGY_RATINGS = %w[A B C D E F G].freeze

  CHARGE_GROUPS = {
    ownership: %i[property_tax insurance maintenance condominium_fees],
    letting: %i[management_fees rent_guarantee],
    furnished: %i[accounting_fees furniture_maintenance],
    other: %i[other_charges]
  }.freeze

  # Droits, émoluments et débours suivent le prix : une droite en tient lieu.
  NOTARY_FEES_RATE = BigDecimal("0.0742")

  NOTARY_FEES_BASE = 1_772

  REGIME_CHARGES = %i[accounting_fees furniture_maintenance].freeze

  ANNUAL_CHARGES = (CHARGE_GROUPS.values.flatten - REGIME_CHARGES).freeze

  NAME_CITY_LENGTH = 5

  MAX_PER_USER = 50

  MAX_LOAN_DURATION_YEARS = Projection::HORIZON_YEARS

  LOT_LETTING_FIELDS = %w[monthly_rent monthly_charges occupancy_months].freeze

  LOT_FIELDS = ["surface", *LOT_LETTING_FIELDS].freeze

  MAX_LOTS = 20

  belongs_to :user

  before_validation :clear_loan_without_credit
  before_validation :align_rental_start_date

  before_save :settle_lots

  after_save { @loan = nil }

  scope :search, ->(query) {
    query.to_s.split.reduce(all) do |found, term|
      found.where("unaccent(city || ' ' || coalesce(address, '')) ILIKE unaccent(?)", "%#{sanitize_sql_like(term)}%")
    end
  }
  scope :of_type, ->(type) { PROPERTY_TYPES.include?(type) ? where(property_type: type) : all }

  validates :property_type, presence: true, inclusion: { in: PROPERTY_TYPES, allow_blank: true },
            on: [:create, :update, :property]
  validates :city, presence: true, on: [:create, :update, :property]
  validates :surface, presence: true, numericality: { greater_than: 0 }, on: [:create, :update, :property]
  validates :energy_rating, inclusion: { in: ENERGY_RATINGS, allow_blank: true }, on: [:create, :update, :property]
  validates :lots, length: { maximum: MAX_LOTS }, on: [:create, :update, :property], if: :building?
  validate :lot_surfaces_given, on: [:create, :update, :property], if: :building?

  validates :purchase_date, presence: true, on: [:create, :update, :purchase]
  validates :purchase_price, presence: true, numericality: { greater_than: 0 }, on: [:create, :update, :purchase]
  validates :initial_works, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :purchase]
  validates :furniture, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :purchase]
  validates :down_payment, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :purchase]
  validates :down_payment, numericality: { less_than: :total_investment },
            on: [:create, :update, :purchase],
            if: -> { credit? && purchase_price.present? && initial_works.present? }

  validates :loan_rate, presence: true, numericality: { greater_than_or_equal_to: 0, less_than: 100 },
            on: [:create, :update, :credit], if: :credit?
  validates :loan_duration_years, presence: true,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_LOAN_DURATION_YEARS },
            on: [:create, :update, :credit], if: :credit?
  validates :loan_insurance, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :credit], if: :credit?
  validates :loan_guarantee_fees, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :credit], if: :credit?
  validates :loan_application_fees, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :credit], if: :credit?

  validates :monthly_rent, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :rental]
  validate :lot_lettings_given, on: [:create, :update, :rental], if: :building?
  validates :monthly_charges, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :rental]
  validates :occupancy_months, presence: true,
            numericality: { greater_than: 0, less_than_or_equal_to: MONTHS_PER_YEAR },
            on: [:create, :update, :rental]
  validates :rental_start_date, presence: true, on: [:create, :update, :rental]
  validates :rental_start_date, comparison: { greater_than_or_equal_to: :purchase_date },
            on: [:create, :update, :rental], if: -> { purchase_date.present? && rental_start_date.present? }

  validates(*ANNUAL_CHARGES, *REGIME_CHARGES, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :charges])

  # Une décote n'est pas un rabais : c'est ce que le bien vaut en plus du prix.
  validates :purchase_discount, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update]

  validates(*Assumptions::RATES, presence: true,
            numericality: { greater_than_or_equal_to: Assumptions::MIN_RATE,
                            less_than_or_equal_to: Assumptions::MAX_RATE },
            on: [:create, :update])

  validates :marginal_tax_rate, presence: true, inclusion: { in: Taxation::MARGINAL_TAX_RATES },
            on: [:create, :update]

  validate :within_quota, on: :create

  def building? = property_type == "building"

  def divided_into_lots? = building? && lots.any?

  def lots=(rows)
    rows = rows.to_h.sort_by { |index, _| index.to_i }.map(&:last) if rows.respond_to?(:each_pair)

    super(Array(rows).map { |row| row.to_h.stringify_keys.slice(*LOT_FIELDS) }
                     .reject { |row| row.values.all?(&:blank?) })
  end

  def surface = divided_into_lots? ? lot_total("surface") : super

  def monthly_rent = divided_into_lots? ? lot_total("monthly_rent") : super

  def monthly_charges = divided_into_lots? ? lot_total("monthly_charges") : super

  # Pondérés par le loyer : le loyer total × ces mois approche le loyer de l'année.
  def occupancy_months = divided_into_lots? ? lots_occupancy_months : super

  def steps = Step.all_for(self)

  def defaults_for(step) = Step.defaults(step, self)

  def assumptions
    @assumptions ||= Assumptions.for(user)
  end

  def estimate(field, surface = self.surface) = Estimate.new(assumptions).for(field, surface, property_type)

  def rent_reference = RentReference.for(city)

  def market_rent = rent_reference&.monthly_rent(property_type, surface)

  # Le baromètre énonce un loyer charges comprises : la provision en sort avant la proposition.
  def proposed_rent
    return lots.sum { |lot| estimate(:monthly_rent, lot["surface"]) } if divided_into_lots?

    market = market_rent

    market.nil? ? estimate(:monthly_rent) : [market - estimate(:monthly_charges), 0].max
  end

  def name
    I18n.t(
      "simulations.name",
      type: I18n.t("simulations.property_type_icons.#{property_type}"),
      city: short_city,
      surface: surface&.round
    )
  end

  def notary_fees
    return 0 if purchase_price.blank?

    (purchase_price * NOTARY_FEES_RATE + NOTARY_FEES_BASE).round(2)
  end

  def market_value = purchase_price + purchase_discount

  def total_investment = purchase_price + notary_fees + initial_works

  # Les meubles ne s'achètent que sous un régime du meublé, et jamais à crédit.
  def furniture_under(regime) = Taxation.furnished?(regime) ? furniture : 0

  def total_investment_under(regime) = total_investment + furniture_under(regime)

  def borrowed_capital
    return 0 unless credit?

    [total_investment - down_payment, 0].max
  end

  def loan
    @loan ||= Loan.new(capital: borrowed_capital, annual_rate: loan_rate, duration_years: loan_duration_years,
                       insurance: loan_insurance, guarantee_fees: loan_guarantee_fees,
                       application_fees: loan_application_fees, early_repayment_fee: early_repayment_fee?,
                       signed_on: purchase_date)
  end

  def projection(regime) = Projection.new(self, regime)

  def regimes = Taxation::NAMES.select { |regime| Taxation.available?(regime, annual_receipts_under(regime)) }

  def projections = regimes.index_with { |regime| projection(regime) }

  def best_return
    @best_return ||= BestReturn.new(self)
  end

  def dashboard(projections = self.projections, exit_year = Projection::REVIEW_YEAR)
    Dashboard.new(self, projections, exit_year)
  end

  def annual_rent = annual_rent_excluding_charges + annual_provision_for_charges

  def annual_rent_excluding_charges = lettings.sum { |rent, _, months| rent * months }

  # Une année de projection ne loue que les mois postérieurs à la mise en location.
  def occupancy_months_in(year, months = occupancy_months) = year.nil? ? months : (months * rented_share(year)).round(2)

  def monthly_rent_under(regime) = monthly_rents_under(regime).sum

  def monthly_rents_under(regime) = lettings.map { |rent, _, _| rent_under(rent, regime) }

  def annual_rent_excluding_charges_under(regime, year = nil)
    lettings.sum { |rent, _, months| (rent_under(rent, regime) * occupancy_months_in(year, months)).round(2) }
  end

  def annual_rent_under(regime) = annual_rent_excluding_charges_under(regime) + annual_provision_for_charges

  def annual_receipts_under(regime)
    return annual_rent_under(regime) if Taxation.regime(regime).provision_in_receipts?

    annual_rent_excluding_charges_under(regime)
  end

  def annual_provision_for_charges(year = nil)
    lettings.sum { |_, charges, months| (charges * occupancy_months_in(year, months)).round(2) }
  end

  def annual_charges = ANNUAL_CHARGES.sum { |field| public_send(field) }

  def annual_charges_excluding_provision(year = nil) = annual_charges - annual_provision_for_charges(year)

  def annual_business_tax = taxation(:micro_bic).business_tax

  def depreciation_plan
    @depreciation_plan ||= Taxation::DepreciationPlan.new(price: purchase_price, acquisition_fees: notary_fees, works: initial_works,
                                   furniture: furniture, maintenance: maintenance,
                                   furniture_maintenance: furniture_maintenance, inflation_rate: inflation_rate)
  end

  def taxation(regime = Taxation::DEFAULT_REGIME,
               rent_excluding_charges: annual_rent_excluding_charges_under(regime),
               provision_for_charges: annual_provision_for_charges,
               charges: annual_charges_excluding_provision, loan_interest: loan.annual_interest.fetch(1, 0),
               monthly_rent: monthly_rent_under(regime), accounting_fees: self.accounting_fees,
               furniture_maintenance: self.furniture_maintenance, year: 1,
               depreciation: depreciation_plan.lines(year), deferred_depreciation: {},
               capitalized: depreciation_plan.capitalized(year))
    Taxation.for(regime, rent_excluding_charges: rent_excluding_charges,
                         provision_for_charges: provision_for_charges, charges: charges,
                         loan_interest: loan_interest, marginal_tax_rate: marginal_tax_rate,
                         monthly_rent: monthly_rent, accounting_fees: accounting_fees,
                         furniture_maintenance: furniture_maintenance, depreciation: depreciation,
                         deferred_depreciation: deferred_depreciation, capitalized: capitalized)
  end

  def annual_taxes(regime = Taxation::DEFAULT_REGIME) = taxation(regime).total

  def sale_costs = SaleCosts.new(surface: surface, diagnostics: assumptions.sale_diagnostics,
                                 refurbishment: assumptions.sale_refurbishment)

  def capital_gain_taxation(sale_price, held_years, depreciation: 0)
    Taxation::CapitalGain.new(sale_price: sale_price, purchase_price: purchase_price,
                              acquisition_fees: notary_fees, held_years: held_years,
                              depreciation: depreciation)
  end

  def annual_cash_flow = annual_rent - annual_charges - annual_taxes - loan.annual_payment

  def initial_outlay(regime = Taxation::DEFAULT_REGIME)
    (credit? ? down_payment + loan.upfront_fees : total_investment) + furniture_under(regime)
  end

  private

  def lot_total(field) = lots.sum { |lot| lot[field].to_d }

  def lots_occupancy_months
    rent = lot_total("monthly_rent")
    return (lot_total("occupancy_months") / lots.size).round(1) unless rent.positive?

    (lots.sum { |lot| lot["monthly_rent"].to_d * lot["occupancy_months"].to_d } / rent).round(1)
  end

  def lettings
    return [[monthly_rent, monthly_charges, occupancy_months]] unless divided_into_lots?

    lots.map { |lot| lot.values_at(*LOT_LETTING_FIELDS).map(&:to_d) }
  end

  def rent_under(rent, regime) = (rent * (1 + Taxation.rent_premium_rate(regime).to_d / 100)).round(2)

  def decimal(value) = BigDecimal(value.to_s, exception: false)

  def lot_surfaces_given
    errors.add(:lots, :surface_missing) unless lots.all? { |lot| decimal(lot["surface"])&.positive? }
  end

  def lot_lettings_given
    valid = lots.all? do |lot|
      rent, charges, months = lot.values_at(*LOT_LETTING_FIELDS).map { |value| decimal(value) }
      [rent, charges].all? { |amount| amount && !amount.negative? } && months&.positive? && months <= MONTHS_PER_YEAR
    end

    errors.add(:lots, :letting_missing) unless valid
  end

  def settle_lots
    return self.lots = [] unless building?
    return if lots.empty?

    self[:surface] = surface
    self[:monthly_rent] = monthly_rent
    self[:monthly_charges] = monthly_charges
    self[:occupancy_months] = occupancy_months
  end

  def rented_share(year)
    opening = purchase_date + (year - 1).years
    closing = purchase_date + year.years
    return 1 if rental_start_date.nil? || rental_start_date <= opening
    return 0 if rental_start_date >= closing

    months_until(closing) / MONTHS_PER_YEAR
  end

  # Les mois pleins qui restent, plus la fraction du mois entamé.
  def months_until(closing)
    months = (closing.year - rental_start_date.year) * MONTHS_PER_YEAR + closing.month - rental_start_date.month

    months + (closing.day - rental_start_date.day).to_d / rental_start_date.end_of_month.day
  end

  # Déplacer l'achat déplace d'autant une mise en location qui n'est pas saisie.
  def align_rental_start_date
    return if purchase_date.blank?
    return self.rental_start_date = purchase_date >> 1 if rental_start_date.blank?
    return unless purchase_date_changed? && !rental_start_date_changed? && purchase_date_was.present?

    self.rental_start_date += (purchase_date - purchase_date_was).to_i
  end

  def within_quota
    errors.add(:base, :quota_exceeded, count: MAX_PER_USER) if user && user.simulations.count >= MAX_PER_USER
  end

  def short_city = city.to_s.strip.first(NAME_CITY_LENGTH)

  def clear_loan_without_credit
    return if credit?

    self.down_payment = 0
    self.loan_rate = 0
    self.loan_duration_years = 0
    self.loan_insurance = 0
    self.loan_guarantee_fees = 0
    self.loan_application_fees = 0
  end
end
