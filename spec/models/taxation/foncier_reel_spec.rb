require "rails_helper"

# Le foncier réel n'a pas de forfait : l'assiette est ce que le loyer laisse une fois les
# charges réelles et les intérêts d'emprunt déduits, et le reste se lève dessus comme ailleurs.
RSpec.describe Taxation::FoncierReel do
  subject(:taxation) do
    described_class.new(rent_excluding_charges: 12_000, marginal_tax_rate: 30, charges: 2_000,
                        loan_interest: 4_000)
  end

  describe "#taxable_income" do
    it "is what the real charges and the loan interest leave of the rent" do
      expect(taxation.taxable_income).to eq(6_000)
    end
  end

  # 6 000 € imposables : 30 % de barème, et 17,2 % de prélèvements sociaux par-dessus.
  describe "the two levies" do
    it "applies the bracket of the household to what is taxable" do
      expect(taxation.income_tax).to eq(1_800)
    end

    it "adds the social charges, which no bracket governs" do
      expect(taxation.social_charges).to eq(1_032)
    end

    it "asks for both at once" do
      expect(taxation.total).to eq(2_832)
    end
  end

  # Un déficit foncier ne se reporte pas ici : l'année qui n'a rien gagné ne doit rien, et
  # rien ne passe à la suivante.
  it "asks nothing of a year its charges and its interest have swallowed" do
    deficit = described_class.new(rent_excluding_charges: 9_600, marginal_tax_rate: 45, charges: 5_000,
                                  loan_interest: 6_000)

    expect(deficit.taxable_income).to eq(0)
    expect(deficit.total).to eq(0)
  end

  # Un achat comptant et sans charges : il ne reste que le loyer, et tout est imposable.
  it "supposes neither charges nor interest when none are named" do
    bare = described_class.new(rent_excluding_charges: 12_000, marginal_tax_rate: 0)

    expect(bare.taxable_income).to eq(12_000)
    expect(bare.total).to eq(BigDecimal("2064"))
  end

  # `to_d` comme dans Loan : un taux entier ferait une division entière, et l'impôt tomberait à zéro.
  it "reads an integer bracket as a rate and not as a division" do
    expect(described_class.new(rent_excluding_charges: 10_000, marginal_tax_rate: 45).income_tax).to eq(4_500)
  end
end
