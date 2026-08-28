module Taxation
  # Le micro-BIC : le régime forfaitaire du meublé. Un loyer meublé n'est pas un revenu foncier
  # mais une recette commerciale — d'où une assiette qui compte la provision pour charges, un
  # abattement de moitié en place de toute charge, et 18,6 % de prélèvements sociaux.
  class MicroBic < Regime
    # Le forfait du micro-BIC : 50 % des recettes pour une location meublée de longue durée.
    ALLOWANCE_RATE = BigDecimal("50")

    # Les recettes de l'année : tout ce que le locataire verse. La provision pour charges en
    # fait partie, là où le foncier l'écarte de l'assiette — c'est la différence des deux mondes.
    def receipts
      rent_excluding_charges + provision_for_charges
    end

    def allowance
      share(receipts, ALLOWANCE_RATE)
    end

    def taxable_income
      receipts - allowance
    end

    def social_charges_rate
      FURNISHED_SOCIAL_CHARGES_RATE
    end
  end
end
