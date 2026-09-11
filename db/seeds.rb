require "json"

# bin/docker-entrypoint lance `db:prepare` à chaque démarrage, et db:prepare enchaîne sur
# db:seed la première fois. En production cela injecterait le jeu de démonstration dans la
# vraie base : on s'arrête là, sauf demande explicite.
if Rails.env.production? && ENV["ALLOW_PRODUCTION_SEED"] != "true"
  puts "Seeds ignorés en production (ALLOW_PRODUCTION_SEED=true pour forcer)."
  return
end

seed_data = JSON.parse(File.read(Rails.root.join("db", "seed_data.json")))

user_data = seed_data["user"]
user = User.find_or_create_by!(email: user_data["email"]) do |u|
  u.firstname = user_data["firstname"]
  u.lastname = user_data["lastname"]
  u.password = user_data["password"]
  u.password_confirmation = user_data["password"]
end

assumptions = Assumptions.for(user)
seed_data.fetch("assumptions", {}).each { |field, value| assumptions[field] = value }
assumptions.save!

# Une simulation n'a pas de nom : deux variantes d'un même bien ne diffèrent que par leurs
# chiffres. C'est donc l'ensemble de ses champs qui l'identifie, et rejouer le fichier ne crée
# rien de plus tant qu'il n'a pas changé.
attributes = seed_data.fetch("simulations", []).map { |data| data.slice(*AccountExport::SIMULATION_FIELDS) }
created = attributes.reject { |simulation| user.simulations.exists?(simulation) }
created.each { |simulation| user.simulations.create!(simulation) }

puts "Compte de démonstration : #{user_data["email"]} / #{user_data["password"]}"
puts "#{created.count} simulation(s) créée(s), #{attributes.count - created.count} déjà présente(s)."
