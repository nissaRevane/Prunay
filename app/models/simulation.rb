# Un investissement locatif projeté sur trente ans : le bien, son achat, son financement, son
# exploitation et ses charges annuelles. Le crédit est dans Loan, la projection dans
# Projection, les montants proposés dans Simulation::Estimate et les pages dans Simulation::Step.
class Simulation < ApplicationRecord
  MONTHS_PER_YEAR = 12

  PROPERTY_TYPES = %w[apartment house parking building].freeze
  ENERGY_RATINGS = %w[A B C D E F G].freeze

  # Les charges annuelles, groupées comme le formulaire les demande : l'ordre est le sien.
  CHARGE_GROUPS = {
    ownership: %i[property_tax insurance maintenance condominium_fees],
    letting: %i[management_fees rent_guarantee],
    furnished: %i[accounting_fees furniture_maintenance],
    other: %i[other_charges]
  }.freeze

  # Les charges qu'un seul type de régime paie : il les porte lui-même (voir Taxation::Bic et
  # Taxation::Lmnp) et elles restent hors du total que tous les autres supportent.
  REGIME_CHARGES = %i[accounting_fees furniture_maintenance].freeze

  ANNUAL_CHARGES = (CHARGE_GROUPS.values.flatten - REGIME_CHARGES).freeze

  # Droits, émoluments et débours suivent le prix d'assez près pour qu'une droite en tienne lieu.
  NOTARY_FEES_RATE = BigDecimal("0.0742")

  NOTARY_FEES_BASE = 1_772

  # Cinq lettres de ville : de quoi reconnaître le lieu sans déborder d'une ligne de liste.
  NAME_CITY_LENGTH = 5

  # Un crédit plus long que la projection porterait une annuité au-delà de sa dernière ligne.
  MAX_LOAN_DURATION_YEARS = Projection::HORIZON_YEARS

  belongs_to :user

  # Un montant que le formulaire ne montre plus ne doit pas continuer de peser sur la projection.
  before_validation :clear_loan_without_credit

  # Un crédit abandonné ne doit pas survivre à la case qui le déclarait.
  after_save { @loan = nil }

  validates :property_type, presence: true, inclusion: { in: PROPERTY_TYPES, allow_blank: true },
            on: [:create, :update, :property]
  validates :city, presence: true, on: [:create, :update, :property]
  validates :surface, presence: true, numericality: { greater_than: 0 }, on: [:create, :update, :property]
  validates :energy_rating, inclusion: { in: ENERGY_RATINGS, allow_blank: true }, on: [:create, :update, :property]

  validates :purchase_date, presence: true, on: [:create, :update, :purchase]
  validates :purchase_price, presence: true, numericality: { greater_than: 0 }, on: [:create, :update, :purchase]
  validates :initial_works, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :purchase]
  validates :furniture, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :purchase]
  validates :down_payment, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :purchase]
  # Un apport qui couvrirait tout le projet ne laisserait rien à emprunter.
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
  # Les frais que la signature coûte : ils s'ajoutent à l'apport dans le capital immobilisé.
  validates :loan_guarantee_fees, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :credit], if: :credit?
  validates :loan_application_fees, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :credit], if: :credit?

  validates :monthly_rent, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :rental]
  validates :monthly_charges, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :rental]
  validates :occupancy_months, presence: true,
            numericality: { greater_than: 0, less_than_or_equal_to: MONTHS_PER_YEAR },
            on: [:create, :update, :rental]

  validates(*ANNUAL_CHARGES, *REGIME_CHARGES, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :charges])

  # Héritées de l'utilisateur à la création : aucune page du parcours ne les demande.
  validates(*EconomicConditions::RATES, presence: true,
            numericality: { greater_than_or_equal_to: EconomicConditions::MIN_RATE,
                            less_than_or_equal_to: EconomicConditions::MAX_RATE },
            on: [:create, :update])

  # La tranche marginale, elle, se choisit dans le barème et non sur une échelle.
  validates :marginal_tax_rate, presence: true, inclusion: { in: Taxation::MARGINAL_TAX_RATES },
            on: [:create, :update]

  # Les pages que CETTE simulation traverse : le parcours et la barre de progression lisent #steps.
  def steps = Step.all_for(self)

  def defaults_for(step) = Step.defaults(step, self)

  def estimate(field) = Estimate.for(field, surface)

  # Rien à saisir, rien à stocker : le bien se nomme par son type, sa ville et sa surface.
  def name
    I18n.t(
      "simulations.name",
      type: I18n.t("simulations.property_type_icons.#{property_type}"),
      city: short_city,
      surface: surface&.round
    )
  end

  # Pas de colonne en base : les recalculer coûte moins que de risquer qu'ils démentent le prix.
  def notary_fees
    return 0 if purchase_price.blank?

    (purchase_price * NOTARY_FEES_RATE + NOTARY_FEES_BASE).round(2)
  end

  # Le montant à financer, comptant ou à crédit — non ce qu'on immobilise : voir #initial_outlay.
  def total_investment = purchase_price + notary_fees + initial_works

  # Les meubles ne s'achètent que sous un régime du meublé, et jamais à crédit : voir #initial_outlay.
  def furniture_under(regime) = Taxation.furnished?(regime) ? furniture : 0

  def total_investment_under(regime) = total_investment + furniture_under(regime)

  def borrowed_capital
    return 0 unless credit?

    [total_investment - down_payment, 0].max
  end

  # Toujours présent : un achat comptant en porte un qui ne prête rien et n'a pas de tableau.
  def loan
    @loan ||= Loan.new(capital: borrowed_capital, annual_rate: loan_rate, duration_years: loan_duration_years,
                       insurance: loan_insurance, guarantee_fees: loan_guarantee_fees,
                       application_fees: loan_application_fees, early_repayment_fee: early_repayment_fee?,
                       signed_on: purchase_date)
  end

  def projection(regime) = Projection.new(self, regime)

  def projections = Taxation::NAMES.index_with { |regime| projection(regime) }

  def annual_rent = annual_rent_excluding_charges + annual_provision_for_charges

  # Le loyer seul, hors charges : la part imposable, et rien d'autre.
  def annual_rent_excluding_charges = monthly_rent * occupancy_months

  # Le loyer saisi est celui d'un nu : les régimes du meublé lui ajoutent leur prime (voir Taxation::Bic).
  def monthly_rent_under(regime) = (monthly_rent * (1 + Taxation.rent_premium_rate(regime).to_d / 100)).round(2)

  def annual_rent_excluding_charges_under(regime) = monthly_rent_under(regime) * occupancy_months

  def annual_rent_under(regime) = annual_rent_excluding_charges_under(regime) + annual_provision_for_charges

  # La provision que le locataire rembourse par-dessus le loyer, et que la copropriété reprend.
  def annual_provision_for_charges = monthly_charges * occupancy_months

  def annual_charges = ANNUAL_CHARGES.sum { |field| public_send(field) }

  # La provision remboursée est ôtée : les dépenses qu'elle couvre ne se déclarent pas plus qu'elle.
  def annual_charges_excluding_provision = annual_charges - annual_provision_for_charges

  # La CFE, que le meublé seul paie : elle ne se saisit pas et reste hors du total des charges.
  def annual_business_tax = taxation(:micro_bic).business_tax

  # Ce que le LMNP amortit : le bâti frais de notaire compris, les travaux et les meubles, et chaque
  # année la part de l'entretien qui achète du durable.
  def depreciation_plan
    Taxation::DepreciationPlan.new(price: purchase_price, acquisition_fees: notary_fees, works: initial_works,
                                   furniture: furniture, maintenance: maintenance,
                                   furniture_maintenance: furniture_maintenance, inflation_rate: inflation_rate)
  end

  # La provision voyage avec le loyer : le meublé l'impose là où le nu la laisse dehors.
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

  # Diagnostics et remise en état : ce que la revente coûte avant même la plus-value.
  def sale_costs = SaleCosts.new(surface: surface)

  # La plus-value se compte sur la valeur fiscale, frais de notaire compris, et s'efface avec la
  # détention ; les amortissements déjà déduits, eux, la creusent.
  def capital_gain_taxation(sale_price, held_years, depreciation: 0)
    Taxation::CapitalGain.new(sale_price: sale_price, purchase_price: purchase_price,
                              acquisition_fees: notary_fees, held_years: held_years,
                              depreciation: depreciation)
  end

  # Une année pleine : la projection, elle, lit l'annuité par année et voit le crédit s'éteindre.
  def annual_cash_flow = annual_rent - annual_charges - annual_taxes - loan.annual_payment

  # À crédit seuls l'apport et les frais se paient à la signature : l'emprunt, lui, se rend par les annuités.
  def initial_outlay(regime = Taxation::DEFAULT_REGIME)
    (credit? ? down_payment + loan.upfront_fees : total_investment) + furniture_under(regime)
  end

  private

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
