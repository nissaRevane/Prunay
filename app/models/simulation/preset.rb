# Une simulation née de cinq réponses : tout le reste est, mot pour mot, ce que le parcours
# complet aurait proposé page après page. Les défauts continuent donc de vivre dans
# Simulation::Step, et rien ici ne leur en oppose d'autres.
module Simulation::Preset
  # Ce que le formulaire rapide demande : tout autre champ est un défaut.
  ANSWERS = %w[property_type city surface purchase_price monthly_rent].freeze

  module_function

  # Dans l'ordre des pages, car l'apport se lit sur le prix et le crédit sur l'apport.
  def complete(simulation)
    simulation.credit = true

    simulation.steps.each do |step|
      simulation.assign_attributes(simulation.defaults_for(step).except(*ANSWERS))
    end

    simulation
  end
end
