class AddLotsToSimulations < ActiveRecord::Migration[8.0]
  def change
    add_column :simulations, :lots, :jsonb, default: [], null: false
  end
end
