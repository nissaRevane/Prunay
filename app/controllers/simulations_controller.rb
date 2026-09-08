class SimulationsController < ApplicationController
  include RendersSimulation

  before_action :set_simulation, only: [:show, :edit, :update, :destroy]

  def index
    @simulations = current_user.simulations.order(purchase_date: :desc, id: :desc)
  end

  # `tab` dit quel onglet s'ouvre : la fiche y revient après une modification, le premier à défaut.
  def show = assign_detail

  # La création vit dans Simulations::StepsController : entrer ici oublie le brouillon et rouvre la première page.
  def new
    session.delete(Simulations::StepsController::DRAFT_KEY)

    redirect_to new_simulation_step_path(step: Simulation::Step::NAMES.first)
  end

  # Les étapes n'ont de sens que pour qui découvre le formulaire : corriger un chiffre tient sur une page.
  def edit
  end

  # Une valeur cliquée sur la fiche s'enregistre seule ; le formulaire complet, lui, redirige.
  def update
    if @simulation.update(simulation_params)
      respond_to do |format|
        format.turbo_stream { render_detail }
        format.html { redirect_to @simulation, notice: t("flash.simulations.updated") }
      end
    else
      respond_to do |format|
        format.turbo_stream { render_error }
        format.html { render :edit, status: :unprocessable_entity }
      end
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
      :property_type, :address, :city, :energy_rating, :surface,
      :purchase_price, :initial_works, :furniture, :purchase_date, :credit, :down_payment,
      :loan_rate, :loan_duration_years, :loan_insurance, :loan_guarantee_fees, :loan_application_fees,
      :early_repayment_fee,
      :monthly_rent, :monthly_charges, :occupancy_months,
      *Simulation::ANNUAL_CHARGES, *Simulation::REGIME_CHARGES
    )
  end
end
