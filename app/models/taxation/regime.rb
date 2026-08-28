module Taxation
  # Ce que les régimes ont en commun : la même année de location leur est donnée, et la tranche
  # marginale du foyer comme les prélèvements sociaux frappent ensuite l'assiette de la même
  # façon. Seuls #taxable_income et, pour le meublé, #social_charges_rate les distinguent.
  class Regime
    attr_reader :rent_excluding_charges, :provision_for_charges, :marginal_tax_rate, :charges, :loan_interest

    def initialize(rent_excluding_charges:, marginal_tax_rate:, provision_for_charges: 0, charges: 0,
                   loan_interest: 0)
      # Décimaux d'office, comme dans Loan : un taux entier ferait une division entière.
      @rent_excluding_charges = rent_excluding_charges.to_d
      @provision_for_charges = provision_for_charges.to_d
      @marginal_tax_rate = marginal_tax_rate.to_d
      @charges = charges.to_d
      @loan_interest = loan_interest.to_d
    end

    # Le revenu imposable : ce que le régime retient de l'année.
    def taxable_income
      raise NotImplementedError
    end

    # Le taux du nu, que le meublé remplace par le sien : voir Taxation.
    def social_charges_rate
      SOCIAL_CHARGES_RATE
    end

    def income_tax
      share(taxable_income, marginal_tax_rate)
    end

    def social_charges
      share(taxable_income, social_charges_rate)
    end

    # Ce que l'année coûte en tout : la projection le retranche de son cash-flow.
    def total
      income_tax + social_charges
    end

    private

    def share(amount, rate)
      (amount * rate / 100).round(2)
    end
  end
end
