class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :simulations, dependent: :destroy

  # Absentes tant que l'utilisateur n'y a pas touché : Assumptions.for en tient lieu.
  has_one :assumptions, class_name: "Assumptions", dependent: :destroy

  validates :firstname, presence: true
  validates :lastname, presence: true

  def full_name = "#{firstname} #{lastname}"
end
