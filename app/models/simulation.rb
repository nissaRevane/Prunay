class Simulation < ApplicationRecord
  # Un investissement locatif projeté sur trente ans.
  #
  # Le modèle est volontairement pauvre : un prix, une date d'achat, un loyer. Ni prêt, ni
  # charges, ni fiscalité — ils viendront, et chacun ajoutera une colonne à la projection
  # sans en changer la forme.
  HORIZON_YEARS = 30

  MONTHS_PER_YEAR = 12

  # Une année de la projection, telle que le tableau la lit.
  #
  # +immobilized_capital+ est cumulatif : c'est ce qui reste engagé après avoir déduit du prix
  # d'achat tous les cash-flows encaissés depuis l'achat, et non le seul cash-flow de l'année.
  # Il décroît donc d'année en année, et passe sous zéro l'année où l'investissement est
  # récupéré — un capital immobilisé recalculé à chaque ligne sur le seul cash-flow annuel
  # rendrait trente fois le même montant.
  Year = Struct.new(:number, :date, :annual_rent, :cash_flow, :immobilized_capital, keyword_init: true) do
    def recovered?
      immobilized_capital <= 0
    end
  end

  belongs_to :user

  validates :purchase_date, presence: true
  validates :purchase_price, presence: true, numericality: { greater_than: 0 }
  validates :monthly_rent, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Les loyers d'une année pleine. Le loyer est saisi au mois — c'est ainsi qu'un bail
  # l'énonce — et la projection ne raisonne qu'en années.
  def annual_rent
    monthly_rent * MONTHS_PER_YEAR
  end

  # Le cash-flow d'une année : les entrées moins les sorties. Tant qu'il n'y a ni prêt ni
  # charges, il n'y a que les loyers — la méthode existe pour que les sorties futures aient
  # un seul endroit où se soustraire.
  def annual_cash_flow
    annual_rent
  end

  # La projection, une ligne par anniversaire de l'achat. La première ligne est le premier
  # anniversaire, pas le jour de l'achat : elle porte les loyers des douze mois écoulés.
  def projection
    cumulative_cash_flow = 0

    (1..HORIZON_YEARS).map do |number|
      cumulative_cash_flow += annual_cash_flow

      Year.new(
        number: number,
        date: purchase_date >> (number * MONTHS_PER_YEAR),
        annual_rent: annual_rent,
        cash_flow: annual_cash_flow,
        immobilized_capital: purchase_price - cumulative_cash_flow
      )
    end
  end

  # Le chiffre que la liste met en avant : ce qui reste immobilisé au bout de l'horizon.
  # Négatif, l'investissement est récupéré et a rapporté au-delà.
  def final_immobilized_capital
    purchase_price - total_cash_flow
  end

  def total_rent
    annual_rent * HORIZON_YEARS
  end

  def total_cash_flow
    annual_cash_flow * HORIZON_YEARS
  end
end
