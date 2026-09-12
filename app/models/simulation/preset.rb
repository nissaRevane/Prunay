# Une simulation née de cinq réponses : le reste est ce que le parcours complet aurait
# proposé page après page. Les défauts vivent dans Simulation::Step, pas ici.
module Simulation::Preset
  ANSWERS = %w[property_type city surface purchase_price monthly_rent].freeze

  module_function

  def complete(simulation)
    simulation.credit = true

    simulation.steps.each do |step|
      simulation.assign_attributes(simulation.defaults_for(step).except(*ANSWERS))
    end

    simulation
  end
end
