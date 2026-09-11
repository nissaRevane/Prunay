module Simulations
  # La création en cinq réponses, sur une page et sans brouillon : Simulation::Preset complète
  # le reste avec les défauts du parcours complet, et la fiche étant modifiable au clic, un
  # chiffre qui ne convient pas se corrige après coup plutôt qu'avant.
  class ExpressController < ApplicationController
    RECENT = 1

    before_action :set_recent

    def new = @simulation = current_user.simulations.build

    def create
      @simulation = Simulation::Preset.complete(current_user.simulations.build(assumptions.merge(express_params)))

      return render :new, status: :unprocessable_entity, formats: :html unless @simulation.save

      flash[:notice] = t("flash.simulations.created")

      # Soumis depuis la pop-in, le formulaire répond dans son cadre : seul un flux en sort.
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.action(:redirect, simulation_path(@simulation)) }
        format.html { redirect_to @simulation }
      end
    end

    private

    # La page est l'accueil d'un connecté : le formulaire, et le dernier bien pour y revenir.
    def set_recent = @recent = current_user.simulations.order(purchase_date: :desc).limit(RECENT)

    # Aucune page ne les demande : la simulation naît avec celles de l'utilisateur.
    def assumptions = Assumptions.for(current_user).economic

    def express_params
      params.fetch(:simulation, ActionController::Parameters.new)
            .permit(*Simulation::Preset::ANSWERS)
            .to_h
    end
  end
end
