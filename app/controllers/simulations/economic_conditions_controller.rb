module Simulations
  # Les conditions économiques d'une simulation, corrigées depuis son onglet. Elles ne
  # touchent qu'elle : les valeurs par défaut de l'utilisateur sont ailleurs, et une
  # simulation les a copiées une fois pour toutes le jour de sa création.
  class EconomicConditionsController < ApplicationController
    def update
      @simulation = current_user.simulations.find(params[:simulation_id])

      return render_simulation unless @simulation.update(economic_conditions_params)

      redirect_to simulation_path(@simulation, tab: SimulationsHelper::ECONOMIC_CONDITIONS_TAB),
                  notice: t("flash.simulations.updated")
    end

    private

    # L'onglet se rouvre sur ses erreurs, les autres panneaux restant ceux de la fiche.
    def render_simulation
      @tab = SimulationsHelper::ECONOMIC_CONDITIONS_TAB
      @projection = @simulation.projection
      @schedule = @simulation.loan.schedule

      render "simulations/show", status: :unprocessable_entity
    end

    def economic_conditions_params
      params.require(:simulation).permit(*EconomicConditions::RATES)
    end
  end
end
