class AddPurchaseDiscountToSimulations < ActiveRecord::Migration[8.0]
  # Ce que l'acheteur estime payer sous la valeur réelle du bien : la revente part de cette
  # valeur-là, l'achat et la plus-value restent sur le prix payé.
  def change
    add_column :simulations, :purchase_discount, :decimal, precision: 12, scale: 2, null: false, default: 0
  end
end
