class RemoveRentalTypeFromSimulations < ActiveRecord::Migration[8.0]
  # Le meublé ne se distingue plus du nu : la question disparaît du parcours, et avec elle
  # les deux charges qu'elle seule justifiait — la CFE et le comptable. Leurs montants
  # partent avec leurs colonnes : aucune simulation ne les compte plus dans ses charges.
  def change
    remove_column :simulations, :rental_type, :string, null: false, default: "furnished"
    remove_column :simulations, :business_tax, :decimal, precision: 12, scale: 2, null: false, default: 0
    remove_column :simulations, :accounting_fees, :decimal, precision: 12, scale: 2, null: false, default: 0
  end
end
