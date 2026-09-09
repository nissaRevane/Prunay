require "rails_helper"

RSpec.describe Simulation::Estimate do
  describe ".for" do
    # Racine carrée : un logement quatre fois plus grand se loue deux fois plus cher, pas quatre.
    it "scales a reference amount by the square root of the surface" do
      expect(described_class.for(:monthly_rent, 50)).to eq(650)
      expect(described_class.for(:monthly_rent, 200)).to eq(1_300)
    end

    it "rounds to the nearest ten euros" do
      expect(described_class.for(:property_tax, 30)).to eq(540)
      expect(described_class.for(:insurance, 30)).to eq(120)
      expect(described_class.for(:maintenance, 30)).to eq(770)
      expect(described_class.for(:condominium_fees, 30)).to eq(770)
      expect(described_class.for(:other_charges, 30)).to eq(80)
    end

    # Ni gestion déléguée ni garantie des loyers impayés ne se supposent : on les propose à zéro.
    it "leaves the amounts that do not follow the surface where they are" do
      expect(described_class.for(:management_fees, 200)).to eq(0)
      expect(described_class.for(:rent_guarantee, 200)).to eq(0)
    end

    # Les meubles se comptent sur 45 m² : 180 m², quatre fois la référence, en meublent le double.
    it "scales the furniture and its upkeep on a smaller reference surface" do
      expect(described_class.for(:furniture, 45)).to eq(2_000)
      expect(described_class.for(:furniture, 180)).to eq(4_000)
      expect(described_class.for(:furniture_maintenance, 45)).to eq(350)
      expect(described_class.for(:furniture_maintenance, 180)).to eq(700)
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
