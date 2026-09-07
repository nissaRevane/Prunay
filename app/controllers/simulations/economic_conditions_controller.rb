module Simulations
  # Les conditions économiques d'une simulation, corrigées depuis son onglet. Elles ne
  # touchent qu'elle : les valeurs par défaut de l'utilisateur sont ailleurs, et une
  # simulation les a copiées une fois pour toutes le jour de sa création.
  class EconomicConditionsController < ApplicationController
    include RendersSimulation

    TAB = SimulationsHelper::ECONOMIC_CONDITIONS_TAB

    def update
      @simulation = current_user.simulations.find(params[:simulation_id])

      if @simulation.update(economic_conditions_params)
        respond_to do |format|
          format.turbo_stream { render_detail(TAB) }
          format.html { redirect_to simulation_path(@simulation, tab: TAB), notice: t("flash.simulations.updated") }
        end
      else
        respond_to do |format|
          format.turbo_stream { render_error }
          format.html { render_simulation }
        end
      end
    end

    private

    # L'onglet se rouvre sur ses erreurs, les autres panneaux restant ceux de la fiche.
    def render_simulation
      flash_error
      assign_detail(TAB)

      render "simulations/show", status: :unprocessable_entity
    end

    def economic_conditions_params
      params.require(:simulation).permit(*EconomicConditions::ASSUMPTIONS)
    end
  end
end
