class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :simulations, dependent: :destroy

  # Absente tant que l'utilisateur n'y a pas touché : EconomicConditions.for en tient lieu.
  has_one :economic_conditions, class_name: "EconomicConditions", dependent: :destroy

  validates :firstname, presence: true
  validates :lastname, presence: true

  def full_name
    "#{firstname} #{lastname}"
  end
end
