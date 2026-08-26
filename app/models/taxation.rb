# L'impôt d'une année de location. Ce que tous les régimes partagent — les prélèvements
# sociaux, le barème du foyer — tient ici ; ce que chacun retient de l'année lui est propre
# et se lit dans sa classe (voir Taxation::Regime).
module Taxation
  # CSG, CRDS et prélèvement de solidarité réunis : le taux des revenus du patrimoine.
  SOCIAL_CHARGES_RATE = BigDecimal("17.2")

  # Les tranches du barème : celle où tombe le dernier euro de revenu du foyer. Des entiers,
  # parce que le barème n'en connaît pas d'autres — d'où une liste et non un taux libre.
  MARGINAL_TAX_RATES = [0, 11, 30, 41, 45].freeze

  # La tranche de la plupart des foyers qui investissent : ce que Prunay suppose à défaut.
  DEFAULT_MARGINAL_TAX_RATE = 30

  # Les régimes, dans l'ordre où la simulation les présente : chaque nom est sa classe, son onglet et sa traduction.
  NAMES = %i[micro_foncier foncier_reel].freeze

  # Le régime que la liste des simulations suppose quand elle n'affiche qu'un cash-flow.
  DEFAULT_REGIME = NAMES.first

  def self.for(name, **attributes)
    raise ArgumentError, "régime fiscal inconnu : #{name.inspect}" unless NAMES.include?(name.to_s.to_sym)

    const_get(name.to_s.camelize).new(**attributes)
  end
end
