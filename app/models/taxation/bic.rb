module Taxation
  # Ce qu'un loyer meublé a de commun, quel que soit le régime sous lequel il se déclare : une
  # recette commerciale et non un revenu foncier, d'où la provision pour charges comptée dans
  # les recettes, 18,6 % de prélèvements sociaux, et la CFE que tout loueur en meublé paie
  # comme une charge de l'année. Le forfait est dans MicroBic, le réel dans Lmnp.
  class Bic < Regime
    # La CFE se calcule sur la valeur locative que la commune retient : faute de la connaître,
    # Prunay prend un loyer mensuel pour référence et lui applique ce taux.
    BUSINESS_TAX_RATE = BigDecimal("30")

    # Un meublé se loue plus cher qu'un nu, meubles et rotation compris.
    RENT_PREMIUM_RATE = BigDecimal("5")

    def self.rent_premium_rate = RENT_PREMIUM_RATE

    # La provision pour charges entre dans les recettes, là où le foncier l'écarte de l'assiette.
    def self.provision_in_receipts? = true

    def receipts = rent_excluding_charges + provision_for_charges

    def social_charges_rate = FURNISHED_SOCIAL_CHARGES_RATE

    # La CFE est due sur le local loué, non sur le résultat : ni le forfait ni le déficit ne l'allègent.
    def business_tax = share(monthly_rent, BUSINESS_TAX_RATE)

    def own_charge_lines = { business_tax: business_tax }
  end
end
