class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :simulations, dependent: :destroy

  # Les conditions économiques dont hérite chaque simulation créée. Absente tant qu'elle n'a
  # pas été modifiée : EconomicConditions.for en tient lieu.
  has_one :economic_conditions, class_name: "EconomicConditions", dependent: :destroy

  validates :firstname, presence: true
  validates :lastname, presence: true

  def full_name
    "#{firstname} #{lastname}"
  end
end
