module Taxation
  # Le plan d'amortissement du LMNP : le bâti — prix et frais de notaire, moins le terrain qui
  # ne s'use pas —, les travaux et les meubles du départ, puis chaque année la part de
  # l'entretien qui achète du durable — gros travaux, meubles renouvelés — ouvrant sa tranche.
  # Le plan inscrit ; ce que l'année déduit vraiment, et ce qu'elle reporte, se lit dans Lmnp.
  class DepreciationPlan
    # Le terrain, jamais amortissable : entre 10 et 20 % du prix, Prunay prend le milieu.
    LAND_SHARE = BigDecimal("0.15")

    # Les durées, au milieu des fourchettes d'usage ; l'ordre est celui de l'imputation (voir Lmnp).
    COMPONENTS = { building: 32, works: 12, furniture: 7 }.freeze

    # Ce que l'entretien immobilise : la moitié de celui du bien est de gros travaux, l'entretien
    # des meubles est pour l'essentiel leur renouvellement. Le reste se déduit en charge.
    CAPITALIZED_SHARES = { works: BigDecimal("0.5"), furniture: BigDecimal("0.8") }.freeze

    attr_reader :price, :acquisition_fees, :works, :furniture, :maintenance, :furniture_maintenance, :inflation_rate

    def initialize(price:, acquisition_fees:, works:, furniture:, maintenance: 0, furniture_maintenance: 0,
                   inflation_rate: 0)
      # Décimaux d'office, comme partout ailleurs : un montant entier ferait une division entière.
      @price = price.to_d
      @acquisition_fees = acquisition_fees.to_d
      @works = works.to_d
      @furniture = furniture.to_d
      @maintenance = maintenance.to_d
      @furniture_maintenance = furniture_maintenance.to_d
      @inflation_rate = inflation_rate.to_d
    end

    # Les frais d'acquisition suivent le bien qu'ils ont payé, part du terrain comprise.
    def bases
      @bases ||= { building: (price + acquisition_fees) * (1 - LAND_SHARE), works: works, furniture: furniture }
    end

    def annuity(component) = annuity_of(bases.fetch(component), COMPONENTS.fetch(component), 1)

    # La tranche que l'entretien de l'année ouvre, au prix de l'année.
    def capitalized(year)
      return {} unless year.positive?

      @capitalized ||= {}
      @capitalized[year] ||= without_zeros(CAPITALIZED_SHARES.to_h do |component, share|
        [component, (upkeep_of(component) * share * (1 + inflation_rate / 100)**(year - 1)).round(2)]
      end)
    end

    # L'annuité d'une tranche de première année : ce que la fiche annonce.
    def capitalized_annuity(component) = annuity_of(capitalized(1).fetch(component, 0), COMPONENTS.fetch(component), 1)

    # Rien le jour de l'achat ; le départ tant que sa durée court, et chaque tranche encore vivante.
    def lines(year)
      @lines ||= {}
      @lines[year] ||= without_zeros(COMPONENTS.to_h do |component, years|
        [component, initial_line(component, years, year) + tranches(component, years, year)]
      end)
    end

    def total(year) = lines(year).values.sum

    private

    def initial_line(component, years, year)
      year.between?(1, years) ? annuity_of(bases.fetch(component), years, year) : 0
    end

    # Les tranches ouvertes depuis moins de `years` ans, chacune à l'annuité de son âge.
    def tranches(component, years, year)
      (1..year).sum do |opened|
        age = year - opened + 1
        age <= years ? annuity_of(capitalized(opened).fetch(component, 0), years, age) : 0
      end
    end

    # En ligne droite, et la dernière annuité solde la base au centime.
    def annuity_of(base, years, age)
      annuity = (base / years).round(2)
      age == years ? base - annuity * (years - 1) : annuity
    end

    def upkeep_of(component) = component == :works ? maintenance : furniture_maintenance

    def without_zeros(lines) = lines.reject { |_, amount| amount.zero? }
  end
end
