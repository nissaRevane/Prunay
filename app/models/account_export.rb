# Sérialise un compte dans la forme de db/seed_data.json, pour que db/seeds.rb le reprenne tel
# quel. Le mot de passe n'est pas exporté : un mot de passe aléatoire prend sa place.
class AccountExport
  PASSWORD_LENGTH = 24

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

  def assumptions_data
    Assumptions.for(@user).slice(*Assumptions::EDITABLE).transform_values { |value| serialize(value) }
  end

  def simulation_data(simulation) = SIMULATION_FIELDS.index_with { |field| serialize(simulation[field]) }

  def serialize(value)
    case value
    when BigDecimal then value.to_i == value ? value.to_i : value.to_f
    when Date then value.iso8601
    else value
    end
  end
end
