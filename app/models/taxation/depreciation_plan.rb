module Taxation
  # Le plan d'amortissement du LMNP : le bâti hors terrain, les travaux et les meubles, puis
  # chaque année la part d'entretien qui achète du durable. Ce qui se déduit est dans Lmnp.
  class DepreciationPlan
    # Le terrain ne s'amortit pas : 10 à 20 % du prix, on prend le milieu.
    LAND_SHARE = BigDecimal("0.15")

    # Durées au milieu des fourchettes ; l'ordre est celui de l'imputation.
    COMPONENTS = { building: 32, works: 12, furniture: 7 }.freeze

    # La part d'entretien qui achète du durable ; le reste se déduit en charge.
    CAPITALIZED_SHARES = { works: BigDecimal("0.5"), furniture: BigDecimal("0.8") }.freeze

    attr_reader :price, :acquisition_fees, :works, :furniture, :maintenance, :furniture_maintenance, :inflation_rate

    def initialize(price:, acquisition_fees:, works:, furniture:, maintenance: 0, furniture_maintenance: 0,
                   inflation_rate: 0)
      @price = price.to_d
      @acquisition_fees = acquisition_fees.to_d
      @works = works.to_d
      @furniture = furniture.to_d
      @maintenance = maintenance.to_d
      @furniture_maintenance = furniture_maintenance.to_d
      @inflation_rate = inflation_rate.to_d
    end

    def bases
      @bases ||= { building: (price + acquisition_fees) * (1 - LAND_SHARE), works: works, furniture: furniture }
    end

    def annuity(component) = annuity_of(bases.fetch(component), COMPONENTS.fetch(component), 1)

    def capitalized(year)
      return {} unless year.positive?

      @capitalized ||= {}
      @capitalized[year] ||= without_zeros(CAPITALIZED_SHARES.to_h do |component, share|
        [component, (upkeep_of(component) * share * (1 + inflation_rate / 100)**(year - 1)).round(2)]
      end)
    end

    def capitalized_annuity(component) = annuity_of(capitalized(1).fetch(component, 0), COMPONENTS.fetch(component), 1)

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

    def tranches(component, years, year)
      (1..year).sum do |opened|
        age = year - opened + 1
        age <= years ? annuity_of(capitalized(opened).fetch(component, 0), years, age) : 0
      end
    end

    def annuity_of(base, years, age)
      annuity = (base / years).round(2)
      age == years ? base - annuity * (years - 1) : annuity
    end

    def upkeep_of(component) = component == :works ? maintenance : furniture_maintenance

    def without_zeros(lines) = lines.reject { |_, amount| amount.zero? }
  end
end
