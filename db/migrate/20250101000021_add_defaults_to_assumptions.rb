class AddDefaultsToAssumptions < ActiveRecord::Migration[8.0]
  AMOUNTS = { monthly_rent: 650, property_tax: 700, insurance: 150, maintenance: 1_000,
              condominium_fees: 1_000, other_charges: 100, furniture: 2_110, furniture_maintenance: 370,
              monthly_charges: 0, management_fees: 0, rent_guarantee: 0, accounting_fees: 500,
              loan_application_fees_floor: 500, sale_diagnostics: 400, sale_refurbishment: 500,
              notary_fees_base: 1_772 }.freeze

  RATES = { down_payment_share: 10, loan_rate: "3.6", loan_insurance_rate: "0.12",
            loan_guarantee_rate: "1.667", loan_application_rate: 1, notary_fees_rate: "7.42" }.freeze

  def change
    AMOUNTS.each { |name, default| add_column :assumptions, name, :decimal, precision: 12, scale: 2, default: default, null: false }
    RATES.each { |name, default| add_column :assumptions, name, :decimal, precision: 6, scale: 3, default: default, null: false }

    add_column :assumptions, :occupancy_months, :decimal, precision: 4, scale: 1, default: 11, null: false
    add_column :assumptions, :loan_duration_years, :integer, default: 20, null: false
    add_column :assumptions, :purchase_delay_months, :integer, default: 3, null: false
  end
end
