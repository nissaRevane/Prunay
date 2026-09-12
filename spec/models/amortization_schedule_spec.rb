require "rails_helper"

RSpec.describe AmortizationSchedule do
  let(:simulation) { build(:simulation, :with_credit, purchase_date: Date.new(2025, 1, 15)) }
  let(:schedule) { described_class.new(simulation.loan) }

  describe "#monthly_payment" do
    it "is what it takes to clear the capital over the whole duration" do
      expect(schedule.monthly_payment).to eq(BigDecimal("1071.62"))
    end

    it "shares the capital out in equal parts when nothing is charged for it" do
      free = build(:simulation, :with_credit, purchase_price: 100_000, down_payment: 92_808,
                                              loan_rate: 0, loan_duration_years: 1)

      expect(described_class.new(free.loan).monthly_payment).to eq(BigDecimal("1365.33"))
    end
  end

  describe "#rows" do
    it "runs one line per month of the duration" do
      expect(schedule.rows.size).to eq(240)
      expect(schedule.rows.map(&:number)).to eq((1..240).to_a)
    end

    it "falls on the fifth of the month after the purchase, then month by month" do
      expect(schedule.rows.first.due_on).to eq(Date.new(2025, 2, 5))
      expect(schedule.rows.second.due_on).to eq(Date.new(2025, 3, 5))

      month_end = build(:simulation, :with_credit, purchase_date: Date.new(2025, 1, 31))
      expect(described_class.new(month_end.loan).rows.first.due_on).to eq(Date.new(2025, 2, 5))
    end

    it "starts in the month of the purchase itself when the fifth is still ahead" do
      early = build(:simulation, :with_credit, purchase_date: Date.new(2025, 1, 3))
      on_the_day = build(:simulation, :with_credit, purchase_date: Date.new(2025, 1, 5))

      expect(described_class.new(early.loan).rows.first.due_on).to eq(Date.new(2025, 1, 5))
      expect(described_class.new(on_the_day.loan).rows.first.due_on).to eq(Date.new(2025, 1, 5))
    end

    it "splits each payment between the interest the capital owes and the capital itself" do
      first = schedule.rows.first

      expect(first).to have_attributes(interest: BigDecimal("483.06"), principal: BigDecimal("588.56"),
                                       payment: BigDecimal("1071.62"), remaining_capital: BigDecimal("192635.44"))
      expect(schedule.rows.second.interest).to be < first.interest
      expect(schedule.rows.second.principal).to be > first.principal
    end

    it "settles the rounding residue on the last payment and ends at nothing" do
      last = schedule.rows.last

      expect(last.principal).to eq(schedule.rows[-2].remaining_capital)
      expect(last.remaining_capital).to eq(0)
    end
  end

  describe "#annual_payments" do
    it "gathers the payments twelve by twelve" do
      expect(schedule.annual_payments[1]).to eq(BigDecimal("1071.62") * 12)
      expect(schedule.annual_payments.keys).to eq((1..20).to_a)
    end

    it "gives the last year only what is left to pay" do
      expect(schedule.annual_payments[20]).to eq(BigDecimal("12857.95"))
      expect(schedule.annual_payments[21]).to be_nil
    end
  end

  describe "#total_interest" do
    it "is what the credit costs on top of the capital" do
      expect(schedule.total_interest).to eq(BigDecimal("63963.31"))
      expect(schedule.total_payments - schedule.total_interest).to eq(simulation.borrowed_capital)
    end
  end

  describe "the borrower's insurance" do
    let(:insured) do
      build(:simulation, :with_credit, purchase_date: Date.new(2025, 1, 15), loan_insurance: 19.32)
    end

    let(:insured_schedule) { described_class.new(insured.loan) }

    it "adds the same premium to every payment without repaying anything" do
      expect(insured_schedule.rows.first.insurance).to eq(BigDecimal("19.32"))
      expect(insured_schedule.rows.last.insurance).to eq(BigDecimal("19.32"))
      expect(insured_schedule.rows.first.payment).to eq(BigDecimal("1090.94"))
      expect(insured_schedule.monthly_payment).to eq(schedule.monthly_payment)
      expect(insured_schedule.total_monthly_payment).to eq(BigDecimal("1090.94"))
      expect(insured_schedule.rows.map(&:remaining_capital)).to eq(schedule.rows.map(&:remaining_capital))
    end

    it "carries the premium into what each year of the projection pays" do
      expect(insured_schedule.annual_payments[1]).to eq(BigDecimal("1090.94") * 12)
      expect(insured_schedule.annual_payments.keys).to eq((1..20).to_a)
    end

    it "counts the premiums apart from the interest" do
      expect(insured_schedule.total_insurance).to eq(BigDecimal("19.32") * 240)
      expect(insured_schedule.total_interest).to eq(schedule.total_interest)
      expect(insured_schedule.total_payments - insured_schedule.total_interest - insured_schedule.total_insurance)
        .to eq(insured.borrowed_capital)
    end
  end
end
