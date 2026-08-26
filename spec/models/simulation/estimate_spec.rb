require "rails_helper"

RSpec.describe Simulation::Estimate do
  describe ".for" do
    # Racine carrée, et non proportion : un logement quatre fois plus grand se loue deux fois
    # plus cher, pas quatre.
    it "scales a reference amount by the square root of the surface" do
      expect(described_class.for(:monthly_rent, 50)).to eq(650)
      expect(described_class.for(:monthly_rent, 200)).to eq(1_300)
    end

    it "rounds to the nearest ten euros" do
      expect(described_class.for(:property_tax, 30)).to eq(540)
      expect(described_class.for(:insurance, 30)).to eq(120)
      expect(described_class.for(:condominium_fees, 30)).to eq(770)
      expect(described_class.for(:other_charges, 30)).to eq(80)
    end

    # L'entretien se lit à deux références : la copropriété porte déjà la façade, la toiture
    # et les communs, et le propriétaire seul les porte toutes.
    it "doubles the maintenance of a property no condominium looks after" do
      expect(described_class.for(:maintenance, 50, condominium: true)).to eq(1_000)
      expect(described_class.for(:maintenance, 50)).to eq(2_000)
    end

    # Ni une gestion déléguée ni une garantie des loyers impayés ne se supposent : on les
    # propose à zéro.
    it "leaves the amounts that do not follow the surface where they are" do
      expect(described_class.for(:management_fees, 200)).to eq(0)
      expect(described_class.for(:rent_guarantee, 200)).to eq(0)
    end

    it "has nothing to propose without a surface" do
      expect(described_class.for(:monthly_rent, nil)).to eq(0)
      expect(described_class.for(:monthly_rent, 0)).to eq(0)
    end
  end

  describe ".down_payment" do
    # Un dixième du coût du projet — 216 612 € font 21 660 €, arrondis à la dizaine d'euros.
    it "is a tenth of the project cost, rounded like the rest" do
      expect(described_class.down_payment(BigDecimal("216612"))).to eq(21_660)
    end
  end
end
