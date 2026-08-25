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
    maintenance { 0 }
    insurance { 0 }
    other_charges { 0 }
  end
end
