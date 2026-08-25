class CreateSimulations < ActiveRecord::Migration[8.0]
  def change
    create_table :simulations do |t|
      t.references :user, null: false, foreign_key: true
      t.date :purchase_date, null: false
      t.decimal :purchase_price, precision: 12, scale: 2, null: false
      t.decimal :monthly_rent, precision: 12, scale: 2, null: false
      t.timestamps
    end

    add_index :simulations, [:user_id, :purchase_date]
  end
end
