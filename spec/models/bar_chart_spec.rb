require "rails_helper"

RSpec.describe BarChart do
  def bar(lines) = described_class::Bar.new(name: "regime", label: "Régime", lines: lines)

  describe "#y_ticks" do
    it "graduates from zero to a round ceiling" do
      chart = described_class.new([bar(tax: 18_000)])

      expect(chart.y_ticks).to eq([0, 5_000, 10_000, 15_000, 20_000])
    end
  end

  describe "#segments" do
    it "stacks each component on the one below" do
      one = bar(notary_fees: 5_000, income_tax: 15_000)

      expect(described_class.new([one]).segments(one).map { |segment| [segment.y, segment.height] })
        .to eq([[263.0, 77.0], [32.0, 231.0]])
    end

    it "leaves a sliver without its amount" do
      one = bar(business_tax: 1, income_tax: 19_999)

      expect(described_class.new([one]).segments(one).map(&:labelled?)).to eq([false, true])
    end
  end

  describe "#components" do
    it "lists every component any bar pays, in stacking order" do
      chart = described_class.new([bar(notary_fees: 1_000, income_tax: 2_000),
                                   bar(notary_fees: 1_000, business_tax: 500)])

      expect(chart.components).to eq(%i[notary_fees income_tax business_tax])
    end
  end

  describe "#bar_x" do
    it "centres each bar on its column" do
      chart = described_class.new(Array.new(4) { bar(tax: 1_000) })

      expect(chart.bar_width).to eq(106)
      expect((0...4).map { |index| chart.bar_x(index) }).to eq([141.0, 353.0, 565.0, 777.0])
    end
  end
end
