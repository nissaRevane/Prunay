# Une simulation née de cinq réponses, dont le loyer peut manquer : le reste, et le loyer laissé
# vide, est ce que le parcours complet aurait proposé. Les défauts vivent dans Simulation::Step.
module Simulation::Preset
  ANSWERS = %w[property_type city surface purchase_price monthly_rent].freeze

  module_function

  def complete(simulation)
    simulation.credit = true

    simulation.steps.each do |step|
      simulation.assign_attributes(simulation.defaults_for(step).reject { |name, _| given?(simulation, name) })
    end

    simulation
  end

  def given?(simulation, name) = ANSWERS.include?(name) && simulation[name].present?
end
