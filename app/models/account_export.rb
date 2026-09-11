# Sérialise un compte entier dans la forme de db/seed_data.json, pour qu'un export puisse être
# redonné tel quel à db/seeds.rb.
#
# Le mot de passe n'est jamais exporté : Devise n'en garde qu'une empreinte, et c'est un mot de
# passe aléatoire qui prend sa place. Ré-alimenter depuis un export recrée donc le compte avec
# celui-là, pas avec le vrai.
class AccountExport
  PASSWORD_LENGTH = 24

  # Ce qu'une simulation porte et qu'elle ne tient pas de la base : une colonne de plus voyage
  # d'elle-même, des deux côtés du rond-point export → seed.
  SIMULATION_FIELDS = (Simulation.column_names - %w[id user_id created_at updated_at]).freeze

  def initialize(user)
    @user = user
  end

  def filename = "prunay-export-#{@user.email.parameterize}-#{Date.current.iso8601}.json"

  def to_json = JSON.pretty_generate(to_h)

  def to_h
    {
      "user" => user_data,
      "assumptions" => assumptions_data,
      "simulations" => @user.simulations.order(:id).map { |simulation| simulation_data(simulation) }
    }
  end

  private

  def user_data
    {
      "email" => @user.email,
      "password" => Devise.friendly_token(PASSWORD_LENGTH)
    }
  end

  # Celles de l'utilisateur, ou les valeurs par défaut tant qu'il n'y a pas touché.
  def assumptions_data
    Assumptions.for(@user).slice(*Assumptions::EDITABLE).transform_values { |value| serialize(value) }
  end

  def simulation_data(simulation) = SIMULATION_FIELDS.index_with { |field| serialize(simulation[field]) }

  # Les montants ronds restent entiers pour que la sortie se lise comme un fichier écrit à la
  # main ; un BigDecimal serait sinon sérialisé en chaîne.
  def serialize(value)
    case value
    when BigDecimal then value.to_i == value ? value.to_i : value.to_f
    when Date then value.iso8601
    else value
    end
  end
end
