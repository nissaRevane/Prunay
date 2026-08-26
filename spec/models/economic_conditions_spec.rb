require "rails_helper"

RSpec.describe EconomicConditions, type: :model do
  let(:user) { create(:user) }

  describe "validations" do
    subject { build(:economic_conditions) }

    it { is_expected.to validate_presence_of(:rent_growth_rate) }
    it { is_expected.to validate_presence_of(:property_growth_rate) }
    it { is_expected.to validate_presence_of(:inflation_rate) }

    # Les taux se prennent dans les deux sens : un marché peut baisser, et un loyer avec lui.
    it { is_expected.to validate_numericality_of(:rent_growth_rate).is_greater_than_or_equal_to(described_class::MIN_RATE).is_less_than_or_equal_to(described_class::MAX_RATE) }
    it { is_expected.to validate_numericality_of(:property_growth_rate).is_greater_than_or_equal_to(described_class::MIN_RATE).is_less_than_or_equal_to(described_class::MAX_RATE) }
    it { is_expected.to validate_numericality_of(:inflation_rate).is_greater_than_or_equal_to(described_class::MIN_RATE).is_less_than_or_equal_to(described_class::MAX_RATE) }

    # La tranche marginale n'est pas un taux libre : le barème n'en connaît que cinq.
    it { is_expected.to validate_inclusion_of(:marginal_tax_rate).in_array(Taxation::MARGINAL_TAX_RATES) }
  end

  # Un utilisateur n'a pas de ligne en base tant qu'il n'a rien changé : la page doit tout de
  # même s'ouvrir sur quelque chose, et ce quelque chose est ce que Prunay suppose.
  describe ".for" do
    it "is what Prunay assumes as long as the user has not decided otherwise" do
      conditions = described_class.for(user)

      expect(conditions).to be_new_record
      expect(conditions).to have_attributes(described_class::DEFAULTS)
    end

    it "supposes one per cent on the rents and the prices, two on the charges, and a household in the 30 per cent bracket" do
      expect(described_class::DEFAULTS).to eq(rent_growth_rate: 1, property_growth_rate: 1, inflation_rate: 2,
                                              marginal_tax_rate: 30)
    end

    it "is what the user has decided once he has decided it" do
      create(:economic_conditions, user: user, rent_growth_rate: 3)

      expect(described_class.for(user.reload)).to be_persisted
      expect(described_class.for(user.reload).rent_growth_rate).to eq(3)
    end
  end

  # Les colonnes portent les mêmes noms des deux côtés : c'est ce qui permet d'en habiller
  # une simulation qui naît sans les nommer une seconde fois.
  describe "#assumptions" do
    it "reads as the simulation columns of the same name" do
      conditions = build(:economic_conditions, rent_growth_rate: 3, property_growth_rate: 4, inflation_rate: 5,
                                               marginal_tax_rate: 41)

      expect(conditions.assumptions).to eq("rent_growth_rate" => 3, "property_growth_rate" => 4,
                                           "inflation_rate" => 5, "marginal_tax_rate" => 41)
      expect(build(:simulation, conditions.assumptions)).to have_attributes(rent_growth_rate: 3, inflation_rate: 5,
                                                                           marginal_tax_rate: 41)
    end
  end
end
