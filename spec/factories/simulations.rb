FactoryBot.define do
  # Le bien par défaut est neutre : loué douze mois sur douze et sans charges, pour que la
  # projection d'un exemple ne dépende que de ce que le test énonce lui-même.
  factory :simulation do
    user
    property_type { "apartment" }
    city { "Nantes" }
    surface { 50 }
    purchase_date { Date.new(2025, 1, 15) }
    purchase_price { 200_000 }
    initial_works { 0 }
    monthly_rent { 800 }
    occupancy_months { 12 }
    rental_type { "furnished" }
    property_tax { 0 }
    insurance { 0 }
    maintenance { 0 }
    condominium_fees { 0 }
    management_fees { 0 }
    rent_guarantee { 0 }
    business_tax { 0 }
    accounting_fees { 0 }
    other_charges { 0 }

    # Une économie immobile, comme le reste du bien par défaut : un test qui parle d'évolution
    # énonce lui-même ses taux, et les autres n'ont pas à s'en défendre.
    rent_growth_rate { 0 }
    property_growth_rate { 0 }
    inflation_rate { 0 }

    # Un achat à crédit : 200 000 € de prix, 16 612 € de frais de notaire, 23 388 € d'apport
    # — soit 193 224 € empruntés sur vingt ans à 3 %.
    trait :with_credit do
      credit { true }
      down_payment { 23_388 }
      loan_rate { 3.0 }
      loan_duration_years { 20 }
    end
  end
end
