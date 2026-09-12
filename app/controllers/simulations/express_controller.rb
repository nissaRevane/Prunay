module Simulations
  class ExpressController < ApplicationController
    RECENT = 1

    throttle name: "create", to: 20, within: 1.minute, only: :create

    before_action :set_recent

    def new = @simulation = current_user.simulations.build

    def create
      @simulation = Simulation::Preset.complete(current_user.simulations.build(assumptions.merge(express_params)))

      return render :new, status: :unprocessable_entity, formats: :html unless @simulation.save

      flash[:notice] = t("flash.simulations.created")

      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.action(:redirect, simulation_path(@simulation)) }
        format.html { redirect_to @simulation }
      end
    end

    private

    def set_recent = @recent = current_user.simulations.order(purchase_date: :desc).limit(RECENT)

    def assumptions = Assumptions.for(current_user).economic

    def express_params
      params.fetch(:simulation, ActionController::Parameters.new)
            .permit(*Simulation::Preset::ANSWERS)
            .to_h
    end
  end
end
