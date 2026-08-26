class SimulationsController < ApplicationController
  before_action :set_simulation, only: [:show, :edit, :update, :destroy]

  def index
    @simulations = current_user.simulations.order(purchase_date: :desc, id: :desc)
  end

  def show
    @projection = @simulation.projection
    @schedule = @simulation.amortization_schedule
  end

  # La création vit dans Simulations::StepsController, en quatre pages. `/simulations/new`
  # en reste la porte : il oublie le brouillon en cours et rouvre la première page.
  def new
    session.delete(Simulations::StepsController::DRAFT_KEY)

    redirect_to new_simulation_step_path(step: Simulation::STEPS.first)
  end

  # La modification, elle, tient sur une seule page : les quatre étapes n'ont de sens que
  # pour qui découvre le formulaire, pas pour qui vient corriger un chiffre.
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
    params.require(:simulation).permit(
      :name, :property_type, :address, :city, :energy_rating, :surface, :condominium,
      :purchase_price, :initial_works, :purchase_date, :credit, :down_payment,
      :loan_rate, :loan_duration_years, :loan_insurance,
      :monthly_rent, :occupancy_months, :rental_type,
      *Simulation::ANNUAL_CHARGES
    )
  end
end
