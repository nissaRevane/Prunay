require "rails_helper"

RSpec.describe Simulation::BestReturn do
  subject(:best) { simulation.best_return }

  let(:simulation) do
    create(:simulation, purchase_price: 200_000, monthly_rent: 800, purchase_date: Date.new(2025, 1, 15))
  end

  it "keeps the highest rate of every regime and every resale year" do
    expect(best.rate).to eq(BigDecimal("4.0"))
    expect(best.regime).to eq(:lmnp)
    expect(best.year).to eq(30)
    expect(best.date).to eq(Date.new(2055, 1, 15))
  end

  it "finds what scanning every rate would have found" do
    every_rate = Taxation::NAMES.flat_map do |name|
      projection = simulation.projection(name)

      projection.years.filter_map { |year| projection.internal_rate_of_return(year) }
    end

    expect(best.rate).to eq(every_rate.max)
  end

  it "reads the outlay and the first full year under the winning regime" do
    expect(best.initial_outlay).to eq(216_612)
    expect(best.monthly_cash_flow).to eq(BigDecimal("755.85"))
  end

  describe "the cache it keeps" do
    before { allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new) }

    it "reads its figures again without building a single projection" do
      described_class.new(simulation).rate

      expect(simulation).not_to receive(:projection)
      expect(described_class.new(simulation).rate).to eq(BigDecimal("4.0"))
    end

    it "scans again once a figure of the simulation changed" do
      described_class.new(simulation).rate
      simulation.update!(monthly_rent: 1_200)

      expect(described_class.new(simulation).rate).to eq(BigDecimal("6.1"))
    end
  end
end
