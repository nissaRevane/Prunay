require "rails_helper"

RSpec.describe BarChart do
  def bar(lines) = described_class::Bar.new(name: "expense", lines: lines)

  def column(*lines) = described_class::Column.new(label: "Régime", bars: lines.map { |line| bar(line) })

  describe "#segments" do
    it "stacks each component on the one below" do
      one = bar(notary_fees: 5_000, income_tax: 15_000)

      expect(described_class.new([column(one.lines)]).segments(one).map { |segment| [segment.y, segment.height] })
        .to eq([[263.0, 77.0], [32.0, 231.0]])
    end

    it "leaves a sliver without its amount" do
      one = bar(business_tax: 1, income_tax: 19_999)

      expect(described_class.new([column(one.lines)]).segments(one).map(&:labelled?)).to eq([false, true])
    end
  end

  describe "#components" do
    it "lists every component any bar pays, in stacking order" do
      chart = described_class.new([column({ notary_fees: 1_000, income_tax: 2_000 }),
                                   column({ notary_fees: 1_000, business_tax: 500 })])

      expect(chart.components).to eq(%i[notary_fees income_tax business_tax])
    end
  end

  describe "#bar_x" do
    it "centres a lone bar on its column" do
      chart = described_class.new(Array.new(4) { column(tax: 1_000) })

      expect(chart.bar_width).to eq(114)
      expect((0...4).map { |index| chart.bar_x(index, 0) }).to eq([81.0, 309.0, 537.0, 765.0])
    end

    it "sets two bars side by side, a gap apart, around the centre of their column" do
      chart = described_class.new(Array.new(4) { column({ tax: 1_000 }, { rent: 2_000 }) })

      expect(chart.bar_width).to eq(78.8)
      expect((0..1).map { |slot| chart.bar_x(0, slot) }).to eq([58.2, 139.0])
    end
  end
end
