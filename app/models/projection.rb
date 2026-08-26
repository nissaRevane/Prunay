# La projection d'un investissement locatif sur trente ans, une ligne par anniversaire de
# l'achat. La première ligne est le premier anniversaire et non le jour de l'achat : elle
# porte les loyers des douze mois écoulés.
class Projection
  HORIZON_YEARS = 30

  # +loan_payments+ est ce que le crédit prélève cette année-là ; +immobilized_capital+ est cumulatif.
  Year = Struct.new(:number, :date, :annual_rent, :annual_charges, :loan_payments, :cash_flow,
                    :immobilized_capital, keyword_init: true) do
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

  def total_rent
    @simulation.annual_rent * HORIZON_YEARS
  end

  def total_charges
    @simulation.annual_charges * HORIZON_YEARS
  end

  # Le cumul ne se multiplie plus : un crédit qui s'éteint rend les années inégales entre elles.
  def total_cash_flow
    years.sum(&:cash_flow)
  end

  # Ce qui reste immobilisé au bout de l'horizon. Négatif, l'investissement est récupéré.
  def final_immobilized_capital
    years.last.immobilized_capital
  end

  private

  def build_years
    rent = @simulation.annual_rent
    charges = @simulation.annual_charges
    outlay = @simulation.initial_outlay
    payments = @simulation.loan.annual_payments
    cumulative_cash_flow = 0

    (1..HORIZON_YEARS).map do |number|
      due = payments.fetch(number, 0)
      cash_flow = rent - charges - due
      cumulative_cash_flow += cash_flow

      Year.new(
        number: number,
        date: @simulation.purchase_date + number.years,
        annual_rent: rent,
        annual_charges: charges,
        loan_payments: due,
        cash_flow: cash_flow,
        immobilized_capital: outlay - cumulative_cash_flow
      )
    end
  end
end
