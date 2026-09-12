class AssumptionsController < ApplicationController
  before_action :set_assumptions

  def edit
  end

  def update
    if @assumptions.update(assumptions_params)
      redirect_to edit_assumptions_path, notice: t("flash.assumptions.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  # Pas de ligne en base tant que rien n'a été modifié : les défauts suffisent.
  def set_assumptions
    @assumptions = Assumptions.for(current_user)
  end

  def assumptions_params
    params.require(:assumptions).permit(*Assumptions::EDITABLE)
  end
end
