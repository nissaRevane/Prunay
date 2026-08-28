class SimulationsController < ApplicationController
  before_action :set_simulation, only: [:show, :edit, :update, :destroy]

  def index
    @simulations = current_user.simulations.order(purchase_date: :desc, id: :desc)
  end

  # `tab` dit quel onglet s'ouvre : la fiche y revient après une modification faite dans l'un
  # d'eux, et le premier s'ouvre à défaut.
  def show
    @tab = params[:tab]
    @projections = @simulation.projections
    @schedule = @simulation.loan.schedule
  end

  # La création vit dans Simulations::StepsController, en quatre pages. `/simulations/new`
  # en reste la porte : il oublie le brouillon en cours et rouvre la première page.
  def new
    session.delete(Simulations::StepsController::DRAFT_KEY)

    redirect_to new_simulation_step_path(step: Simulation::Step::NAMES.first)
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
      :property_type, :address, :city, :energy_rating, :surface, :condominium,
      :purchase_price, :initial_works, :purchase_date, :credit, :down_payment,
      :loan_rate, :loan_duration_years, :loan_insurance, :loan_guarantee_fees, :loan_application_fees,
      :monthly_rent, :monthly_charges, :occupancy_months,
      *Simulation::ANNUAL_CHARGES
    )
  end
end
