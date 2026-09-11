class RemoveNotaryFeesFromAssumptions < ActiveRecord::Migration[8.0]
  def change
    remove_column :assumptions, :notary_fees_rate, :decimal, precision: 6, scale: 3, default: "7.42", null: false
    remove_column :assumptions, :notary_fees_base, :decimal, precision: 12, scale: 2, default: "1772.0", null: false
  end
end
