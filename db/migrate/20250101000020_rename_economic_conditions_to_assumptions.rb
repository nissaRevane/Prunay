class RenameEconomicConditionsToAssumptions < ActiveRecord::Migration[8.0]
  def change
    rename_table :economic_conditions, :assumptions
  end
end
