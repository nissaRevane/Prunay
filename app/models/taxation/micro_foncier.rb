module Taxation
  # Le micro-foncier : l'assiette est le loyer hors charges encaissé, diminué d'un abattement
  # forfaitaire. Ni les charges réelles ni les intérêts d'emprunt n'y entrent — le forfait
  # tient lieu de toute charge déductible, et c'est ce que le régime a de simple.
  class MicroFoncier < Regime
    # Le forfait du micro-foncier : 30 % de l'assiette, en place des charges réelles.
    ALLOWANCE_RATE = BigDecimal("30")

    def allowance
      share(rent_excluding_charges, ALLOWANCE_RATE)
    end

    def taxable_income
      rent_excluding_charges - allowance
    end
  end
end
