# Les hypothèses d'un utilisateur : ce dont hérite chaque simulation qu'il crée, ce que le
# formulaire lui propose, et les règles de calcul qu'il retient. Corriger les premières ne
# touche pas aux simulations déjà écrites — chacune porte les siennes, modifiables dans son
# propre onglet ; corriger les dernières les recalcule toutes.
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

  # Pas de ligne en base tant que rien n'a été modifié : la page ouvre alors sur les défauts.
  def set_assumptions
    @assumptions = Assumptions.for(current_user)
  end

  def assumptions_params
    params.require(:assumptions).permit(*Assumptions::EDITABLE)
  end
end
