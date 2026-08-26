require "rails_helper"

# Le module ne calcule rien : il nomme les régimes, tient ce qu'ils ont en commun et rend
# celui qu'on lui demande. Ce que chacun retient de l'année se lit dans son propre spec.
RSpec.describe Taxation do
  let(:year) { { rent_excluding_charges: 12_000, marginal_tax_rate: 30, charges: 2_000, loan_interest: 4_000 } }

  describe ".for" do
    it "returns the regime that bears the name" do
      expect(described_class.for(:micro_foncier, **year)).to be_a(Taxation::MicroFoncier)
      expect(described_class.for(:foncier_reel, **year)).to be_a(Taxation::FoncierReel)
    end

    # L'onglet et le paramètre `tab` passent le nom en chaîne : c'est le même régime.
    it "reads a name given as a string as well as a symbol" do
      expect(described_class.for("foncier_reel", **year)).to be_a(Taxation::FoncierReel)
    end

    it "hands the year over to the regime it returns" do
      expect(described_class.for(:foncier_reel, **year).taxable_income).to eq(6_000)
    end

    # Un nom que le module ne connaît pas ne doit pas se résoudre en une classe quelconque.
    it "refuses a regime it does not know" do
      expect { described_class.for(:foncier_imaginaire, **year) }.to raise_error(ArgumentError)
      expect { described_class.for(:regime, **year) }.to raise_error(ArgumentError)
    end
  end

  # L'ordre est celui des onglets de la fiche, et le premier est celui que la liste suppose.
  it "names the regimes in the order the simulation presents them" do
    expect(described_class::NAMES).to eq([:micro_foncier, :foncier_reel])
    expect(described_class::DEFAULT_REGIME).to eq(:micro_foncier)
  end

  # Ce que les deux régimes partagent : les prélèvements sociaux et le barème du foyer.
  it "carries the social charges rate and the brackets of the scale" do
    expect(described_class::SOCIAL_CHARGES_RATE).to eq(BigDecimal("17.2"))
    expect(described_class::MARGINAL_TAX_RATES).to eq([0, 11, 30, 41, 45])
    expect(described_class::DEFAULT_MARGINAL_TAX_RATE).to eq(30)
  end
end
