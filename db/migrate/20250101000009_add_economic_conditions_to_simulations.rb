class AddEconomicConditionsToSimulations < ActiveRecord::Migration[8.0]
  # Les mêmes colonnes que economic_conditions : chaque simulation en reçoit une copie à sa
  # création, et la corrige ensuite pour elle seule.
  def change
    add_column :simulations, :rent_growth_rate, :decimal, precision: 5, scale: 2, default: "1.0", null: false
    add_column :simulations, :property_growth_rate, :decimal, precision: 5, scale: 2, default: "1.0", null: false
    add_column :simulations, :inflation_rate, :decimal, precision: 5, scale: 2, default: "2.0", null: false
  end
end
