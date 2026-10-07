module Taxation
  # Le micro-BIC : le forfait du meublé, un abattement de moitié en place de toute charge - la
  # CFE comprise, qui reste due sans alléger l'assiette.
  class MicroBic < Bic
    # 50 % des recettes, pour une location meublée de longue durée.
    ALLOWANCE_RATE = BigDecimal("50")

    # Au-delà de ces recettes annuelles, le réel s'impose (art. 50-0 CGI).
    RECEIPTS_CEILING = 77_700

    def self.available?(receipts) = receipts <= RECEIPTS_CEILING

    def allowance_rate = ALLOWANCE_RATE

    def allowance = share(receipts, allowance_rate)

    def taxable_income = receipts - allowance
  end
end
