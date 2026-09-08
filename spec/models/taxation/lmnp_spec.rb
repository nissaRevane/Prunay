require "rails_helper"

# Le LMNP est un BIC déclaré au réel : les recettes du meublé, provision comprise, mais aucun
# forfait — charges, CFE, comptable et intérêts déduits, et l'amortissement du bâti par-dessus,
# qui ne coûte rien et qu'aucune trésorerie ne paie.
RSpec.describe Taxation::Lmnp do
  subject(:taxation) { described_class.new(**attributes) }

  # 200 000 € de prix, 80 % de bâti, vingt-cinq ans : 6 400 € par an.
  describe "#depreciation" do
    it "spreads the built share of the price over the years of the plan" do
      expect(taxation.depreciation).to eq(6_400)
      expect(described_class::DEPRECIATED_SHARE).to eq(BigDecimal("0.80"))
      expect(described_class::DEPRECIATION_YEARS).to eq(25)
    end

    # Le plan s'éteint : rien avant la première année louée, rien après la vingt-cinquième.
    it "gives nothing to the day of the purchase nor to the years the plan no longer covers" do
      expect(described_class.new(**attributes, year: 0).depreciation).to eq(0)
      expect(described_class.new(**attributes, year: 25).depreciation).to eq(6_400)
      expect(described_class.new(**attributes, year: 26).depreciation).to eq(0)
    end
  end

  # La CFE du meublé et le comptable que l'amortissement rend nécessaire : 300 € et 500 €.
  describe "#own_charges" do
    it "pays the accountant on top of the business tax the furnished letting already owes" do
      expect(taxation.own_charge_lines).to eq(business_tax: BigDecimal("300"), accounting_fees: BigDecimal("500"))
      expect(taxation.own_charges).to eq(800)
    end
  end

  # 13 200 € de recettes, moins 2 000 € de charges, 800 € de CFE et de comptable, 6 400 € d'amortissement.
  describe "#taxable_income" do
    it "deducts everything it really pays and the depreciation it does not" do
      expect(taxation.receipts).to eq(13_200)
      expect(taxation.allowance).to eq(0)
      expect(taxation.taxable_income).to eq(4_000)
    end

    # Ni le déficit ni l'excédent d'amortissement ne se reportent : l'année qui n'a rien gagné ne doit rien.
    it "asks nothing of a year the interest and the depreciation have swallowed" do
      indebted = described_class.new(**attributes, loan_interest: 5_000)

      expect(indebted.taxable_income).to eq(0)
      expect(indebted.total).to eq(0)
    end
  end

  # 4 000 € imposables : 30 % de barème, et 18,6 % de prélèvements sociaux, car un loyer meublé est un BIC.
  describe "the two levies" do
    it "applies the bracket of the household and the social charges of the furnished letting" do
      expect(taxation.income_tax).to eq(1_200)
      expect(taxation.social_charges_rate).to eq(BigDecimal("18.6"))
      expect(taxation.social_charges).to eq(744)
      expect(taxation.total).to eq(1_944)
    end
  end

  # Le forfait du micro-BIC laisse 6 600 € imposables là où le réel amorti n'en laisse que 4 000.
  it "costs less than the micro-BIC on the same year, the depreciation making the difference" do
    expect(taxation.total).to be < Taxation::MicroBic.new(**attributes).total
  end

  # Le comptable est au LMNP ce que la CFE est au meublé : les autres régimes ne le paient pas.
  it "is the only regime to pay an accountant" do
    expect(Taxation::MicroBic.new(**attributes).own_charge_lines).to eq(business_tax: BigDecimal("300"))
    expect(Taxation::FoncierReel.new(**attributes).own_charges).to eq(0)
    expect(Taxation::FoncierReel.new(**attributes).depreciation).to eq(0)
  end

  def attributes
    { rent_excluding_charges: 12_000, provision_for_charges: 1_200, marginal_tax_rate: 30, charges: 2_000,
      monthly_rent: 1_000, purchase_price: 200_000, accounting_fees: 500, year: 1 }
  end
end
