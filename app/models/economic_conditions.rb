# Les conditions économiques supposées au fil des ans : ce que les loyers gagnent chaque
# année, ce que le bien prend en valeur, l'inflation qui alourdit les charges, et la tranche
# du barème où le foyer est imposé. Cet enregistrement porte celles d'un utilisateur ; chaque
# simulation en reçoit une copie.
class EconomicConditions < ApplicationRecord
  # Les trois taux, dans l'ordre où les formulaires les demandent.
  RATES = %i[rent_growth_rate property_growth_rate inflation_rate].freeze

  # Tout ce qu'une simulation hérite : les taux, et la tranche marginale d'imposition — qui
  # n'est pas un taux libre mais un choix dans le barème (voir Taxation::MARGINAL_TAX_RATES).
  ASSUMPTIONS = [*RATES, :marginal_tax_rate].freeze

  # Ce que Prunay suppose tant que personne n'en a décidé autrement.
  DEFAULTS = { rent_growth_rate: BigDecimal("1"), property_growth_rate: BigDecimal("1"),
               inflation_rate: BigDecimal("2"),
               marginal_tax_rate: Taxation::DEFAULT_MARGINAL_TAX_RATE }.freeze

  # Au-delà, ce n'est plus une hypothèse économique : un loyer doublerait en deux ans.
  MIN_RATE = -50

  MAX_RATE = 50

  belongs_to :user

  validates(*RATES, presence: true,
            numericality: { greater_than_or_equal_to: MIN_RATE, less_than_or_equal_to: MAX_RATE })

  validates :marginal_tax_rate, presence: true, inclusion: { in: Taxation::MARGINAL_TAX_RATES }

  # Celles de l'utilisateur, ou les valeurs par défaut tant qu'il n'y a pas touché.
  def self.for(user)
    user.economic_conditions || user.build_economic_conditions(DEFAULTS)
  end

  # De quoi en habiller une simulation qui naît : les colonnes portent les mêmes noms des deux côtés.
  def assumptions
    ASSUMPTIONS.index_with { |name| public_send(name) }.stringify_keys
  end
end
