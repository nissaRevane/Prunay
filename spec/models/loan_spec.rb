require "rails_helper"

RSpec.describe Loan do
  # 193 224 € empruntés sur vingt ans à 3 %, signés le 15 janvier 2025.
  subject(:loan) do
    described_class.new(capital: 193_224, annual_rate: 3, duration_years: 20, insurance: 0,
                        signed_on: Date.new(2025, 1, 15))
  end

  describe "#first_payment_on" do
    def signed_on(date)
      described_class.new(capital: 193_224, annual_rate: 3, duration_years: 20, insurance: 0, signed_on: date)
    end

    # Le remboursement commence le 5 : celui du mois de l'acte quand il est signé du 1er au
    # 5, celui du mois suivant sinon.
    it "starts repaying on the fifth that follows the signature" do
      expect(signed_on(Date.new(2025, 3, 10)).first_payment_on).to eq(Date.new(2025, 4, 5))
      expect(signed_on(Date.new(2025, 3, 31)).first_payment_on).to eq(Date.new(2025, 4, 5))
      expect(signed_on(Date.new(2025, 3, 2)).first_payment_on).to eq(Date.new(2025, 3, 5))
      expect(signed_on(Date.new(2025, 3, 5)).first_payment_on).to eq(Date.new(2025, 3, 5))
    end

    # Un acte signé en décembre après le 5 rembourse en janvier de l'année suivante.
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

    # L'assurance ne rembourse rien : sa prime s'ajoute à la mensualité, et l'annuité que la
    # projection retranche la porte douze fois.
    it "adds the insurance premium to what the credit takes each month" do
      insured = described_class.new(capital: 193_224, annual_rate: 3, duration_years: 20,
                                    insurance: BigDecimal("19.32"), signed_on: Date.new(2025, 1, 15))

      expect(insured.monthly_payment).to eq(BigDecimal("1071.62"))
      expect(insured.total_monthly_payment).to eq(BigDecimal("1090.94"))
      expect(insured.annual_payment).to eq(BigDecimal("1090.94") * 12)
    end

    # Les intérêts et l'assurance se lisent séparément — l'un est le prix du capital, l'autre
    # celui de la garantie —, et le coût du crédit les additionne.
    it "counts the insurance in what the credit costs, next to its interest" do
      insured = described_class.new(capital: 193_224, annual_rate: 3, duration_years: 20,
                                    insurance: BigDecimal("19.32"), signed_on: Date.new(2025, 1, 15))

      expect(insured.total_insurance).to eq(BigDecimal("19.32") * 240)
      expect(insured.total_cost).to eq(insured.total_interest + insured.total_insurance)
    end

    # Le cautionnement et les frais de dossier se paient une fois, à la signature : ils ne
    # touchent ni la mensualité ni les intérêts, et le coût du crédit les porte tels quels.
    it "counts the fees the signature costs without touching what it takes each month" do
      with_fees = described_class.new(capital: 193_224, annual_rate: 3, duration_years: 20, insurance: 0,
                                      guarantee_fees: 3_220, application_fees: 1_932,
                                      signed_on: Date.new(2025, 1, 15))

      expect(with_fees.upfront_fees).to eq(5_152)
      expect(with_fees.monthly_payment).to eq(BigDecimal("1071.62"))
      expect(with_fees.total_cost).to eq(with_fees.total_interest + 5_152)
    end
  end

  # Un crédit sans capital, sans durée ou sans signature n'a pas de tableau à produire, et ne
  # prélève donc rien : c'est l'état d'un achat comptant.
  describe "a loan with nothing to amortize" do
    subject(:loan) do
      described_class.new(capital: 0, annual_rate: 0, duration_years: 0, insurance: 0,
                          guarantee_fees: 500, application_fees: 500, signed_on: nil)
    end

    # Les frais eux-mêmes ne se prêtent pas à un crédit qui n'existe pas : un achat comptant
    # peut porter des colonnes qu'une case décochée n'a pas encore remises à zéro.
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
    # Un dix-millième des 193 224 € empruntés fait 19,32 € par mois.
    it "reads a premium on the capital borrowed" do
      expect(described_class.default_insurance(BigDecimal("193224"))).to eq(BigDecimal("19.32"))
      expect(described_class.default_insurance(0)).to eq(0)
    end
  end

  describe ".default_guarantee_fees" do
    # Un soixantième des 193 224 € empruntés fait 3 220,40 €.
    it "reads the guarantee on the capital borrowed" do
      expect(described_class.default_guarantee_fees(BigDecimal("193224"))).to eq(BigDecimal("3220.4"))
      expect(described_class.default_guarantee_fees(0)).to eq(0)
    end
  end

  describe ".default_application_fees" do
    # Un centième des 193 224 € empruntés fait 1 932,24 €.
    it "reads the fees on the capital borrowed" do
      expect(described_class.default_application_fees(BigDecimal("193224"))).to eq(BigDecimal("1932.24"))
    end

    # Un centième d'un petit emprunt passerait sous le plancher : la banque le facture quand même.
    it "never proposes less than the floor a bank charges" do
      expect(described_class.default_application_fees(BigDecimal("30000"))).to eq(500)
    end

    # Un brouillon qui n'emprunte encore rien n'a pas de dossier à faire instruire.
    it "proposes nothing when there is nothing to borrow" do
      expect(described_class.default_application_fees(0)).to eq(0)
    end
  end
end
