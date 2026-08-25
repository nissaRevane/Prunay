# Le compte de démonstration, idempotent : `rails db:seed` peut se rejouer sans créer
# de doublon ni écraser un mot de passe changé depuis.
User.find_or_create_by!(email: "demo@prunay.app") do |user|
  user.firstname = "Demo"
  user.lastname = "Prunay"
  user.password = "password123"
  user.password_confirmation = "password123"
end

puts "Compte de démonstration : demo@prunay.app / password123"
