# La projection d'un investissement locatif sur trente ans, une ligne par anniversaire de
# l'achat, précédée de l'année zéro : le jour de la signature, où rien n'a encore été encaissé
# et où le capital vient tout juste d'être immobilisé. Les anniversaires qui suivent portent
# chacun les loyers des douze mois écoulés, composés par les conditions économiques, et
# l'impôt que ces loyers-là valent au foyer (voir Taxation).
class Projection
  HORIZON_YEARS = 30

  # +loan_payments+ est ce que le crédit prélève cette année-là, +taxes+ ce que l'impôt et les
  # prélèvements sociaux prennent des loyers de l'année ; +immobilized_capital+ est cumulatif,
  # et +property_value+ est ce que le bien vaut à cette date-là.
  Year = Struct.new(:number, :date, :annual_rent, :annual_charges, :loan_payments, :taxes, :cash_flow,
                    :immobilized_capital, :property_value, keyword_init: true) do
    def recovered?
      immobilized_capital <= 0
    end
  end

  def initialize(simulation)
    @simulation = simulation
  end

  def years
    @years ||= build_years
  end

  # Les loyers ne se multiplient plus : ils progressent d'une année sur l'autre.
  def total_rent
    years.sum(&:annual_rent)
  end

  def total_charges
    years.sum(&:annual_charges)
  end

  def total_taxes
    years.sum(&:taxes)
  end

  # Le cumul ne se multiplie plus : un crédit qui s'éteint rend les années inégales entre elles.
  def total_cash_flow
    years.sum(&:cash_flow)
  end

  # Ce qui reste immobilisé au bout de l'horizon. Négatif, l'investissement est récupéré.
  def final_immobilized_capital
    years.last.immobilized_capital
  end

  # Ce que le bien vaut au bout de l'horizon, l'évolution des prix appliquée année par année.
  def final_property_value
    years.last.property_value
  end

  private

  # La première année pleine porte les montants tels qu'ils ont été saisis : ils décrivent les
  # douze mois qui suivent l'achat. Le prix du bien, lui, a déjà pris une année au premier
  # anniversaire — c'est une valeur à une date, non un montant encaissé sur une période.
  def build_years
    outlay = @simulation.initial_outlay
    payments = @simulation.loan.annual_payments
    cumulative_cash_flow = 0

    [origin_year] + (1..HORIZON_YEARS).map do |number|
      rent = compound(@simulation.annual_rent, @simulation.rent_growth_rate, number - 1)
      charges = compound(@simulation.annual_charges, @simulation.inflation_rate, number - 1)
      due = payments.fetch(number, 0)
      # L'assiette suit le loyer hors charges de cette année-là, et non les loyers encaissés :
      # la provision pour charges n'est pas un revenu, elle rembourse une dépense.
      taxes = @simulation.taxation(compound(@simulation.annual_rent_excluding_charges,
                                            @simulation.rent_growth_rate, number - 1)).total
      cash_flow = rent - charges - taxes - due
      cumulative_cash_flow += cash_flow

      Year.new(
        number: number,
        date: @simulation.purchase_date + number.years,
        annual_rent: rent,
        annual_charges: charges,
        loan_payments: due,
        taxes: taxes,
        cash_flow: cash_flow,
        immobilized_capital: outlay - cumulative_cash_flow,
        property_value: compound(@simulation.purchase_price, @simulation.property_growth_rate, number)
      )
    end
  end

  # Le jour de l'achat : aucun loyer, aucune charge, aucune échéance — rien n'a encore couru.
  # La ligne est là pour ce qu'elle seule montre, le capital immobilisé d'où part le reste du
  # tableau, et pour le prix payé avant que le marché n'y touche.
  def origin_year
    Year.new(
      number: 0,
      date: @simulation.purchase_date,
      annual_rent: 0,
      annual_charges: 0,
      loan_payments: 0,
      taxes: 0,
      cash_flow: 0,
      immobilized_capital: @simulation.initial_outlay,
      property_value: @simulation.purchase_price
    )
  end

  # `to_d` comme dans Loan : un taux qu'un formulaire invalide vient de vider se lit comme une
  # absence d'évolution, le temps que la page se réaffiche avec son erreur.
  def compound(amount, annual_rate, years)
    (amount.to_d * (1 + annual_rate.to_d / 100)**years).round(2)
  end
end
