module Taxation
  # Ce qu'un loyer meublé a de commun : une recette commerciale, la provision comptée dans les
  # recettes, 18,6 % de sociaux, et la CFE. Le forfait est dans MicroBic, le réel dans Lmnp.
  class Bic < Regime
    # Faute de connaître la valeur locative, la CFE part d'un loyer mensuel.
    BUSINESS_TAX_RATE = BigDecimal("30")

    # Un meublé se loue plus cher qu'un nu, meubles et rotation compris.
    RENT_PREMIUM_RATE = BigDecimal("5")

    def self.rent_premium_rate = RENT_PREMIUM_RATE

    def self.provision_in_receipts? = true

    def self.furnished? = true

    def receipts = rent_excluding_charges + provision_for_charges

    def social_charges_rate = FURNISHED_SOCIAL_CHARGES_RATE

    def business_tax = share(monthly_rent, BUSINESS_TAX_RATE)

    def own_charge_lines = { business_tax: business_tax, furniture_maintenance: furniture_maintenance }
  end
end
