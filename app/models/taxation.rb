# L'impôt d'une année de location. Ce que tous les régimes partagent — le barème du foyer, la
# mécanique des prélèvements sociaux — tient ici ; l'assiette, l'abattement et le taux social
# de chacun lui sont propres et se lisent dans sa classe (voir Taxation::Regime).
module Taxation
  # CSG, CRDS et prélèvement de solidarité réunis : le taux des revenus fonciers et des
  # plus-values immobilières, que la LFSS 2026 a expressément laissés à 9,2 % de CSG.
  SOCIAL_CHARGES_RATE = BigDecimal("17.2")

  # Le taux des autres revenus du capital, le meublé compris : la même LFSS 2026 y porte la
  # CSG à 10,6 %. Un loyer meublé est un BIC, non un revenu foncier — il n'est pas épargné.
  FURNISHED_SOCIAL_CHARGES_RATE = BigDecimal("18.6")

  # Les tranches du barème : celle où tombe le dernier euro de revenu du foyer. Des entiers,
  # parce que le barème n'en connaît pas d'autres — d'où une liste et non un taux libre.
  MARGINAL_TAX_RATES = [0, 11, 30, 41, 45].freeze

  # La tranche de la plupart des foyers qui investissent : ce que Prunay suppose à défaut.
  DEFAULT_MARGINAL_TAX_RATE = 30

  # Les régimes, dans l'ordre où la simulation les présente — les deux du nu, puis celui du
  # meublé : chaque nom est sa classe, son onglet et sa traduction.
  NAMES = %i[micro_foncier foncier_reel micro_bic].freeze

  # Le régime supposé quand on ne le nomme pas : le plus simple du nu.
  DEFAULT_REGIME = NAMES.first

  # Celui sous lequel la liste des simulations les compare : le réel, seul à tenir compte des
  # charges et des intérêts, donc seul à départager deux biens qui ne se financent pas pareil.
  REVIEW_REGIME = :foncier_reel

  def self.for(name, **attributes)
    raise ArgumentError, "régime fiscal inconnu : #{name.inspect}" unless NAMES.include?(name.to_s.to_sym)

    const_get(name.to_s.camelize).new(**attributes)
  end
end
