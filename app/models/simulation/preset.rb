# Une simulation née de cinq réponses, dont le loyer peut manquer : le reste, et le loyer laissé
# vide, est ce que le parcours complet aurait proposé. Les défauts vivent dans Simulation::Step.
module Simulation::Preset
  ANSWERS = %w[property_type city surface purchase_price monthly_rent].freeze

  LOT_SURFACE = 50

  module_function

  def complete(simulation)
    simulation.credit = true
    divide(simulation)

    simulation.steps.each do |step|
      simulation.assign_attributes(simulation.defaults_for(step).reject { |name, _| given?(simulation, name) })
    end

    simulation
  end

  # Un loyer saisi se répartit selon la surface, sinon chaque lot a le sien.
  def divide(simulation)
    surface = simulation.surface.to_d
    return simulation unless simulation.building? && surface.positive?

    surfaces = lot_surfaces(surface)
    simulation.lots = surfaces.zip(lot_rents(simulation[:monthly_rent], surfaces)).map do |lot_surface, rent|
      Simulation::Step.lot_defaults(simulation, lot_surface)
                      .merge({ "surface" => lot_surface, "monthly_rent" => rent }.compact)
                      .transform_values { |value| Assumptions.whole(value).to_s }
    end

    simulation
  end

  # Sous deux lots pleins, deux moitiés ; au-delà, le dernier garde le reste.
  def lot_surfaces(surface)
    if surface < 2 * LOT_SURFACE
      half = (surface / 2).round(2)
      return [half, surface - half]
    end

    count = [(surface / LOT_SURFACE).floor - 1, Simulation::MAX_LOTS - 1].min
    [*Array.new(count, LOT_SURFACE), surface - LOT_SURFACE * count]
  end

  def lot_rents(rent, surfaces)
    return Array.new(surfaces.size) if rent.nil?

    rents = surfaces[...-1].map { |surface| (rent * surface / surfaces.sum).round(2) }
    [*rents, rent - rents.sum]
  end

  def given?(simulation, name) = ANSWERS.include?(name) && simulation[name].present?
end
