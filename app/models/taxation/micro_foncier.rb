module Taxation
  # Le micro-foncier : le loyer hors charges encaissé, diminué d'un abattement forfaitaire qui
  # tient lieu de toute charge déductible. Ni charges réelles ni intérêts.
  class MicroFoncier < Regime
    # 30 % de l'assiette, en place des charges réelles.
    ALLOWANCE_RATE = BigDecimal("30")

    # Au-delà de ces loyers bruts annuels, le réel s'impose (art. 32 CGI).
    RECEIPTS_CEILING = 15_000

    def self.available?(rent_excluding_charges) = rent_excluding_charges <= RECEIPTS_CEILING

    def allowance_rate = ALLOWANCE_RATE

    def allowance = share(rent_excluding_charges, allowance_rate)

    def taxable_income = rent_excluding_charges - allowance
  end
end
