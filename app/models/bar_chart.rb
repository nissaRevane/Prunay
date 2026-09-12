# Une barre par régime fiscal, empilée poste par poste, en coordonnées d'un SVG. L'échelle
# part du zéro — ce sont des sommes payées — et un poste trop mince ne porte pas son montant.
class BarChart
  WIDTH = 960
  HEIGHT = 380
  MARGIN = { top: 32, right: 24, bottom: 40, left: 88 }.freeze

  GRID_LINES = 4

  BAR_RATIO = BigDecimal("0.5")

  # Sous cette hauteur, le montant ne tiendrait pas dans son rectangle.
  LABEL_MIN_HEIGHT = 16

  Bar = Struct.new(:name, :label, :lines, keyword_init: true) do
    def total = lines.values.sum
  end

  Segment = Struct.new(:component, :amount, :y, :height, keyword_init: true) do
    def labelled? = height >= LABEL_MIN_HEIGHT

    def middle = y + height / 2
  end

  attr_reader :bars

  def initialize(bars)
    @bars = bars
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

  def bar_x(index) = (x(index) - bar_width / 2).round(2)

  def bar_width = (column_width * BAR_RATIO).round(2)

  def y(value) = (MARGIN[:top] + (high - value.to_d) * plot_height / high).round(2)

  def y_ticks = (0..(high / step).round).map { |index| index * step }

  def right = MARGIN[:left] + plot_width

  def bottom = MARGIN[:top] + plot_height

  private

  def column_width = plot_width.to_d / bars.size

  def plot_width = WIDTH - MARGIN[:left] - MARGIN[:right]

  def plot_height = HEIGHT - MARGIN[:top] - MARGIN[:bottom]

  def high = @high ||= (highest / step).ceil * step

  def highest = @highest ||= [bars.map(&:total).max.to_d, 1].max

  def step
    @step ||= nice_step(highest)
  end

  def nice_step(range)
    magnitude = BigDecimal(10)**Math.log10((range / GRID_LINES).to_f).floor

    [1, 2, 5, 10].map { |factor| factor * magnitude }.find { |candidate| range / candidate <= GRID_LINES }
  end
end
