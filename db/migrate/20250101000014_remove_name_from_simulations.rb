class RemoveNameFromSimulations < ActiveRecord::Migration[8.0]
  # Le nom d'une simulation se déduit désormais du bien seul : plus personne ne le saisit,
  # donc plus rien à stocker.
  def change
    remove_column :simulations, :name, :string, default: "", null: false
  end
end
