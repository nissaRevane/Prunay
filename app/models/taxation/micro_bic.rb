module Taxation
  # Le micro-BIC : le régime forfaitaire du meublé. Un loyer meublé n'est pas un revenu foncier
  # mais une recette commerciale — d'où une assiette qui compte la provision pour charges, un
  # abattement de moitié en place de toute charge, 18,6 % de prélèvements sociaux, et la CFE
  # que tout loueur en meublé paie comme une charge de l'année.
  class MicroBic < Regime
    # Le forfait du micro-BIC : 50 % des recettes pour une location meublée de longue durée.
    ALLOWANCE_RATE = BigDecimal("50")

    # La CFE se calcule sur la valeur locative que la commune retient : faute de la connaître,
    # Prunay prend un loyer mensuel pour référence et lui applique ce taux.
    BUSINESS_TAX_RATE = BigDecimal("30")

    # La provision pour charges entre dans les recettes, là où le foncier l'écarte de l'assiette.
    def self.provision_in_receipts? = true

    def receipts = rent_excluding_charges + provision_for_charges

    def allowance = share(receipts, ALLOWANCE_RATE)

    def taxable_income = receipts - allowance

    def social_charges_rate = FURNISHED_SOCIAL_CHARGES_RATE

    # La CFE est due sur le local loué, non sur le résultat : le forfait ne l'allège pas.
    def business_tax = share(monthly_rent, BUSINESS_TAX_RATE)
  end
end
