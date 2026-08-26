module Taxation
  # Le foncier réel : aucun abattement, mais les charges réelles et les intérêts d'emprunt —
  # prime d'assurance comprise — déduits du loyer hors charges, la provision pour charges
  # restant dehors. Le déficit foncier ne se reporte pas : une année sans gain ne doit rien.
  class FoncierReel < Regime
    def taxable_income
      [rent_excluding_charges - charges - loan_interest, 0].max
    end
  end
end
