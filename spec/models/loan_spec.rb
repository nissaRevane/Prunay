require "rails_helper"

RSpec.describe Loan do
  subject(:loan) do
    described_class.new(capital: 193_224, annual_rate: 3, duration_years: 20, insurance: 0,
                        signed_on: Date.new(2025, 1, 15))
  end

  describe "#first_payment_on" do
    def signed_on(date)
      described_class.new(capital: 193_224, annual_rate: 3, duration_years: 20, insurance: 0, signed_on: date)
    end

    it "starts repaying on the fifth that follows the signature" do
      expect(signed_on(Date.new(2025, 3, 10)).first_payment_on).to eq(Date.new(2025, 4, 5))
      expect(signed_on(Date.new(2025, 3, 31)).first_payment_on).to eq(Date.new(2025, 4, 5))
      expect(signed_on(Date.new(2025, 3, 2)).first_payment_on).to eq(Date.new(2025, 3, 5))
      expect(signed_on(Date.new(2025, 3, 5)).first_payment_on).to eq(Date.new(2025, 3, 5))
    end

    it "rolls over the year when the purchase is signed late in December" do
      expect(signed_on(Date.new(2025, 12, 20)).first_payment_on).to eq(Date.new(2026, 1, 5))
    end
  end

  describe "#duration_months" do
    it "counts twelve payments a year" do
      expect(loan.duration_months).to eq(240)
    end
  end

  describe "what the credit takes" do
    it "reads the payment off its schedule" do
      expect(loan.monthly_payment).to eq(BigDecimal("1071.62"))
      expect(loan.annual_payment).to eq(BigDecimal("1071.62") * 12)
    end

    it "adds the insurance premium to what the credit takes each month" do
      insured = described_class.new(capital: 193_224, annual_rate: 3, duration_years: 20,
                                    insurance: BigDecimal("19.32"), signed_on: Date.new(2025, 1, 15))

      expect(insured.monthly_payment).to eq(BigDecimal("1071.62"))
      expect(insured.total_monthly_payment).to eq(BigDecimal("1090.94"))
      expect(insured.annual_payment).to eq(BigDecimal("1090.94") * 12)
    end

    it "counts the insurance in what the credit costs, next to its interest" do
      insured = described_class.new(capital: 193_224, annual_rate: 3, duration_years: 20,
                                    insurance: BigDecimal("19.32"), signed_on: Date.new(2025, 1, 15))

      expect(insured.total_insurance).to eq(BigDecimal("19.32") * 240)
      expect(insured.total_cost).to eq(insured.total_interest + insured.total_insurance)
    end

    it "counts the fees the signature costs without touching what it takes each month" do
      with_fees = described_class.new(capital: 193_224, annual_rate: 3, duration_years: 20, insurance: 0,
                                      guarantee_fees: 3_220, application_fees: 1_932,
                                      signed_on: Date.new(2025, 1, 15))

      expect(with_fees.upfront_fees).to eq(5_152)
      expect(with_fees.monthly_payment).to eq(BigDecimal("1071.62"))
      expect(with_fees.total_cost).to eq(with_fees.total_interest + 5_152)
    end
  end

  describe "a loan with nothing to amortize" do
    subject(:loan) do
      described_class.new(capital: 0, annual_rate: 0, duration_years: 0, insurance: 0,
                          guarantee_fees: 500, application_fees: 500, signed_on: nil)
    end

    it "has no schedule and takes nothing" do
      expect(loan).not_to be_amortizable
      expect(loan.schedule).to be_nil
      expect(loan.monthly_payment).to eq(0)
      expect(loan.annual_payment).to eq(0)
      expect(loan.upfront_fees).to eq(0)
      expect(loan.total_cost).to eq(0)
      expect(loan.annual_payments).to eq({})
    end
  end

  describe ".default_insurance" do
    it "reads a premium on the capital borrowed" do
      expect(described_class.default_insurance(BigDecimal("193224"), BigDecimal("0.12"))).to eq(BigDecimal("19.32"))
      expect(described_class.default_insurance(0, BigDecimal("0.12"))).to eq(0)
    end
  end

  describe ".default_guarantee_fees" do
    it "reads the guarantee on the capital borrowed" do
      expect(described_class.default_guarantee_fees(BigDecimal("193224"), BigDecimal("1.667")))
        .to eq(BigDecimal("3221.04"))
      expect(described_class.default_guarantee_fees(0, BigDecimal("1.667"))).to eq(0)
    end
  end

  describe ".default_application_fees" do
    it "reads the fees on the capital borrowed" do
      expect(described_class.default_application_fees(BigDecimal("193224"), 1, 500)).to eq(BigDecimal("1932.24"))
    end

    it "never proposes less than the floor a bank charges" do
      expect(described_class.default_application_fees(BigDecimal("30000"), 1, 500)).to eq(500)
    end

    it "proposes nothing when there is nothing to borrow" do
      expect(described_class.default_application_fees(0, 1, 500)).to eq(0)
    end
  end

  describe "#early_repayment_fee" do
    def loan(rate, early_repayment_fee: true) =
      described_class.new(capital: 100_000, annual_rate: rate, duration_years: 20, insurance: 0,
                          early_repayment_fee: early_repayment_fee, signed_on: Date.new(2025, 1, 15))

    it "caps the indemnity at six months of the interest it saves" do
      expect(loan(3).early_repayment_fee(100_000)).to eq(1_500)
    end

    it "never takes more than 3 % of the capital repaid" do
      expect(loan(9).early_repayment_fee(100_000)).to eq(3_000)
    end

    it "owes nothing once there is no capital left" do
      expect(loan(3).early_repayment_fee(0)).to eq(0)
    end

    it "owes nothing when the indemnity has been waived" do
      expect(loan(3, early_repayment_fee: false).early_repayment_fee(100_000)).to eq(0)
    end
  end
end
