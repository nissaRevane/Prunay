module Taxation
  # Ce que les régimes ont en commun : la même année de location leur est donnée, et la tranche
  # marginale du foyer comme les prélèvements sociaux frappent ensuite l'assiette de la même
  # façon. Seuls #taxable_income, #business_tax et #social_charges_rate les distinguent.
  # #total est l'impôt sur le revenu seul ; la CFE est une charge et se compte à part.
  class Regime
    attr_reader :rent_excluding_charges, :provision_for_charges, :marginal_tax_rate, :charges, :loan_interest,
                :monthly_rent

    def initialize(rent_excluding_charges:, marginal_tax_rate:, provision_for_charges: 0, charges: 0,
                   loan_interest: 0, monthly_rent: 0)
      # Décimaux d'office, comme dans Loan : un taux entier ferait une division entière.
      @rent_excluding_charges = rent_excluding_charges.to_d
      @provision_for_charges = provision_for_charges.to_d
      @marginal_tax_rate = marginal_tax_rate.to_d
      @charges = charges.to_d
      @loan_interest = loan_interest.to_d
      @monthly_rent = monthly_rent.to_d
    end

    # La provision refacturée n'est une recette que du meublé : voir Taxation::MicroBic.
    def self.provision_in_receipts? = false

    def taxable_income = raise NotImplementedError

    # Le taux du nu, que le meublé remplace par le sien : voir Taxation.
    def social_charges_rate = SOCIAL_CHARGES_RATE

    def income_tax = share(taxable_income, marginal_tax_rate)

    def social_charges = share(taxable_income, social_charges_rate)

    # La CFE ne frappe que le meublé, et n'est pas un impôt sur le revenu : voir Taxation::MicroBic.
    def business_tax = 0

    def total = income_tax + social_charges

    private

    def share(amount, rate) = (amount * rate / 100).round(2)
  end
end
