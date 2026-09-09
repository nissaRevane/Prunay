module Simulations
  # La création en cinq réponses, sur une page et sans brouillon : Simulation::Preset complète
  # le reste avec les défauts du parcours complet, et la fiche étant modifiable au clic, un
  # chiffre qui ne convient pas se corrige après coup plutôt qu'avant.
  class ExpressController < ApplicationController
    def new = @simulation = current_user.simulations.build

    def create
      @simulation = Simulation::Preset.complete(current_user.simulations.build(assumptions.merge(express_params)))

      if @simulation.save
        redirect_to @simulation, notice: t("flash.simulations.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    # Aucune page ne les demande : la simulation naît avec celles de l'utilisateur.
    def assumptions = EconomicConditions.for(current_user).assumptions

    def express_params
      params.fetch(:simulation, ActionController::Parameters.new)
            .permit(*Simulation::Preset::ANSWERS)
            .to_h
    end
  end
end
