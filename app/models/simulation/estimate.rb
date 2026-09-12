# Les montants proposés au premier affichage, à l'échelle de la surface : des ordres de
# grandeur à corriger, pas des vérités. Les références se règlent dans Assumptions.
class Simulation::Estimate
  # Les références sont énoncées pour une surface de 50 m².
  REFERENCE_SURFACE = 50

  ROUNDING = 10

  attr_reader :assumptions

  def initialize(assumptions)
    @assumptions = assumptions
  end

  def for(field, surface)
    reference = assumptions.public_send(field)
    return reference if Assumptions::FIXED_AMOUNTS.include?(field.to_sym)

    surface = surface.to_f
    return 0 unless surface.positive?

    # La racine, non la proportion : un logement double ne loue pas au double.
    self.class.round(reference * Math.sqrt(surface / REFERENCE_SURFACE).to_d)
  end

  def down_payment(total_investment) = self.class.round(total_investment * assumptions.down_payment_share / 100)

  def self.round(amount) = (amount / ROUNDING).round * ROUNDING
end
