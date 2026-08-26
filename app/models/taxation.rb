# L'impôt d'une année de location, au micro-foncier — le seul régime que Prunay modélise
# pour l'instant. L'assiette est le loyer hors charges encaissé, diminué d'un abattement
# forfaitaire qui tient lieu de toute charge déductible ; s'y appliquent la tranche marginale
# du foyer et les prélèvements sociaux, qui eux ne dépendent d'aucun barème.
class Taxation
  # Le forfait du micro-foncier : 30 % de l'assiette, en place des charges réelles.
  ALLOWANCE_RATE = BigDecimal("30")

  # CSG, CRDS et prélèvement de solidarité réunis : le taux des revenus du patrimoine.
  SOCIAL_CHARGES_RATE = BigDecimal("17.2")

  # Les tranches du barème : celle où tombe le dernier euro de revenu du foyer. Des entiers,
  # parce que le barème n'en connaît pas d'autres — d'où une liste et non un taux libre.
  MARGINAL_TAX_RATES = [0, 11, 30, 41, 45].freeze

  # La tranche de la plupart des foyers qui investissent : ce que Prunay suppose à défaut.
  DEFAULT_MARGINAL_TAX_RATE = 30

  attr_reader :rent_excluding_charges, :marginal_tax_rate

  def initialize(rent_excluding_charges:, marginal_tax_rate:)
    # Décimaux d'office, comme dans Loan : un taux entier ferait une division entière.
    @rent_excluding_charges = rent_excluding_charges.to_d
    @marginal_tax_rate = marginal_tax_rate.to_d
  end

  # Ce que l'abattement retire de l'assiette : les charges réelles, forfaitairement.
  def allowance
    share(rent_excluding_charges, ALLOWANCE_RATE)
  end

  # Le revenu foncier imposable : l'assiette une fois l'abattement déduit.
  def taxable_income
    rent_excluding_charges - allowance
  end

  def income_tax
    share(taxable_income, marginal_tax_rate)
  end

  def social_charges
    share(taxable_income, SOCIAL_CHARGES_RATE)
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
