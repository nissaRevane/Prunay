module Taxation
  # Le micro-BIC : le forfait du meublé. Un abattement de moitié en place de toute charge —
  # la CFE comprise, qui reste due et pèse sur l'année sans alléger l'assiette. Ce qu'il a de
  # meublé, recettes et prélèvements sociaux, se lit dans Taxation::Bic.
  class MicroBic < Bic
    # Le forfait du micro-BIC : 50 % des recettes pour une location meublée de longue durée.
    ALLOWANCE_RATE = BigDecimal("50")

    def allowance_rate = ALLOWANCE_RATE

    def allowance = share(receipts, allowance_rate)

    def taxable_income = receipts - allowance
  end
end
