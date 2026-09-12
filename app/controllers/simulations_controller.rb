class SimulationsController < ApplicationController
  include RendersSimulation

  # Une carte coûte le balayage des quatre régimes sur trente ans.
  PER_PAGE = 12

  before_action :set_simulation, only: [:show, :tax_burden, :statement, :edit, :update, :destroy]

  def index
    owned = current_user.simulations.order(purchase_date: :desc)

    @pages = [(owned.count / PER_PAGE.to_f).ceil, 1].max
    @page = params[:page].to_i.clamp(1, @pages)
    @simulations = owned.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
    @new_simulation = current_user.simulations.build
  end

  def show = assign_detail

  # Redessiner toute la fiche coûterait les TRI des courbes voisines pour rien.
  def tax_burden
    render partial: "simulations/tax_burden",
           locals: { simulation: @simulation, projections: @simulation.projections, exit_year: exit_year }
  end

  # Les 124 fiches d'année pesaient 80 % de la page ; celle-ci s'ouvre seule.
  def statement
    return head :not_found unless Taxation::NAMES.include?(params[:regime].to_s.to_sym)

    projection = @simulation.projection(params[:regime])
    year = projection.year(params[:year].to_i) or return head :not_found

    render partial: "simulations/statement", locals: { projection: projection, year: year }
  end

  def new
    session.delete(Simulations::StepsController::DRAFT_KEY)

    redirect_to new_simulation_step_path(step: Simulation::Step::NAMES.first)
  end

  def edit
  end

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
