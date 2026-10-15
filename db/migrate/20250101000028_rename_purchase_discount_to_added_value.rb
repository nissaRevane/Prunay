# La décote couvre aussi les travaux qui valorisent le bien : ce que le bien vaut au-delà de son prix.
class RenamePurchaseDiscountToAddedValue < ActiveRecord::Migration[8.0]
  def change
    rename_column :simulations, :purchase_discount, :added_value
  end
end
