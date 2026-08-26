require "rails_helper"

RSpec.describe Projection do
  subject(:projection) { described_class.new(simulation) }

  let(:simulation) do
    build(:simulation, purchase_date: Date.new(2025, 3, 10), purchase_price: 200_000, initial_works: 20_000,
                       monthly_rent: 1_000, occupancy_months: 11,
                       property_tax: 700, maintenance: 1_000, insurance: 150, other_charges: 150)
  end

  it "runs over the whole horizon, one line per year" do
    expect(projection.years.size).to eq(described_class::HORIZON_YEARS)
    expect(projection.years.map(&:number)).to eq((1..30).to_a)
  end

  # La première ligne est le premier anniversaire, pas le jour de l'achat : elle porte les
  # loyers des douze mois écoulés, et une ligne à zéro le jour de la signature n'en dirait rien.
  it "dates each line on an anniversary of the purchase" do
    expect(projection.years.first.date).to eq(Date.new(2026, 3, 10))
    expect(projection.years.second.date).to eq(Date.new(2027, 3, 10))
    expect(projection.years.last.date).to eq(Date.new(2055, 3, 10))
  end

  it "collects the same rent and pays the same charges on every line" do
    expect(projection.years.map(&:annual_rent).uniq).to eq([11_000])
    expect(projection.years.map(&:annual_charges).uniq).to eq([2_000])
  end

  it "is the rent less the charges as long as there is no loan" do
    expect(projection.years.map(&:cash_flow).uniq).to eq([9_000])
  end

  # Les frais de notaire et les travaux initiaux s'immobilisent avec le prix : ils sont
  # engagés avant le premier loyer, et c'est de leur somme que les cash-flows se déduisent.
  it "deducts the cash flows accumulated since the purchase from the price, the fees and the works" do
    expect(projection.years.first.immobilized_capital).to eq(236_612 - 9_000)
    expect(projection.years.second.immobilized_capital).to eq(236_612 - 18_000)
    expect(projection.years.last.immobilized_capital).to eq(236_612 - 270_000)
  end

  it "marks a line as recovered once the capital has come back" do
    recovered = projection.years.select(&:recovered?)

    expect(recovered.first.number).to eq(27)
    expect(projection.years.take(26).map(&:recovered?)).to all(be(false))
  end

  # Le crédit pèse sur chaque année tant qu'il court, et cesse de peser le jour où il est
  # soldé : une projection de trente ans porte vingt annuités d'un prêt de vingt ans.
  describe "of a purchase financed by a credit" do
    subject(:projection) { described_class.new(simulation) }

    let(:simulation) do
      build(:simulation, :with_credit, purchase_price: 200_000, initial_works: 0, down_payment: 23_388,
                                       monthly_rent: 800, occupancy_months: 12)
    end

    it "deducts the annuity from the cash flow for as long as the loan runs" do
      expect(projection.years.first.loan_payments).to eq(BigDecimal("1071.62") * 12)
      expect(projection.years.first.cash_flow).to eq(9_600 - BigDecimal("1071.62") * 12)
    end

    it "stops deducting anything once the loan is cleared" do
      expect(projection.years[19].loan_payments).to be_positive
      expect(projection.years[20].loan_payments).to eq(0)
      expect(projection.years[20].cash_flow).to eq(9_600)
    end

    # L'apport seul est immobilisé le premier jour, et les annuités le creusent avant que les
    # loyers ne le comblent.
    it "starts from the down payment and not from the whole project" do
      expect(projection.years.first.immobilized_capital).to eq(23_388 - projection.years.first.cash_flow)
    end
  end

  it "keeps a 29 February purchase on a real date" do
    leap = described_class.new(build(:simulation, purchase_date: Date.new(2024, 2, 29)))

    expect(leap.years.first.date).to eq(Date.new(2025, 2, 28))
  end

  describe "#final_immobilized_capital" do
    it "is what the last line shows" do
      expect(projection.final_immobilized_capital).to eq(projection.years.last.immobilized_capital)
    end
  end

  # Le cumul se lit sur les lignes et ne se multiplie plus : un crédit qui s'éteint avant
  # l'horizon rend les années inégales entre elles.
  describe "#total_cash_flow" do
    it "adds up every line" do
      expect(projection.total_cash_flow).to eq(9_000 * 30)
    end
  end
end
