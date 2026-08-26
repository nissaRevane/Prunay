class CreateEconomicConditions < ActiveRecord::Migration[8.0]
  def change
    create_table :economic_conditions do |t|
      # Une seule ligne par utilisateur : ce sont ses valeurs par défaut, pas un historique.
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.decimal :rent_growth_rate, precision: 5, scale: 2, default: "1.0", null: false
      t.decimal :property_growth_rate, precision: 5, scale: 2, default: "1.0", null: false
      t.decimal :inflation_rate, precision: 5, scale: 2, default: "2.0", null: false

      t.timestamps
    end
  end
end
