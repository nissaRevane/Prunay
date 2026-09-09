module Taxation
  # Le plan d'amortissement du LMNP : le bâti — prix et frais de notaire, moins le terrain qui
  # ne s'use pas —, les travaux et les meubles, chacun amorti en ligne droite sur sa durée à
  # partir de la première année louée. Le plan inscrit ; ce que l'année déduit vraiment, et
  # ce qu'elle reporte, se lit dans Taxation::Lmnp.
  class DepreciationPlan
    # Le terrain, jamais amortissable : entre 10 et 20 % du prix, Prunay prend le milieu.
    LAND_SHARE = BigDecimal("0.15")

    # Les durées, au milieu des fourchettes d'usage ; l'ordre est celui de l'imputation (voir Lmnp).
    COMPONENTS = { building: 32, works: 12, furniture: 7 }.freeze

    attr_reader :price, :acquisition_fees, :works, :furniture

    def initialize(price:, acquisition_fees:, works:, furniture:)
      # Décimaux d'office, comme partout ailleurs : un montant entier ferait une division entière.
      @price = price.to_d
      @acquisition_fees = acquisition_fees.to_d
      @works = works.to_d
      @furniture = furniture.to_d
    end

    # Les frais d'acquisition suivent le bien qu'ils ont payé, part du terrain comprise.
    def bases = { building: (price + acquisition_fees) * (1 - LAND_SHARE), works: works, furniture: furniture }

    def annuity(component) = (bases.fetch(component) / COMPONENTS.fetch(component)).round(2)

    # Rien le jour de l'achat, rien au-delà de la durée, et la dernière annuité solde la base.
    def lines(year)
      COMPONENTS.filter_map do |component, years|
        next unless year.between?(1, years)

        amount = year == years ? last_annuity(component) : annuity(component)
        [component, amount] unless amount.zero?
      end.to_h
    end

    def total(year) = lines(year).values.sum

    private

    def last_annuity(component) = bases.fetch(component) - annuity(component) * (COMPONENTS.fetch(component) - 1)
  end
end
