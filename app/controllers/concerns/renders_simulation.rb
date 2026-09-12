# La fiche d'une simulation, renvoyée d'un bloc dès qu'une valeur change : tout y est dérivé,
# un chiffre corrigé en refait dix. Sur un refus, seul le message revient.
module RendersSimulation
  private

  def assign_detail(tab = params[:tab], regime = params[:regime])
    @tab = tab
    @regime = regime
    @exit_year = exit_year
    @projections = @simulation.projections
    @schedule = @simulation.loan.schedule
  end

  # L'année où le graphique de l'impôt fait revendre, REVIEW_YEAR à défaut.
  def exit_year
    number = params[:exit_year].to_i

    number.between?(1, Projection::HORIZON_YEARS) ? number : Projection::REVIEW_YEAR
  end

  def render_detail(tab = params[:tab], regime = params[:regime])
    assign_detail(tab, regime)

    render "simulations/update"
  end

  def render_error
    flash_error

    render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash"), status: :unprocessable_entity
  end

  def flash_error
    flash.now[:alert] = @simulation.errors.full_messages.join(", ")
  end
end
