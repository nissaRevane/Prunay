FactoryBot.define do
  # Les valeurs par défaut de Prunay, sauf mention contraire du test.
  factory :economic_conditions, class: "EconomicConditions" do
    user
    rent_growth_rate { 1 }
    property_growth_rate { 1 }
    inflation_rate { 2 }
    marginal_tax_rate { 30 }
  end
end
