# Ce qu'une revente coûte au vendeur avant impôt : diagnostics et remise en état. Pas
# d'agence. L'impôt est dans Taxation::CapitalGain, l'indemnité anticipée dans Loan.
class SaleCosts
  # La remise en état est énoncée pour 50 m² et ne suit pas la surface.
  REFERENCE_SURFACE = 50

  attr_reader :surface, :diagnostics, :reference_refurbishment

  def initialize(surface:, diagnostics: 400, refurbishment: 500)
    @surface = surface.to_d
    @diagnostics = diagnostics.to_d
    @reference_refurbishment = refurbishment.to_d
  end

  def refurbishment = (reference_refurbishment * Math.sqrt(surface.to_f / REFERENCE_SURFACE).to_d).round(2)

  def total = diagnostics + refurbishment
end
