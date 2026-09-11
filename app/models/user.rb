class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :simulations, dependent: :destroy

  has_one :assumptions, class_name: "Assumptions", dependent: :destroy
end
