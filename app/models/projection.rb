# La projection d'un investissement locatif sur trente ans, une ligne par anniversaire de
# l'achat, précédée de l'année zéro : le jour de la signature, où rien n'a encore été encaissé
# et où le capital vient tout juste d'être immobilisé. Les anniversaires qui suivent portent
# chacun les loyers des douze mois écoulés, composés par les conditions économiques, et
# l'impôt que ces loyers-là valent au foyer, dans le régime qu'on lui donne (voir Taxation).
class Projection
  HORIZON_YEARS = 30

  # Le compte de résultat d'une année, tenu comme il se déclare : le loyer hors charges d'un
  # côté, de l'autre les charges dont la provision remboursée est ôtée — la provision n'est pas
  # un revenu, et les dépenses qu'elle couvre ne se déduisent pas davantage. Le solde, lui, est
  # celui des montants bruts : ce que l'on retire d'un côté, on ne le compte pas de l'autre.
  Year = Struct.new(:number, :date, :rent_excluding_charges, :charges_excluding_provision,
                    :provision_for_charges, :loan_interest, :capital_repayment, :taxes,
                    :immobilized_capital, :property_value, keyword_init: true) do
    # Les intérêts sont une charge ; le capital rendu, non — il ne passe qu'au cash-flow.
    def pre_tax_result
      rent_excluding_charges - charges_excluding_provision - loan_interest
    end

    def net_result
      pre_tax_result - taxes
    end

    def cash_flow
      net_result - capital_repayment
    end

    # Ce que le crédit prélève en tout : c'est l'annuité que la banque appelle.
    def loan_payments
      loan_interest + capital_repayment
    end

    def recovered?
      immobilized_capital <= 0
    end
  end

  attr_reader :regime

  def initialize(simulation, regime)
    @simulation = simulation
    @regime = regime
  end

  def years
    @years ||= build_years
  end

  # Les loyers ne se multiplient plus : ils progressent d'une année sur l'autre.
  def total_rent
    years.sum(&:rent_excluding_charges)
  end

  def total_charges
    years.sum(&:charges_excluding_provision)
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
  # anniversaire — c'est une valeur à une date, non un montant encaissé sur une période. La
  # provision suit l'inflation et non les loyers : elle rembourse des dépenses, et se régularise
  # sur elles.
  def build_years
    outlay = @simulation.initial_outlay
    interest = @simulation.loan.annual_interest
    principal = @simulation.loan.annual_principal
    cumulative_cash_flow = 0

    [origin_year] + (1..HORIZON_YEARS).map do |number|
      rent = compound(@simulation.annual_rent_excluding_charges, @simulation.rent_growth_rate, number - 1)
      charges = compound(@simulation.annual_charges_excluding_provision, @simulation.inflation_rate, number - 1)
      loan_interest = interest.fetch(number, 0)

      year = Year.new(
        number: number,
        date: @simulation.purchase_date + number.years,
        rent_excluding_charges: rent,
        charges_excluding_provision: charges,
        provision_for_charges: compound(@simulation.annual_provision_for_charges,
                                        @simulation.inflation_rate, number - 1),
        loan_interest: loan_interest,
        capital_repayment: principal.fetch(number, 0),
        taxes: taxes_for(rent, charges, loan_interest),
        property_value: compound(@simulation.purchase_price, @simulation.property_growth_rate, number)
      )
      cumulative_cash_flow += year.cash_flow
      year.immobilized_capital = outlay - cumulative_cash_flow

      year
    end
  end

  # L'assiette ne se compose pas ici : l'année porte déjà les montants qui se déclarent.
  def taxes_for(rent, charges, loan_interest)
    @simulation.taxation(regime, rent_excluding_charges: rent, charges: charges,
                                 loan_interest: loan_interest).total
  end

  # Le jour de l'achat : aucun loyer, aucune charge, aucune échéance — rien n'a encore couru.
  # La ligne est là pour ce qu'elle seule montre, le capital immobilisé d'où part le reste du
  # tableau, et pour le prix payé avant que le marché n'y touche.
  def origin_year
    Year.new(
      number: 0,
      date: @simulation.purchase_date,
      rent_excluding_charges: 0,
      charges_excluding_provision: 0,
      provision_for_charges: 0,
      loan_interest: 0,
      capital_repayment: 0,
      taxes: 0,
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
