FactoryBot.define do
  factory :simulation do
    user
    purchase_date { Date.new(2025, 1, 15) }
    purchase_price { 200_000 }
    monthly_rent { 800 }
  end
end
