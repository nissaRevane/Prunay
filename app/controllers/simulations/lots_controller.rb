module Simulations
  class LotsController < ApplicationController
    include RendersSimulation

    TAB = SimulationsHelper::PARAMETERS_TAB

    before_action :set_simulation

    def create
      surface = params.require(:lot).permit(:surface)[:surface]

      save(@simulation.lots + [{ "surface" => surface }.merge(Simulation::Step.lot_defaults(@simulation, surface))])
    end

    # Le dernier lot reste : on défait l'immeuble depuis le formulaire complet.
    def destroy
      index = params[:id].to_i
      return head :not_found unless @simulation.lots.size > 1 && @simulation.lots[index]

      save(@simulation.lots.reject.with_index { |_, row| row == index })
    end

    private

    def set_simulation
      @simulation = current_user.simulations.find(params[:simulation_id])
    end

    def save(lots)
      if @simulation.update(lots: lots)
        respond_to do |format|
          format.turbo_stream { render_detail(TAB) }
          format.html { redirect_to simulation_path(@simulation, tab: TAB), notice: t("flash.simulations.updated") }
        end
      else
        respond_to do |format|
          format.turbo_stream { render_error }
          format.html do
            redirect_to simulation_path(@simulation, tab: TAB), alert: @simulation.errors.full_messages.join(", ")
          end
        end
      end
    end
  end
end
