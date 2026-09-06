class AddEarlyRepaymentFeeToSimulations < ActiveRecord::Migration[8.0]
  # Toutes les banques la prennent, mais elle se négocie : la case est cochée par défaut.
  def change
    add_column :simulations, :early_repayment_fee, :boolean, null: false, default: true
  end
end
