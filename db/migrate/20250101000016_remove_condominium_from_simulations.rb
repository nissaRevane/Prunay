class RemoveCondominiumFromSimulations < ActiveRecord::Migration[8.0]
  # Seules les charges de copropriété comptaient : le reste ne dépendait plus que d'une case.
  def change
    remove_column :simulations, :condominium, :boolean, default: false, null: false
  end
end
