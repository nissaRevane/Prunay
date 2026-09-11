# Les montants proposés au premier affichage, mis à l'échelle de la surface du bien. Ce sont
# des ordres de grandeur, pas des vérités : le formulaire les affiche pré-remplis pour que
# l'utilisateur les corrige, pas pour qu'il les subisse. Les références, elles, sont les
# siennes et se règlent dans Assumptions.
class Simulation::Estimate
  # Les références sont énoncées pour une surface de 50 m².
  REFERENCE_SURFACE = 50

  # Une estimation au centime se lirait comme un calcul, alors que ce n'en est pas un.
  ROUNDING = 10

  attr_reader :assumptions

  def initialize(assumptions)
    @assumptions = assumptions
  end

  # La racine carrée, et non la proportion : un logement double ne se loue pas au double du prix.
  def for(field, surface)
    reference = assumptions.public_send(field)
    return reference if Assumptions::FIXED_AMOUNTS.include?(field.to_sym)

    surface = surface.to_f
    return 0 unless surface.positive?

    self.class.round(reference * Math.sqrt(surface / REFERENCE_SURFACE).to_d)
  end

  def down_payment(total_investment) = self.class.round(total_investment * assumptions.down_payment_share / 100)

  def self.round(amount) = (amount / ROUNDING).round * ROUNDING
end
