class AddOtherTypesMaintenanceToAssumptions < ActiveRecord::Migration[8.0]
  def change
    add_column :assumptions, :other_types_maintenance, :decimal, precision: 12, scale: 2, default: "1500.0", null: false
  end
end
