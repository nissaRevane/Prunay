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

  it "is complete enough to be saved" do
    expect(simulation).to be_valid
    expect(simulation.save).to be(true)
  end
end
