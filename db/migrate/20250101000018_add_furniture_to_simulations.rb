class AddFurnitureToSimulations < ActiveRecord::Migration[8.0]
  # Un meublé se loue meublé : les meubles s'achètent à la signature et s'entretiennent chaque
  # année. Deux colonnes que l'utilisateur saisit, et que seuls les régimes du meublé dépensent.
  def change
    add_column :simulations, :furniture, :decimal, precision: 12, scale: 2, null: false, default: 0
    add_column :simulations, :furniture_maintenance, :decimal, precision: 12, scale: 2, null: false, default: 0
  end
end
