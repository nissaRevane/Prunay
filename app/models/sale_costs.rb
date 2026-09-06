# Ce qu'une revente coûte au vendeur, avant impôt : les diagnostics obligatoires, une remise en
# état que la surface mesure et, en copropriété, l'état daté. Pas d'agence — le bien se vend de
# particulier à particulier. L'impôt sur la plus-value est dans Taxation::CapitalGain, et
# l'indemnité de remboursement anticipé dans Loan : elle est due à la banque, pas à la vente.
class SaleCosts
  # Le dossier de diagnostic technique se paie au dossier et non au mètre carré.
  DIAGNOSTICS = BigDecimal("400")

  # La remise en état est énoncée pour 50 m² : deux fois la surface ne fait pas deux fois les travaux.
  REFURBISHMENT = BigDecimal("500")

  REFERENCE_SURFACE = 50

  # Le décret plafonne à 380 € TTC ce que le syndic prend pour l'état daté : personne ne demande moins.
  CONDOMINIUM_STATEMENT = BigDecimal("380")

  attr_reader :surface

  def initialize(surface:, condominium: false)
    @surface = surface.to_d
    @condominium = condominium
  end

  def condominium? = @condominium

  def diagnostics = DIAGNOSTICS

  def condominium_statement = condominium? ? CONDOMINIUM_STATEMENT : 0

  def refurbishment = (REFURBISHMENT * Math.sqrt(surface.to_f / REFERENCE_SURFACE).to_d).round(2)

  def total = diagnostics + refurbishment + condominium_statement
end
