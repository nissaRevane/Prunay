# Les conditions économiques par défaut d'un utilisateur : celles dont hérite chaque
# simulation qu'il crée. Les corriger ne touche pas aux simulations déjà écrites — chacune
# porte les siennes, modifiables dans son propre onglet.
class EconomicConditionsController < ApplicationController
  before_action :set_economic_conditions

  def edit
  end

  def update
    if @economic_conditions.update(economic_conditions_params)
      redirect_to edit_economic_conditions_path, notice: t("flash.economic_conditions.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  # Pas de ligne en base tant que rien n'a été modifié : la page ouvre alors sur les défauts.
  def set_economic_conditions
    @economic_conditions = EconomicConditions.for(current_user)
  end

  def economic_conditions_params
    params.require(:economic_conditions).permit(*EconomicConditions::ASSUMPTIONS)
  end
end
