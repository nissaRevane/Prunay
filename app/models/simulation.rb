class Simulation < ApplicationRecord
  # Un investissement locatif projeté sur trente ans.
  #
  # Le modèle décrit le bien (type, ville, surface), son achat (prix, frais de notaire et
  # travaux initiaux), son financement (comptant ou à crédit), son exploitation (loyer, mois
  # loués, meublé ou nu) et ses charges annuelles. Reste la fiscalité : elle viendra, et
  # ajoutera sa colonne à la projection sans en changer la forme.
  HORIZON_YEARS = 30

  MONTHS_PER_YEAR = 12

  # Les pages de la création, dans l'ordre. Chaque nom est aussi un contexte de validation :
  # `valid?(:purchase)` ne juge que ce que la page achat a demandé, ce qui permet de valider
  # une étape sans exiger les réponses des suivantes.
  STEPS = %w[property purchase credit rental charges].freeze

  # Les étapes qu'une condition gouverne, comme CHARGE_CONDITIONS gouverne les charges : la
  # page du crédit ne s'ouvre qu'à qui en a coché un sur la page de l'achat. Le parcours, la
  # barre de progression et l'enchaînement des pages lisent tous #steps, jamais STEPS — un
  # achat comptant n'a que quatre pages.
  STEP_CONDITIONS = { "credit" => :credit? }.freeze

  PROPERTY_TYPES = %w[apartment house parking building].freeze
  RENTAL_TYPES = %w[furnished unfurnished].freeze
  ENERGY_RATINGS = %w[A B C D E F G].freeze

  # Le meublé, nommé : trois charges ne se demandent qu'à lui.
  FURNISHED = "furnished"

  # Les charges annuelles, groupées comme le formulaire les demande : ce que la détention du
  # bien coûte, ce que sa location coûte, ce que le meublé impose, et le reste. Les groupes
  # portent l'ordre d'affichage autant que le sens, et `ANNUAL_CHARGES` s'en déduit — une
  # charge de plus s'ajoute donc dans un groupe, et nulle part ailleurs.
  CHARGE_GROUPS = {
    ownership: %i[property_tax insurance maintenance condominium_fees],
    letting: %i[management_fees rent_guarantee],
    furnished: %i[business_tax accounting_fees],
    other: %i[other_charges]
  }.freeze

  ANNUAL_CHARGES = CHARGE_GROUPS.values.flatten.freeze

  # Les charges qu'une condition gouverne. Une maison n'a pas de charges de copropriété, et
  # un bien loué nu ne paie ni CFE ni comptable : le formulaire ne pose pas ces questions, et
  # le modèle remet le montant à zéro si la réponse qui le justifiait vient à changer.
  CHARGE_CONDITIONS = {
    condominium_fees: :condominium?,
    business_tax: :furnished?,
    accounting_fees: :furnished?
  }.freeze

  # Les montants proposés au premier affichage, énoncés pour une surface de référence de
  # 50 m². Ce sont des ordres de grandeur, pas des vérités : le formulaire les affiche
  # pré-remplis pour que l'utilisateur les corrige, pas pour qu'il les subisse.
  REFERENCE_SURFACE = 50

  REFERENCE_AMOUNTS = {
    monthly_rent: 650,
    property_tax: 700,
    insurance: 150,
    condominium_fees: 1_000,
    business_tax: 200,
    other_charges: 100
  }.freeze

  # L'entretien se lit à deux références, selon qui porte la façade, la toiture et les
  # communs : en copropriété les charges de copro les portent déjà, et seul le propriétaire
  # les porte toutes — d'où le double.
  MAINTENANCE_REFERENCES = { condominium: 1_000, sole_owner: 2_000 }.freeze

  # Les montants qui ne se déduisent pas de la surface. Un bilan de meublé se paie au
  # forfait, et une gestion déléguée comme une garantie des loyers impayés ne se supposent
  # pas : on les propose à zéro, à celui qui les paie de le dire.
  FIXED_AMOUNTS = { management_fees: 0, rent_guarantee: 0, accounting_fees: 500 }.freeze

  # Onze mois sur douze : un mois de vacance locative par an, la vacance moyenne d'un bien
  # correctement loué.
  DEFAULT_OCCUPANCY_MONTHS = 11

  # Trois mois entre la simulation et la signature — le temps d'un compromis.
  DEFAULT_PURCHASE_DELAY_MONTHS = 3

  # Les frais de notaire, approchés par une droite : 7,42 % du prix, majorés de 1 772 €.
  # Droits de mutation, émoluments et débours confondus, ils suivent le prix d'assez près
  # pour qu'une formule en tienne lieu — et l'utilisateur ne les saisit donc pas.
  NOTARY_FEES_RATE = BigDecimal("0.0742")

  NOTARY_FEES_BASE = 1_772

  # L'apport proposé : un dixième du coût du projet — l'ordre de grandeur qu'une banque
  # attend pour couvrir les frais de notaire sans les financer.
  DEFAULT_DOWN_PAYMENT_SHARE = BigDecimal("0.10")

  # Le crédit proposé tant que rien n'a été saisi : vingt ans à 3,5 %.
  DEFAULT_LOAN_RATE = BigDecimal("3.5")

  DEFAULT_LOAN_DURATION_YEARS = 20

  # Le jour du mois où la banque prélève : le 5. Le remboursement ne commence donc pas à
  # l'anniversaire de la signature mais au premier 5 qui la suit — le mois de l'acte quand il
  # est signé du 1er au 5, le mois d'après sinon.
  LOAN_PAYMENT_DAY = 5

  # Un crédit plus long que la projection ne se lirait qu'à moitié : le tableau s'arrêterait
  # avant sa dernière échéance, et la dernière ligne de la projection porterait encore une
  # annuité. La durée s'arrête donc là où l'horizon s'arrête.
  MAX_LOAN_DURATION_YEARS = HORIZON_YEARS

  # L'arrondi des montants proposés : la dizaine d'euros. Une estimation au centime se
  # lirait comme un calcul, alors que ce n'en est pas un.
  ESTIMATE_ROUNDING = 10

  # Une année de la projection, telle que le tableau la lit.
  #
  # +loan_payments+ est ce que le crédit prélève cette année-là : douze mensualités tant
  # qu'il court, ce qu'il en reste l'année où il se solde, et zéro ensuite — un crédit de
  # vingt ans ne pèse pas sur les dix dernières lignes d'une projection qui en compte trente.
  #
  # +immobilized_capital+ est cumulatif : c'est ce qui reste engagé après avoir déduit de
  # l'investissement initial tous les cash-flows encaissés depuis l'achat, et non le seul
  # cash-flow de l'année. Il décroît donc d'année en année, et passe sous zéro l'année où
  # l'investissement est récupéré — un capital immobilisé recalculé à chaque ligne sur le
  # seul cash-flow annuel rendrait trente fois le même montant.
  Year = Struct.new(:number, :date, :annual_rent, :annual_charges, :loan_payments, :cash_flow,
                    :immobilized_capital, keyword_init: true) do
    def recovered?
      immobilized_capital <= 0
    end
  end

  belongs_to :user

  # Le nom est le seul champ qu'aucune page n'exige. Il se propose dès la première, pour qui
  # sait déjà comment il appelle ce bien, et sinon le bien le lui dicte à l'enregistrement :
  # `on: [:create, :update]` et non un callback nu, pour que la validation d'une étape —
  # `valid?(:property)` — laisse le champ vide tel que l'utilisateur l'a laissé.
  before_validation :name_after_the_property, on: [:create, :update]

  # Ce qu'une condition ne justifie plus retombe à zéro : un bien qui sort de copropriété
  # cesse d'en payer les charges, un meublé repassé au nu cesse de payer la CFE. Sans quoi un
  # montant que le formulaire ne montre plus continuerait de peser sur la projection.
  before_validation :clear_inapplicable_charges

  # Ce qu'un achat comptant n'a pas à répondre retombe à zéro, comme pour les charges : une
  # simulation qui renonce à son crédit ne doit pas garder un taux et une durée que le
  # formulaire ne montre plus, et que le tableau d'amortissement continuerait de lire.
  before_validation :clear_loan_without_credit

  # La page du bien.
  validates :property_type, presence: true, inclusion: { in: PROPERTY_TYPES, allow_blank: true },
            on: [:create, :update, :property]
  validates :city, presence: true, on: [:create, :update, :property]
  validates :surface, presence: true, numericality: { greater_than: 0 }, on: [:create, :update, :property]
  validates :energy_rating, inclusion: { in: ENERGY_RATINGS, allow_blank: true }, on: [:create, :update, :property]

  # La page de l'achat — le financement compris : c'est la case du crédit qui ouvre la page
  # suivante.
  validates :purchase_date, presence: true, on: [:create, :update, :purchase]
  validates :purchase_price, presence: true, numericality: { greater_than: 0 }, on: [:create, :update, :purchase]
  validates :initial_works, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :purchase]
  validates :down_payment, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :purchase]
  # Un apport qui couvrirait tout le projet ne laisserait rien à emprunter : ce n'est plus un
  # achat à crédit. La comparaison attend le prix, sans quoi il n'y a pas encore de coût du
  # projet à comparer.
  validates :down_payment, numericality: { less_than: :total_investment },
            on: [:create, :update, :purchase],
            if: -> { credit? && purchase_price.present? && initial_works.present? }

  # La page du crédit, pour qui en prend un. Le contexte ne juge que lui : sans crédit, la
  # page n'existe pas et ses deux champs sont déjà retombés à zéro.
  validates :loan_rate, presence: true, numericality: { greater_than_or_equal_to: 0, less_than: 100 },
            on: [:create, :update, :credit], if: :credit?
  validates :loan_duration_years, presence: true,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_LOAN_DURATION_YEARS },
            on: [:create, :update, :credit], if: :credit?

  # La page de la location.
  validates :monthly_rent, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :rental]
  validates :occupancy_months, presence: true,
            numericality: { greater_than: 0, less_than_or_equal_to: MONTHS_PER_YEAR },
            on: [:create, :update, :rental]
  validates :rental_type, presence: true, inclusion: { in: RENTAL_TYPES, allow_blank: true },
            on: [:create, :update, :rental]

  # La page des charges annuelles. Toutes sont exigées, y compris celles qu'une condition
  # masque : `clear_inapplicable_charges` les a déjà ramenées à zéro.
  validates(*ANNUAL_CHARGES, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :charges])

  # Un montant de référence mis à l'échelle d'une surface, arrondi à la dizaine d'euros.
  # La racine carrée, et non la proportion : un logement deux fois plus grand ne se loue ni
  # ne s'entretient au double du prix.
  def self.estimate(field, surface, condominium: false)
    return FIXED_AMOUNTS.fetch(field) if FIXED_AMOUNTS.key?(field)

    surface = surface.to_f
    return 0 unless surface.positive?

    scaled = reference_amount(field, condominium: condominium) * Math.sqrt(surface / REFERENCE_SURFACE)
    (scaled / ESTIMATE_ROUNDING).round * ESTIMATE_ROUNDING
  end

  def self.reference_amount(field, condominium: false)
    return MAINTENANCE_REFERENCES.fetch(condominium ? :condominium : :sole_owner) if field == :maintenance

    REFERENCE_AMOUNTS.fetch(field)
  end
  private_class_method :reference_amount

  # Ce qu'une page propose tant que rien n'y a été saisi. Les trois dernières tirent leurs
  # montants des réponses déjà données — la surface d'abord, mais aussi la copropriété et le
  # meublé : ce sont les seuls chiffres dont on dispose avant que l'utilisateur ne parle
  # d'argent. D'où une méthode d'instance : le brouillon porte ces réponses.
  def defaults_for(step)
    case step.to_s
    when "purchase"
      {
        "purchase_date" => Date.current >> DEFAULT_PURCHASE_DELAY_MONTHS,
        "initial_works" => 0,
        "down_payment" => default_down_payment
      }
    when "credit"
      {
        "loan_rate" => DEFAULT_LOAN_RATE,
        "loan_duration_years" => DEFAULT_LOAN_DURATION_YEARS
      }
    when "rental"
      {
        "monthly_rent" => estimate(:monthly_rent),
        "occupancy_months" => DEFAULT_OCCUPANCY_MONTHS,
        "rental_type" => RENTAL_TYPES.first
      }
    when "charges"
      applicable_charges.to_h { |field| [field.to_s, estimate(field)] }
    else
      {}
    end
  end

  # Les pages que CETTE simulation traverse : toutes, moins celles dont la condition n'est
  # pas remplie. C'est cette liste que le parcours suit et que la barre de progression
  # affiche — un achat comptant saute la page du crédit.
  def steps
    STEPS.select { |step| step_applicable?(step) }
  end

  def step_applicable?(step)
    condition = STEP_CONDITIONS[step.to_s]

    condition.nil? || public_send(condition)
  end

  # L'apport proposé sur la page de l'achat : un dixième du coût du projet, arrondi à la
  # dizaine d'euros comme les autres montants proposés. Zéro tant qu'aucun prix n'a été tapé
  # — la page s'ouvre avant lui, et un dixième de rien ne veut rien dire.
  def default_down_payment
    return 0 if purchase_price.blank? || initial_works.blank?

    scaled = total_investment * DEFAULT_DOWN_PAYMENT_SHARE
    (scaled / ESTIMATE_ROUNDING).round * ESTIMATE_ROUNDING
  end

  # Un montant proposé pour ce bien-ci : sa surface, et sa copropriété là où elle change la
  # référence.
  def estimate(field)
    self.class.estimate(field, surface, condominium: condominium?)
  end

  def furnished?
    rental_type == FURNISHED
  end

  # Les charges que ce bien-ci se voit demander : toutes, moins celles dont la condition
  # n'est pas remplie. C'est cette liste que le formulaire affiche, que la fiche détaille et
  # que le total additionne.
  def applicable_charges
    ANNUAL_CHARGES.select { |field| charge_applicable?(field) }
  end

  def charge_applicable?(field)
    condition = CHARGE_CONDITIONS[field.to_sym]

    condition.nil? || public_send(condition)
  end

  # Le nom que le bien se donne lui-même : son type, sa ville et sa surface. C'est celui
  # que porte une simulation dont l'utilisateur n'a rien nommé — trois chiffres et deux mots
  # suffisent à la reconnaître dans une liste.
  def default_name
    I18n.t(
      "simulations.default_name",
      type: I18n.t("simulations.property_types.#{property_type}"),
      city: city,
      surface: ActiveSupport::NumberHelper.number_to_rounded(surface, precision: 2, strip_insignificant_zeros: true)
    )
  end

  # Les frais de notaire dus à la signature. Ils ne découlent que du prix, d'où l'absence
  # de colonne en base : les recalculer coûte moins que de les stocker et de risquer qu'ils
  # démentent un jour le prix affiché à côté d'eux.
  def notary_fees
    return 0 if purchase_price.blank?

    (purchase_price * NOTARY_FEES_RATE + NOTARY_FEES_BASE).round(2)
  end

  # Ce que le projet coûte : le prix, les frais de notaire qu'il entraîne, et les travaux
  # qu'il faut engager avant de pouvoir louer. C'est le montant à financer — comptant ou à
  # crédit —, et non ce que l'acheteur immobilise (voir #initial_outlay).
  def total_investment
    purchase_price + notary_fees + initial_works
  end

  # Ce que la banque prête : le coût du projet moins l'apport. Comme les frais de notaire,
  # il se recalcule au lieu de se stocker — il ne découle que de trois montants déjà saisis.
  def borrowed_capital
    return 0 unless credit?

    [total_investment - down_payment, 0].max
  end

  def loan_duration_months
    loan_duration_years.to_i * MONTHS_PER_YEAR
  end

  # La date de l'échéance numéro +number+, comptée depuis la première et non depuis la
  # précédente : toutes tombent le même jour du mois, un mois après l'autre.
  def loan_payment_due_on(number)
    loan_first_payment_on >> (number - 1)
  end

  # La première échéance : le 5 qui suit la signature. Le déblocage des fonds a lieu chez le
  # notaire et le prélèvement suit, mais il suit au jour du prélèvement — le 5 du mois de
  # l'acte quand il est signé du 1er au 5, le 5 du mois d'après quand il est signé plus tard.
  def loan_first_payment_on
    month = purchase_date.day <= LOAN_PAYMENT_DAY ? purchase_date : purchase_date >> 1

    Date.new(month.year, month.month, LOAN_PAYMENT_DAY)
  end

  # Le crédit a-t-il de quoi produire un tableau ? Il faut qu'il existe, qu'il porte une
  # durée, et qu'il reste quelque chose à emprunter une fois l'apport déduit.
  def amortizable?
    credit? && purchase_date.present? && loan_duration_months.positive? && borrowed_capital.positive?
  end

  def amortization_schedule
    return nil unless amortizable?

    @amortization_schedule ||= AmortizationSchedule.new(self)
  end

  def monthly_payment
    amortization_schedule&.monthly_payment || 0
  end

  # L'annuité : douze mensualités. C'est ce que le crédit prélève sur une année pleine — la
  # dernière année, celle où il se solde, en porte moins (voir Year#loan_payments).
  def annual_loan_payment
    monthly_payment * MONTHS_PER_YEAR
  end

  # Ce que le crédit coûte en tout : les intérêts de toutes ses échéances.
  def total_loan_interest
    amortization_schedule&.total_interest || 0
  end

  # Les loyers d'une année. Le loyer est saisi au mois — c'est ainsi qu'un bail l'énonce —
  # et multiplié par les mois effectivement loués, non par douze : un bien vide un mois par
  # an ne rapporte pas douze loyers.
  def annual_rent
    monthly_rent * occupancy_months
  end

  # Les charges d'une année : celles que le bien se voit demander, additionnées. Les autres
  # sont à zéro de toute façon, mais les exclure dit mieux ce que le total recouvre.
  def annual_charges
    applicable_charges.sum { |field| public_send(field) }
  end

  # Le cash-flow d'une année pleine : les loyers, moins les charges, moins l'annuité du
  # crédit. C'est le cash-flow récurrent, celui que la liste des simulations met en avant —
  # la projection, elle, lit l'annuité année par année et voit le crédit s'éteindre.
  def annual_cash_flow
    annual_rent - annual_charges - annual_loan_payment
  end

  # Ce que l'acheteur sort réellement de sa poche le premier jour : tout le projet quand il
  # le paie comptant, son seul apport quand un crédit finance le reste. Le capital emprunté
  # n'est pas immobilisé — il se rembourse ensuite par les annuités, que la projection
  # retranche du cash-flow. Le compter deux fois ferait payer le bien deux fois.
  def initial_outlay
    credit? ? down_payment : total_investment
  end

  # La projection, une ligne par anniversaire de l'achat. La première ligne est le premier
  # anniversaire, pas le jour de l'achat : elle porte les loyers des douze mois écoulés.
  def projection
    cumulative_cash_flow = 0
    loan_payments = amortization_schedule&.annual_payments || {}

    (1..HORIZON_YEARS).map do |number|
      due = loan_payments.fetch(number, 0)
      cash_flow = annual_rent - annual_charges - due
      cumulative_cash_flow += cash_flow

      Year.new(
        number: number,
        date: purchase_date >> (number * MONTHS_PER_YEAR),
        annual_rent: annual_rent,
        annual_charges: annual_charges,
        loan_payments: due,
        cash_flow: cash_flow,
        immobilized_capital: initial_outlay - cumulative_cash_flow
      )
    end
  end

  # Le chiffre que la liste met en avant : ce qui reste immobilisé au bout de l'horizon.
  # Négatif, l'investissement est récupéré et a rapporté au-delà.
  def final_immobilized_capital
    initial_outlay - total_cash_flow
  end

  def total_rent
    annual_rent * HORIZON_YEARS
  end

  def total_charges
    annual_charges * HORIZON_YEARS
  end

  # Le cumul se lit sur la projection, et ne se multiplie plus : un crédit qui s'éteint
  # avant l'horizon rend les années inégales entre elles.
  def total_cash_flow
    projection.sum(&:cash_flow)
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
  end
end
