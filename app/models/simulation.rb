class Simulation < ApplicationRecord
  # Un investissement locatif projeté sur trente ans.
  #
  # Le modèle décrit le bien (type, ville, surface), son achat (prix et travaux initiaux),
  # son exploitation (loyer, mois loués, meublé ou nu) et ses charges annuelles. Ni prêt ni
  # fiscalité : ils viendront, et chacun ajoutera une colonne à la projection sans en
  # changer la forme.
  HORIZON_YEARS = 30

  MONTHS_PER_YEAR = 12

  # Les quatre pages de la création, dans l'ordre. Chaque nom est aussi un contexte de
  # validation : `valid?(:purchase)` ne juge que ce que la page achat a demandé, ce qui
  # permet de valider une étape sans exiger les réponses des suivantes.
  STEPS = %w[property purchase rental charges].freeze

  PROPERTY_TYPES = %w[apartment house parking building].freeze
  RENTAL_TYPES = %w[furnished unfurnished].freeze
  ENERGY_RATINGS = %w[A B C D E F G].freeze

  # Les montants proposés au premier affichage, énoncés pour une surface de référence de
  # 50 m². Ce sont des ordres de grandeur, pas des vérités : le formulaire les affiche
  # pré-remplis pour que l'utilisateur les corrige, pas pour qu'il les subisse.
  REFERENCE_SURFACE = 50

  REFERENCE_AMOUNTS = {
    monthly_rent: 650,
    property_tax: 700,
    maintenance: 1_000,
    insurance: 150,
    other_charges: 100
  }.freeze

  # Onze mois sur douze : un mois de vacance locative par an, la vacance moyenne d'un bien
  # correctement loué.
  DEFAULT_OCCUPANCY_MONTHS = 11

  # Trois mois entre la simulation et la signature — le temps d'un compromis.
  DEFAULT_PURCHASE_DELAY_MONTHS = 3

  # L'arrondi des montants proposés : la dizaine d'euros. Une estimation au centime se
  # lirait comme un calcul, alors que ce n'en est pas un.
  ESTIMATE_ROUNDING = 10

  # Une année de la projection, telle que le tableau la lit.
  #
  # +immobilized_capital+ est cumulatif : c'est ce qui reste engagé après avoir déduit de
  # l'investissement initial tous les cash-flows encaissés depuis l'achat, et non le seul
  # cash-flow de l'année. Il décroît donc d'année en année, et passe sous zéro l'année où
  # l'investissement est récupéré — un capital immobilisé recalculé à chaque ligne sur le
  # seul cash-flow annuel rendrait trente fois le même montant.
  Year = Struct.new(:number, :date, :annual_rent, :annual_charges, :cash_flow, :immobilized_capital, keyword_init: true) do
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

  # Page 1 — le bien.
  validates :property_type, presence: true, inclusion: { in: PROPERTY_TYPES, allow_blank: true },
            on: [:create, :update, :property]
  validates :city, presence: true, on: [:create, :update, :property]
  validates :surface, presence: true, numericality: { greater_than: 0 }, on: [:create, :update, :property]
  validates :energy_rating, inclusion: { in: ENERGY_RATINGS, allow_blank: true }, on: [:create, :update, :property]

  # Page 2 — l'achat.
  validates :purchase_date, presence: true, on: [:create, :update, :purchase]
  validates :purchase_price, presence: true, numericality: { greater_than: 0 }, on: [:create, :update, :purchase]
  validates :initial_works, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :purchase]

  # Page 3 — la location.
  validates :monthly_rent, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :rental]
  validates :occupancy_months, presence: true,
            numericality: { greater_than: 0, less_than_or_equal_to: MONTHS_PER_YEAR },
            on: [:create, :update, :rental]
  validates :rental_type, presence: true, inclusion: { in: RENTAL_TYPES, allow_blank: true },
            on: [:create, :update, :rental]

  # Page 4 — les charges annuelles.
  ANNUAL_CHARGES = %i[property_tax maintenance insurance other_charges].freeze

  validates(*ANNUAL_CHARGES, presence: true, numericality: { greater_than_or_equal_to: 0 },
            on: [:create, :update, :charges])

  # Un montant de référence mis à l'échelle d'une surface, arrondi à la dizaine d'euros.
  # La racine carrée, et non la proportion : un logement deux fois plus grand ne se loue ni
  # ne s'entretient au double du prix.
  def self.estimate(field, surface)
    surface = surface.to_f
    return 0 unless surface.positive?

    scaled = REFERENCE_AMOUNTS.fetch(field) * Math.sqrt(surface / REFERENCE_SURFACE)
    (scaled / ESTIMATE_ROUNDING).round * ESTIMATE_ROUNDING
  end

  # Ce qu'une page propose tant que rien n'y a été saisi. Les trois dernières tirent leurs
  # montants de la surface annoncée par la première : c'est le seul chiffre dont on dispose
  # avant que l'utilisateur ne parle d'argent.
  def self.defaults_for(step, surface: nil)
    case step.to_s
    when "purchase"
      {
        "purchase_date" => Date.current >> DEFAULT_PURCHASE_DELAY_MONTHS,
        "initial_works" => 0
      }
    when "rental"
      {
        "monthly_rent" => estimate(:monthly_rent, surface),
        "occupancy_months" => DEFAULT_OCCUPANCY_MONTHS,
        "rental_type" => RENTAL_TYPES.first
      }
    when "charges"
      ANNUAL_CHARGES.to_h { |field| [field.to_s, estimate(field, surface)] }
    else
      {}
    end
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

  # Ce que l'achat immobilise le premier jour : le prix, et les travaux qu'il faut engager
  # avant de pouvoir louer. C'est de ce montant que les cash-flows se déduiront.
  def total_investment
    purchase_price + initial_works
  end

  # Les loyers d'une année. Le loyer est saisi au mois — c'est ainsi qu'un bail l'énonce —
  # et multiplié par les mois effectivement loués, non par douze : un bien vide un mois par
  # an ne rapporte pas douze loyers.
  def annual_rent
    monthly_rent * occupancy_months
  end

  # Les charges d'une année : taxe foncière, entretien, assurance PNO et frais divers.
  def annual_charges
    ANNUAL_CHARGES.sum { |field| public_send(field) }
  end

  # Le cash-flow d'une année : les entrées moins les sorties. Tant qu'il n'y a pas de prêt,
  # les sorties sont les seules charges — la mensualité aura ici sa place.
  def annual_cash_flow
    annual_rent - annual_charges
  end

  # La projection, une ligne par anniversaire de l'achat. La première ligne est le premier
  # anniversaire, pas le jour de l'achat : elle porte les loyers des douze mois écoulés.
  def projection
    cumulative_cash_flow = 0

    (1..HORIZON_YEARS).map do |number|
      cumulative_cash_flow += annual_cash_flow

      Year.new(
        number: number,
        date: purchase_date >> (number * MONTHS_PER_YEAR),
        annual_rent: annual_rent,
        annual_charges: annual_charges,
        cash_flow: annual_cash_flow,
        immobilized_capital: total_investment - cumulative_cash_flow
      )
    end
  end

  # Le chiffre que la liste met en avant : ce qui reste immobilisé au bout de l'horizon.
  # Négatif, l'investissement est récupéré et a rapporté au-delà.
  def final_immobilized_capital
    total_investment - total_cash_flow
  end

  def total_rent
    annual_rent * HORIZON_YEARS
  end

  def total_charges
    annual_charges * HORIZON_YEARS
  end

  def total_cash_flow
    annual_cash_flow * HORIZON_YEARS
  end

  private

  def name_after_the_property
    self.name = default_name if name.blank?
  end
end
