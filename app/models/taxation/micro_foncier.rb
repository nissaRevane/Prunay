module Taxation
  # Le micro-foncier : le loyer hors charges encaissé, diminué d'un abattement forfaitaire qui
  # tient lieu de toute charge déductible. Ni charges réelles ni intérêts.
  class MicroFoncier < Regime
    # 30 % de l'assiette, en place des charges réelles.
    ALLOWANCE_RATE = BigDecimal("30")

    def allowance_rate = ALLOWANCE_RATE

    def allowance = share(rent_excluding_charges, allowance_rate)

    def taxable_income = rent_excluding_charges - allowance
  end
end
