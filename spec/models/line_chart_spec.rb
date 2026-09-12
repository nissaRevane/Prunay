require "rails_helper"

RSpec.describe LineChart do
  def series(*values) = LineChart::Series.new(name: "regime", label: "Régime", values: values)

  describe "#y_ticks" do
    it "rounds the axis to a step of 1, 2 or 5" do
      chart = described_class.new([series(-4_200, 12_800)])

      expect(chart.y_ticks).to eq([-5_000, 0, 5_000, 10_000, 15_000])
    end

    it "always spans zero" do
      chart = described_class.new([series(8_000, 9_000)])

      expect(chart.y_ticks.first).to eq(0)
    end
  end

  describe "#segments" do
    it "maps each value onto the plot area" do
      one = series(0, 10_000, 20_000)

      expect(described_class.new([one]).segments(one)).to eq(["88,288.0 512,152.0 936,16.0"])
    end

    it "cuts the curve where the measure is missing" do
      one = series(nil, nil, 10_000, nil, 20_000)

      expect(described_class.new([one]).segments(one)).to eq(["512,152.0", "936,16.0"])
    end
  end

  describe "#zero_y" do
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
