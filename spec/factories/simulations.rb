FactoryBot.define do
  factory :simulation do
    user
    property_type { "apartment" }
    city { "Nantes" }
    surface { 50 }
    purchase_date { Date.new(2025, 1, 15) }
    purchase_price { 200_000 }
    purchase_discount { 0 }
    initial_works { 0 }
    monthly_rent { 800 }
    monthly_charges { 0 }
    occupancy_months { 12 }
    property_tax { 0 }
    insurance { 0 }
    maintenance { 0 }
    condominium_fees { 0 }
    management_fees { 0 }
    rent_guarantee { 0 }
    accounting_fees { 0 }
    furniture { 0 }
    furniture_maintenance { 0 }
    other_charges { 0 }

    rent_growth_rate { 0 }
    property_growth_rate { 0 }
    inflation_rate { 0 }

    marginal_tax_rate { 0 }

    trait :with_credit do
      credit { true }
      down_payment { 23_388 }
      loan_rate { 3.0 }
      loan_duration_years { 20 }
    end
  end
end
