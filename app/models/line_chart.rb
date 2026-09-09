# Une courbe par régime fiscal, ramenée aux coordonnées d'un SVG : la vue n'a plus qu'à tracer
# les points. L'échelle verticale englobe toujours le zéro — capital engagé comme bénéfice le
# traversent, et c'est ce passage-là qu'on vient lire.
class LineChart
  WIDTH = 960
  HEIGHT = 320
  MARGIN = { top: 16, right: 24, bottom: 32, left: 88 }.freeze

  # Assez de repères pour situer un montant, pas assez pour brouiller les courbes.
  GRID_LINES = 4

  # Trente et une années sur un axe : une graduation tous les cinq ans, l'origine comprise.
  X_LABEL_STEP = 5

  Series = Struct.new(:name, :label, :values, keyword_init: true) do
    def last = values.last
  end

  attr_reader :series

  def initialize(series)
    @series = series
  end

  # Une mesure peut manquer une année : la courbe se rend alors en autant de tronçons que de
  # suites d'années renseignées, coupés là où l'année suivante ne l'est pas.
  def segments(one)
    one.values.each_with_index.reject { |value, _| value.nil? }
       .slice_when { |(_, index), (_, following)| following > index + 1 }
       .map { |points| points.map { |value, index| "#{x(index)},#{y(value)}" }.join(" ") }
  end

  def x(index) = (MARGIN[:left] + index * plot_width / (length - 1)).round(2)

  def y(value) = (MARGIN[:top] + (high - value.to_d) * plot_height / span).round(2)

  def zero_y = y(0)

  def y_ticks
    count = ((high - low) / step).round

    (0..count).map { |index| low + index * step }
  end

  def x_ticks = (0...length).select { |index| (index % X_LABEL_STEP).zero? }

  def right = MARGIN[:left] + plot_width

  def bottom = MARGIN[:top] + plot_height

  private

  def length = series.first.values.size

  def plot_width = WIDTH - MARGIN[:left] - MARGIN[:right]

  def plot_height = HEIGHT - MARGIN[:top] - MARGIN[:bottom]

  def span = high - low

  def low = bounds.first

  def high = bounds.last

  # Les bornes tombent sur un multiple du pas : les repères se lisent en chiffres ronds.
  def bounds
    @bounds ||= [(extremes.first / step).floor * step, (extremes.last / step).ceil * step]
  end

  def step
    @step ||= nice_step(extremes.last - extremes.first)
  end

  # Le pas d'un axe se prend dans la suite 1, 2, 5 : c'est là que les chiffres restent ronds.
  def nice_step(range)
    return 1 if range.zero?

    magnitude = BigDecimal(10)**Math.log10((range / GRID_LINES).to_f).floor

    [1, 2, 5, 10].map { |factor| factor * magnitude }.find { |candidate| range / candidate <= GRID_LINES }
  end

  def extremes
    @extremes ||= begin
      values = series.flat_map(&:values).compact.map(&:to_d) << 0

      [values.min, values.max]
    end
  end
end
