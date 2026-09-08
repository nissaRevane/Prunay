require "rails_helper"

RSpec.describe LineChart do
  def series(*values) = LineChart::Series.new(name: "regime", label: "Régime", values: values)

  describe "#y_ticks" do
    # De -5 000 à 15 000, le pas de 5 000 tient l'amplitude en quatre repères ronds.
    it "rounds the axis to a step of 1, 2 or 5" do
      chart = described_class.new([series(-4_200, 12_800)])

      expect(chart.y_ticks).to eq([-5_000, 0, 5_000, 10_000, 15_000])
    end

    # Toutes les valeurs au-dessus du zéro : l'axe l'inclut quand même, c'est lui qu'on lit.
    it "always spans zero" do
      chart = described_class.new([series(8_000, 9_000)])

      expect(chart.y_ticks.first).to eq(0)
    end
  end

  describe "#points" do
    # Le cadre va de 88 à 936 en largeur, de 16 à 288 en hauteur : 0 et 20 000 en occupent les
    # deux bords, et 10 000 la mi-hauteur.
    it "maps each value onto the plot area" do
      one = series(0, 10_000, 20_000)

      expect(described_class.new([one]).points(one)).to eq("88,288.0 512,152.0 936,16.0")
    end
  end

  describe "#zero_y" do
    # Une échelle de -10 000 à 10 000 pose le zéro au milieu du cadre.
    it "sits where the value zero falls" do
      chart = described_class.new([series(-10_000, 10_000)])

      expect(chart.zero_y).to eq((LineChart::MARGIN[:top] + LineChart::HEIGHT - LineChart::MARGIN[:bottom]) / 2.0)
    end
  end

  describe "#x_ticks" do
    it "graduates every five years, the origin included" do
      chart = described_class.new([series(*Array.new(31, 0))])

      expect(chart.x_ticks).to eq([0, 5, 10, 15, 20, 25, 30])
    end
  end
end
