# Une colonne par régime fiscal, une ou deux barres empilées poste par poste, en coordonnées
# d'un SVG. Chaque tranche porte son montant, sauf trop mince : il n'y a pas d'échelle.
class BarChart
  WIDTH = 960
  HEIGHT = 380
  MARGIN = { top: 32, right: 24, bottom: 40, left: 24 }.freeze

  BAR_RATIO = BigDecimal("0.5")

  GROUP_RATIO = BigDecimal("0.7")

  BAR_GAP = 2

  # Sous cette hauteur, le montant ne tiendrait pas dans son rectangle.
  LABEL_MIN_HEIGHT = 16

  Column = Struct.new(:label, :bars, keyword_init: true)

  Bar = Struct.new(:name, :lines, keyword_init: true) do
    def total = lines.values.sum
  end

  Segment = Struct.new(:component, :amount, :y, :height, keyword_init: true) do
    def labelled? = height >= LABEL_MIN_HEIGHT

    def middle = y + height / 2
  end

  attr_reader :columns

  def initialize(columns)
    @columns = columns
  end

  def segments(bar)
    base = 0

    bar.lines.map do |component, amount|
      top = base + amount
      segment = Segment.new(component: component, amount: amount, y: y(top), height: (y(base) - y(top)).round(2))
      base = top

      segment
    end
  end

  def components = bars.flat_map { |bar| bar.lines.keys }.uniq

  def x(index) = (MARGIN[:left] + (index + 0.5) * column_width).round(2)

  def bar_x(index, slot) = (x(index) - group_width / 2 + slot * (bar_width + BAR_GAP)).round(2)

  def bar_center(index, slot) = (bar_x(index, slot) + bar_width / 2).round(2)

  def bar_width = ((group_width - BAR_GAP * (slots - 1)) / slots).round(2)

  def y(value) = (MARGIN[:top] + (high - value.to_d) * plot_height / high).round(2)

  def bottom = MARGIN[:top] + plot_height

  private

  def bars = columns.flat_map(&:bars)

  def slots
    @slots ||= columns.map { |column| column.bars.size }.max
  end

  def group_width = column_width * (slots > 1 ? GROUP_RATIO : BAR_RATIO)

  def column_width = plot_width.to_d / columns.size

  def plot_width = WIDTH - MARGIN[:left] - MARGIN[:right]

  def plot_height = HEIGHT - MARGIN[:top] - MARGIN[:bottom]

  # Sans échelle à lire, la plus haute barre monte jusqu'en haut du cadre.
  def high
    @high ||= [bars.map(&:total).max.to_d, 1].max
  end
end
