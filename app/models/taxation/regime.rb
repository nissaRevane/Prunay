module Taxation
  # Ce que les régimes ont en commun : la même année de location leur est donnée, et la tranche
  # marginale du foyer comme les prélèvements sociaux frappent ensuite l'assiette de la même
  # façon. Seuls #taxable_income, #own_charge_lines et #social_charges_rate les distinguent.
  # #total est l'impôt sur le revenu seul ; les charges du régime se comptent à part.
  class Regime
    attr_reader :rent_excluding_charges, :provision_for_charges, :marginal_tax_rate, :charges, :loan_interest,
                :monthly_rent, :purchase_price, :year

    def initialize(rent_excluding_charges:, marginal_tax_rate:, provision_for_charges: 0, charges: 0,
                   loan_interest: 0, monthly_rent: 0, purchase_price: 0, accounting_fees: 0, year: 0)
      # Décimaux d'office, comme dans Loan : un taux entier ferait une division entière.
      @rent_excluding_charges = rent_excluding_charges.to_d
      @provision_for_charges = provision_for_charges.to_d
      @marginal_tax_rate = marginal_tax_rate.to_d
      @charges = charges.to_d
      @loan_interest = loan_interest.to_d
      @monthly_rent = monthly_rent.to_d
      @purchase_price = purchase_price.to_d
      @accounting_fees = accounting_fees.to_d
      # Le rang de l'année, et non un montant : l'amortissement du LMNP s'y arrête.
      @year = year.to_i
    end

    # La provision refacturée n'est une recette que du meublé : voir Taxation::Bic.
    def self.provision_in_receipts? = false

    def taxable_income = raise NotImplementedError

    # Ce que le régime déclare avant tout abattement : le meublé y ajoute la provision.
    def receipts = rent_excluding_charges

    # Le réel n'en a pas : il déduit ses charges pour de vrai. Voir les deux micro-régimes.
    def allowance = 0

    def allowance_rate = 0

    # Le taux du nu, que le meublé remplace par le sien : voir Taxation.
    def social_charges_rate = SOCIAL_CHARGES_RATE

    def income_tax = share(taxable_income, marginal_tax_rate)

    def social_charges = share(taxable_income, social_charges_rate)

    # Le réel du meublé seul en a une : voir Taxation::Lmnp.
    def depreciation = 0

    # Les charges que le régime paie de lui-même, hors de celles qu'on lui donne : la CFE du
    # meublé, le comptable du LMNP. La projection les ajoute aux charges de l'année.
    def own_charge_lines = {}

    def own_charges = own_charge_lines.values.sum

    # La CFE ne frappe que le meublé, et n'est pas un impôt sur le revenu : voir Taxation::Bic.
    def business_tax = 0

    def total = income_tax + social_charges

    private

    # Le montant saisi, qu'un seul régime déduit : voir Taxation::Lmnp.
    attr_reader :accounting_fees

    def share(amount, rate) = (amount * rate / 100).round(2)
  end
end
