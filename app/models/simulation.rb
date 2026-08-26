# Un investissement locatif projeté sur trente ans : le bien, son achat, son financement, son
# exploitation et ses charges annuelles. Le crédit est dans Loan, la projection dans
# Projection, les montants proposés dans Simulation::Estimate et les pages dans Simulation::Step.
class Simulation < ApplicationRecord
  MONTHS_PER_YEAR = 12

  PROPERTY_TYPES = %w[apartment house parking building].freeze
  RENTAL_TYPES = %w[furnished unfurnished].freeze
  ENERGY_RATINGS = %w[A B C D E F G].freeze

  # Le meublé, nommé : trois charges ne se demandent qu'à lui.
  FURNISHED = "furnished"

  # L'appartement, nommé : c'est le seul type de bien que l'on suppose en copropriété.
  APARTMENT = "apartment"

  # Les charges annuelles, groupées comme le formulaire les demande : l'ordre est le sien.
  CHARGE_GROUPS = {
    ownership: %i[property_tax insurance maintenance condominium_fees],
    letting: %i[management_fees rent_guarantee],
    furnished: %i[business_tax accounting_fees],
    other: %i[other_charges]
  }.freeze

  ANNUAL_CHARGES = CHARGE_GROUPS.values.flatten.freeze

  # Une maison n'a pas de charges de copropriété, et un bien loué nu ne paie ni CFE ni comptable.
  CHARGE_CONDITIONS = {
    condominium_fees: :condominium?,
    business_tax: :furnished?,
    accounting_fees: :furnished?
  }.freeze

  # Droits, émoluments et débours suivent le prix d'assez près pour qu'une droite en tienne lieu.
  NOTARY_FEES_RATE = BigDecimal("0.0742")

  NOTARY_FEES_BASE = 1_772

  # Un crédit plus long que la projection porterait une annuité au-delà de sa dernière ligne.
  MAX_LOAN_DURATION_YEARS = Projection::HORIZON_YEARS

  belongs_to :user

  # `on:` et non un callback nu : valider une étape ne doit pas remplir un champ laissé vide.
  before_validation :name_after_the_property, on: [:create, :update]

  # Un montant que le formulaire ne montre plus ne doit pas continuer de peser sur la projection.
  before_validation :clear_inapplicable_charges
  before_validation :clear_loan_without_credit

  # Un crédit abandonné ne doit pas survivre à la case qui le déclarait.
  after_save { @loan = nil }

  # La page du bien.
  validates :property_type, presence: true, inclusion: { in: PROPERTY_TYPES, allow_blank: true },
            on: [:create, :update, :property]
  validates :city, presence: true, on: [:create, :update, :property]
  validates :surface, presence: true, numericality: { greater_than: 0 }, on: [:create, :update, :property]
  validates :energy_rating, inclusion: { in: ENERGY_RATINGS, allow_blank: true }, on: [:create, :update, :property]

  # La page de l'achat, financement compris : c'est la case du crédit qui ouvre la suivante.
  validates :purchase_date, presence: true, on: [:create, :update, :purchase]
  validates :purchase_price, presence: true, numericality: { greater_than: 0 }, on: [:create, :update, :purchase]
  validates :initial_works, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :purchase]
  validates :down_payment, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :purchase]
  # Un apport qui couvrirait tout le projet ne laisserait rien à emprunter.
  validates :down_payment, numericality: { less_than: :total_investment },
            on: [:create, :update, :purchase],
            if: -> { credit? && purchase_price.present? && initial_works.present? }

  # La page du crédit. Sans crédit elle n'existe pas, et ses champs sont déjà retombés à zéro.
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

  # La page de la location.
  validates :monthly_rent, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :rental]
  validates :occupancy_months, presence: true,
            numericality: { greater_than: 0, less_than_or_equal_to: MONTHS_PER_YEAR },
            on: [:create, :update, :rental]
  validates :rental_type, presence: true, inclusion: { in: RENTAL_TYPES, allow_blank: true },
            on: [:create, :update, :rental]

  # Toutes sont exigées : `clear_inapplicable_charges` a déjà ramené à zéro celles qu'on masque.
  validates(*ANNUAL_CHARGES, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :charges])

  # Les conditions économiques, héritées de l'utilisateur à la création : aucune page du
  # parcours ne les demande, seul l'onglet de la simulation les corrige ensuite.
  validates(*EconomicConditions::RATES, presence: true,
            numericality: { greater_than_or_equal_to: EconomicConditions::MIN_RATE,
                            less_than_or_equal_to: EconomicConditions::MAX_RATE },
            on: [:create, :update])

  # Les pages que CETTE simulation traverse : le parcours et la barre de progression lisent #steps.
  def steps
    Step.all_for(self)
  end

  def defaults_for(step)
    Step.defaults(step, self)
  end

  # Un montant proposé pour ce bien-ci : sa surface, et sa copropriété là où elle change la donne.
  def estimate(field)
    Estimate.for(field, surface, condominium: condominium?)
  end

  def furnished?
    rental_type == FURNISHED
  end

  def apartment?
    property_type == APARTMENT
  end

  # Ce que le formulaire affiche, ce que la fiche détaille et ce que le total additionne.
  def applicable_charges
    ANNUAL_CHARGES.select { |field| charge_applicable?(field) }
  end

  def charge_applicable?(field)
    condition = CHARGE_CONDITIONS[field.to_sym]

    condition.nil? || public_send(condition)
  end

  # Le nom que le bien se donne lui-même : deux mots et trois chiffres pour le reconnaître.
  def default_name
    I18n.t(
      "simulations.default_name",
      type: I18n.t("simulations.property_types.#{property_type}"),
      city: city,
      surface: ActiveSupport::NumberHelper.number_to_rounded(surface, precision: 2, strip_insignificant_zeros: true)
    )
  end

  # Pas de colonne en base : les recalculer coûte moins que de risquer qu'ils démentent le prix.
  def notary_fees
    return 0 if purchase_price.blank?

    (purchase_price * NOTARY_FEES_RATE + NOTARY_FEES_BASE).round(2)
  end

  # Le montant à financer, comptant ou à crédit — non ce qu'on immobilise : voir #initial_outlay.
  def total_investment
    purchase_price + notary_fees + initial_works
  end

  # Ce que la banque prête : le coût du projet moins l'apport.
  def borrowed_capital
    return 0 unless credit?

    [total_investment - down_payment, 0].max
  end

  # Toujours présent : un achat comptant en porte un qui ne prête rien et n'a pas de tableau.
  def loan
    @loan ||= Loan.new(capital: borrowed_capital, annual_rate: loan_rate, duration_years: loan_duration_years,
                       insurance: loan_insurance, guarantee_fees: loan_guarantee_fees,
                       application_fees: loan_application_fees, signed_on: purchase_date)
  end

  def projection
    Projection.new(self)
  end

  # Par les mois effectivement loués : un bien vide un mois par an ne fait pas douze loyers.
  def annual_rent
    monthly_rent * occupancy_months
  end

  # Les autres sont à zéro de toute façon, mais les exclure dit mieux ce que le total recouvre.
  def annual_charges
    applicable_charges.sum { |field| public_send(field) }
  end

  # Une année pleine : la projection, elle, lit l'annuité par année et voit le crédit s'éteindre.
  def annual_cash_flow
    annual_rent - annual_charges - loan.annual_payment
  end

  # Tout le projet comptant ; à crédit, l'apport et les frais du prêt — eux se paient à la
  # signature, quand l'emprunt, lui, se rend par les annuités.
  def initial_outlay
    credit? ? down_payment + loan.upfront_fees : total_investment
  end

  private

  def name_after_the_property
    self.name = default_name if name.blank?
  end

  def clear_inapplicable_charges
    (ANNUAL_CHARGES - applicable_charges).each { |field| self[field] = 0 }
  end

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
