# Ce qu'une revente coûte au vendeur, avant impôt : les diagnostics obligatoires et une remise
# en état que la surface mesure. Pas d'agence — le bien se vend de particulier à particulier.
# L'impôt sur la plus-value est dans Taxation::CapitalGain, et l'indemnité de remboursement
# anticipé dans Loan : elle est due à la banque, pas à la vente.
class SaleCosts
  # La remise en état est énoncée pour 50 m² : deux fois la surface ne fait pas deux fois les travaux.
  REFERENCE_SURFACE = 50

  attr_reader :surface, :diagnostics, :reference_refurbishment

  def initialize(surface:, diagnostics: 400, refurbishment: 500)
    @surface = surface.to_d
    # Le dossier de diagnostic technique se paie au dossier et non au mètre carré.
    @diagnostics = diagnostics.to_d
    @reference_refurbishment = refurbishment.to_d
  end

  def refurbishment = (reference_refurbishment * Math.sqrt(surface.to_f / REFERENCE_SURFACE).to_d).round(2)

  def total = diagnostics + refurbishment
end
