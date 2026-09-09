require "rails_helper"

RSpec.describe Simulation::BestReturn do
  subject(:best) { simulation.best_return }

  let(:simulation) do
    create(:simulation, purchase_price: 200_000, monthly_rent: 800, purchase_date: Date.new(2025, 1, 15))
  end

  # 4,04 % au LMNP, contre 3,96 au micro-BIC, 3,75 au micro-foncier et 3,51 au foncier réel.
  it "keeps the highest rate of every regime and every resale year" do
    expect(best.rate).to eq(BigDecimal("4.04"))
    expect(best.regime).to eq(:lmnp)
    expect(best.year.number).to eq(30)
  end

  it "reads the outlay and the first full year under the winning regime" do
    expect(best.initial_outlay).to eq(216_612)
    expect(best.monthly_cash_flow).to eq(BigDecimal("755.85"))
  end
end
