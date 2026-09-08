require "rails_helper"

RSpec.describe SaleCosts do
  # 50 m², la surface de référence : la remise en état y vaut son montant plein.
  it "charges the flat diagnostics and the reference refurbishment at the reference surface" do
    costs = described_class.new(surface: 50)

    expect(costs.diagnostics).to eq(400)
    expect(costs.refurbishment).to eq(500)
    expect(costs.total).to eq(900)
  end

  # 200 m², quatre fois la référence : la racine carrée n'en fait que le double.
  it "scales the refurbishment by the square root of the surface" do
    expect(described_class.new(surface: 200).refurbishment).to eq(1_000)
    expect(described_class.new(surface: 200).total).to eq(1_400)
  end

  # Les diagnostics se paient au dossier : une chambre de bonne les doit en entier.
  it "still owes the whole diagnostics on a small surface" do
    expect(described_class.new(surface: 12.5).total).to eq(650)
  end
end
