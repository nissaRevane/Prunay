require "rails_helper"

RSpec.describe Simulation::Preset do
  subject(:simulation) do
    described_class.complete(
      build(:simulation, property_type: "apartment", city: "Nantes", surface: 50,
                         purchase_price: 200_000, monthly_rent: 800)
    )
  end

  it "keeps the five answers given" do
    expect(simulation).to have_attributes(property_type: "apartment", city: "Nantes", surface: 50,
                                          purchase_price: 200_000, monthly_rent: 800)
  end

  it "buys on credit in three months, without works" do
    expect(simulation).to have_attributes(credit: true, initial_works: 0,
                                          purchase_date: Date.current >> 3)
  end

  it "puts a tenth of the project down and borrows the rest" do
    expect(simulation).to have_attributes(down_payment: 21_660, loan_rate: BigDecimal("3.6"),
                                          loan_duration_years: 20)
    expect(simulation.borrowed_capital).to eq(194_952)
  end

  it "reads the loan fees on the capital borrowed" do
    expect(simulation).to have_attributes(loan_insurance: BigDecimal("19.5"),
                                          loan_guarantee_fees: BigDecimal("3249.85"),
                                          loan_application_fees: BigDecimal("1949.52"))
  end

  it "carries the usual charges for the surface" do
    expect(simulation).to have_attributes(property_tax: 700, insurance: 150, maintenance: 1_000,
                                          condominium_fees: 1_000, other_charges: 100,
                                          management_fees: 0, rent_guarantee: 0,
                                          accounting_fees: 500, furniture: 2_110,
                                          furniture_maintenance: 370)
  end

  it "lets the property eleven months a year, charges included in the rent" do
    expect(simulation).to have_attributes(occupancy_months: 11, monthly_charges: 0)
  end

  it "proposes the market rent when none is given: 14,75 €/m² × 30 m² in Orléans, rounded to 443" do
    simulation = described_class.complete(
      build(:simulation, property_type: "apartment", city: "Orléans", surface: 30,
                         purchase_price: 100_000, monthly_rent: nil)
    )

    expect(simulation.monthly_rent).to eq(443)
  end

  it "is complete enough to be saved" do
    expect(simulation).to be_valid
    expect(simulation.save).to be(true)
  end

  describe "a building" do
    def building(surface, monthly_rent: nil)
      described_class.complete(
        build(:simulation, property_type: "building", city: "Nantes", surface: surface,
                           purchase_price: 500_000, monthly_rent: monthly_rent)
      )
    end

    def surfaces(simulation) = simulation.lots.map { |lot| lot["surface"] }

    it "splits under 100 m² into two halves: 70 m² into 2 lots of 35" do
      expect(surfaces(building(70))).to eq(%w[35 35])
    end

    it "splits 100 m² into 2 lots of 50" do
      expect(surfaces(building(100))).to eq(%w[50 50])
    end

    it "cuts lots of 50 m² until less than 100 remain: 380 m² into 6 lots of 50 and one of 80" do
      expect(surfaces(building(380))).to eq(%w[50 50 50 50 50 50 80])
      expect(building(380).surface).to eq(380)
    end

    it "keeps the cents of an odd half: 75,5 m² into 37,75 and 37,75" do
      expect(surfaces(building(BigDecimal("75.5")))).to eq(%w[37.75 37.75])
    end

    it "stops at twenty lots, the last keeping the rest: 1 200 m² into 19 lots of 50 and one of 250" do
      expect(surfaces(building(1_200))).to eq([*Array.new(19, "50"), "250"])
    end

    it "shares the rent typed by surface: 1 900 € on 380 m² is 250 € per 50 m² and 400 € for 80 m²" do
      expect(building(380, monthly_rent: 1_900).lots.map { |lot| lot["monthly_rent"] })
        .to eq(%w[250 250 250 250 250 250 400])
    end

    it "gives the cents left over to the last lot: 1 000 € on 3 × 50 m² is 333,33 + 333,33 + 333,34" do
      expect(building(150, monthly_rent: 1_000).lots.map { |lot| lot["monthly_rent"] })
        .to eq(%w[333.33 333.33 333.34])
    end

    it "proposes each lot its own rent when none is given: 650 × √(35/50) rounded to 540, twice" do
      simulation = building(70)

      expect(simulation.lots.map { |lot| lot["monthly_rent"] }).to eq(%w[540 540])
      expect(simulation.monthly_rent).to eq(1_080)
    end

    it "lets each lot eleven months a year, charges included in the rent" do
      expect(building(70).lots).to all(include("monthly_charges" => "0", "occupancy_months" => "11"))
    end

    it "is complete enough to be saved" do
      simulation = building(380, monthly_rent: 1_900)

      expect(simulation.save).to be(true)
      expect(simulation.reload).to have_attributes(surface: 380, monthly_rent: 1_900, occupancy_months: 11)
    end
  end

  it "leaves any other property whole" do
    expect(simulation.lots).to eq([])
  end
end
