class AddRentalStartDateToSimulations < ActiveRecord::Migration[8.0]
  def up
    add_column :simulations, :rental_start_date, :date

    execute "UPDATE simulations SET rental_start_date = purchase_date + INTERVAL '1 month'"

    change_column_null :simulations, :rental_start_date, false
  end

  def down
    remove_column :simulations, :rental_start_date
  end
end
