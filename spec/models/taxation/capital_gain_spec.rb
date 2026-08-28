require "rails_helper"

# Le régime des particuliers tient en trois temps : la valeur fiscale du bien, l'abattement que
# la durée de détention lui vaut, puis 19 % de barème et 17,2 % de prélèvements sociaux.
RSpec.describe Taxation::CapitalGain do
  # Les frais de notaire d'un bien à 200 000 € : 16 612 €, comme partout ailleurs.
  def gain(sale_price:, held_years:)
    described_class.new(sale_price: sale_price, purchase_price: 200_000,
                        acquisition_fees: 16_612, held_years: held_years)
  end

  # La valeur fiscale n'est jamais le seul prix payé : les frais d'acquisition s'y ajoutent, et
  # passé cinq ans de détention, 15 % de travaux forfaitaires que rien n'oblige à justifier.
  describe "#fiscal_value" do
    it "adds the acquisition fees to the price paid" do
      expect(gain(sale_price: 250_000, held_years: 3).fiscal_value).to eq(216_612)
    end

    it "still knows nothing of the flat works on the fifth anniversary" do
      expect(gain(sale_price: 250_000, held_years: 5).assumed_works).to eq(0)
      expect(gain(sale_price: 250_000, held_years: 5).fiscal_value).to eq(216_612)
    end

    it "adds 15 per cent of the price paid once the sixth year is reached" do
      expect(gain(sale_price: 250_000, held_years: 6).assumed_works).to eq(30_000)
      expect(gain(sale_price: 250_000, held_years: 6).fiscal_value).to eq(246_612)
    end
  end

  describe "#amount" do
    it "is what the sale gets above the fiscal value" do
      expect(gain(sale_price: 250_000, held_years: 3).amount).to eq(33_388)
    end

    # Une moins-value ne se reporte ni ne se déduit : elle ne doit rien, et c'est tout.
    it "owes nothing when the property is sold for less than it is worth to the taxman" do
      sold_at_a_loss = gain(sale_price: 210_000, held_years: 3)

      expect(sold_at_a_loss.amount).to eq(0)
      expect(sold_at_a_loss.total).to eq(0)
    end
  end

  # 33 388 € de plus-value revendus au bout de trois ans : rien n'est encore abattu.
  describe "the two levies, before any allowance" do
    subject(:early_sale) { gain(sale_price: 250_000, held_years: 3) }

    it "applies the 19 per cent of the capital gain, which no bracket governs" do
      expect(early_sale.income_tax).to eq(BigDecimal("6343.72"))
    end

    it "adds the 17.2 per cent of social charges" do
      expect(early_sale.social_charges).to eq(BigDecimal("5742.74"))
    end

    it "asks for both at once" do
      expect(early_sale.total).to eq(BigDecimal("12086.46"))
    end
  end

  # Les deux abattements ne courent pas au même rythme : cinq années au-delà de la cinquième
  # valent 30 % au barème (6 % l'an) et 8,25 % aux prélèvements sociaux (1,65 % l'an). Sur les
  # 53 388 € que laisse une valeur fiscale déjà majorée des travaux forfaitaires.
  describe "the allowance for the years held" do
    subject(:tenth_year) { gain(sale_price: 300_000, held_years: 10) }

    it "abates each levy at its own pace" do
      expect(tenth_year.income_tax_allowance_rate).to eq(30)
      expect(tenth_year.social_charges_allowance_rate).to eq(BigDecimal("8.25"))
    end

    it "taxes what the allowance leaves of the gain" do
      expect(tenth_year.amount).to eq(53_388)
      expect(tenth_year.income_tax).to eq(BigDecimal("7100.60"))
      expect(tenth_year.social_charges).to eq(BigDecimal("8425.16"))
      expect(tenth_year.total).to eq(BigDecimal("15525.76"))
    end

    it "abates nothing during the first five years" do
      expect(gain(sale_price: 250_000, held_years: 5).income_tax_allowance_rate).to eq(0)
      expect(gain(sale_price: 250_000, held_years: 5).social_charges_allowance_rate).to eq(0)
    end

    # Vingt-deux ans : 6 % pendant seize ans puis 4 % la dernière, et le barème n'a plus rien à
    # prendre. Les prélèvements sociaux, eux, n'en sont qu'à 28 %.
    it "frees the gain from the income tax after twenty-two years, the social charges apart" do
      sale = gain(sale_price: 300_000, held_years: 22)

      expect(sale.income_tax_allowance_rate).to eq(100)
      expect(sale.income_tax).to eq(0)
      expect(sale.social_charges_allowance_rate).to eq(28)
      expect(sale.social_charges).to eq(BigDecimal("6611.57"))
    end

    # Trente ans : 9 % l'an à partir de la vingt-troisième achèvent les prélèvements sociaux.
    it "frees the gain from the social charges after thirty years, and owes nothing at all" do
      sale = gain(sale_price: 300_000, held_years: 30)

      expect(sale.social_charges_allowance_rate).to eq(100)
      expect(sale.total).to eq(0)
    end
  end

  # `to_d` comme dans Loan : un prix entier ferait une division entière, et l'impôt tomberait
  # à zéro comme les 15 % de travaux forfaitaires.
  it "reads an integer price as a decimal and not as a division" do
    entire = described_class.new(sale_price: 250_000, purchase_price: 200_000, acquisition_fees: 0, held_years: 3)

    expect(entire.amount).to eq(50_000)
    expect(entire.income_tax).to eq(9_500)
  end
end
