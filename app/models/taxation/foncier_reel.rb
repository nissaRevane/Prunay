module Taxation
  # Le foncier réel : pas d'abattement, mais charges réelles et intérêts déduits du loyer hors
  # charges. Le déficit ne se reporte pas : une année sans gain ne doit rien.
  class FoncierReel < Regime
    def taxable_income = [rent_excluding_charges - charges - loan_interest, 0].max
  end
end
