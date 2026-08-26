class AddMarginalTaxRate < ActiveRecord::Migration[8.0]
  # La tranche marginale du foyer, des deux côtés comme les autres hypothèses : celle de
  # l'utilisateur, dont chaque simulation hérite, puis celle que la simulation porte pour
  # elle seule. Un entier : le barème n'a que cinq tranches, toutes en points ronds.
  def change
    add_column :economic_conditions, :marginal_tax_rate, :integer, null: false, default: 30
    add_column :simulations, :marginal_tax_rate, :integer, null: false, default: 30
  end
end
