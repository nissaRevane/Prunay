# L'impôt d'une année de location : ce que tous les régimes partagent — barème du foyer,
# prélèvements sociaux. L'assiette et l'abattement de chacun sont dans sa classe.
module Taxation
  # Foncier et plus-value : la LFSS 2026 y laisse la CSG à 9,2 %.
  SOCIAL_CHARGES_RATE = BigDecimal("17.2")

  # Un loyer meublé est un BIC : la LFSS 2026 y porte la CSG à 10,6 %.
  FURNISHED_SOCIAL_CHARGES_RATE = BigDecimal("18.6")

  MARGINAL_TAX_RATES = [0, 11, 30, 41, 45].freeze

  # La tranche de la plupart des foyers qui investissent.
  DEFAULT_MARGINAL_TAX_RATE = 30

  NAMES = %i[micro_foncier foncier_reel micro_bic lmnp].freeze

  DEFAULT_REGIME = NAMES.first

  REVIEW_REGIME = :foncier_reel

  def self.regime(name)
    raise ArgumentError, "régime fiscal inconnu : #{name.inspect}" unless NAMES.include?(name.to_s.to_sym)

    const_get(name.to_s.camelize)
  end

  def self.rent_premium_rate(name) = regime(name).rent_premium_rate

  def self.furnished?(name) = regime(name).furnished?

  def self.for(name, **attributes) = regime(name).new(**attributes)
end
