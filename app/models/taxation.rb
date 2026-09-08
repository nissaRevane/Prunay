# L'impôt d'une année de location. Ce que tous les régimes partagent — le barème du foyer, la
# mécanique des prélèvements sociaux — tient ici ; l'assiette, l'abattement et le taux social
# de chacun lui sont propres et se lisent dans sa classe (voir Taxation::Regime).
module Taxation
  # Le taux des revenus fonciers et des plus-values immobilières, que la LFSS 2026 laisse à 9,2 % de CSG.
  SOCIAL_CHARGES_RATE = BigDecimal("17.2")

  # Un loyer meublé est un BIC et non un revenu foncier : la LFSS 2026 y porte la CSG à 10,6 %.
  FURNISHED_SOCIAL_CHARGES_RATE = BigDecimal("18.6")

  # Le barème ne connaît que ces tranches : une liste, et non un taux libre.
  MARGINAL_TAX_RATES = [0, 11, 30, 41, 45].freeze

  # La tranche de la plupart des foyers qui investissent : ce que Prunay suppose à défaut.
  DEFAULT_MARGINAL_TAX_RATE = 30

  # Dans l'ordre où la simulation les présente : chaque nom est sa classe, son onglet et sa traduction.
  NAMES = %i[micro_foncier foncier_reel micro_bic lmnp].freeze

  DEFAULT_REGIME = NAMES.first

  # Le réel, seul à tenir compte des charges et des intérêts, départage deux biens financés autrement.
  REVIEW_REGIME = :foncier_reel

  def self.regime(name)
    raise ArgumentError, "régime fiscal inconnu : #{name.inspect}" unless NAMES.include?(name.to_s.to_sym)

    const_get(name.to_s.camelize)
  end

  def self.for(name, **attributes) = regime(name).new(**attributes)
end
