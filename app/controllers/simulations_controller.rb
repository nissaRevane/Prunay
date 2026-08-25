class SimulationsController < ApplicationController
  before_action :set_simulation, only: [:show, :edit, :update, :destroy]

  def index
    @simulations = current_user.simulations.order(purchase_date: :desc, id: :desc)
  end

  def show
    @projection = @simulation.projection
  end

  def new
    @simulation = current_user.simulations.build(purchase_date: Date.today)
  end

  def create
    @simulation = current_user.simulations.build(simulation_params)

    if @simulation.save
      redirect_to @simulation, notice: t("flash.simulations.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @simulation.update(simulation_params)
      redirect_to @simulation, notice: t("flash.simulations.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @simulation.destroy
    redirect_to simulations_path, notice: t("flash.simulations.destroyed"), status: :see_other
  end

  private

  def set_simulation
    @simulation = current_user.simulations.find(params[:id])
  end

  def simulation_params
    params.require(:simulation).permit(:purchase_date, :purchase_price, :monthly_rent)
  end
end
