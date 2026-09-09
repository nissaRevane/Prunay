# La meilleure sortie que la simulation permette : le plus haut TRI parmi tous les régimes
# fiscaux et toutes les années de revente. C'est par lui que la liste compare les biens, avec
# la mise de départ et le cash-flow du régime qui l'emporte. Sans flux de signes opposés il
# n'y a pas de taux, et rien à annoncer.
class Simulation::BestReturn
  Exit = Struct.new(:rate, :regime, :year, keyword_init: true)

  attr_reader :simulation

  def initialize(simulation)
    @simulation = simulation
  end

  def found? = !best.nil?

  def rate = best&.rate

  def regime = best&.regime

  def year = best&.year

  def initial_outlay = simulation.initial_outlay(regime)

  # Le cash-flow de la première année pleine, ramené au mois : ce qu'il faudra porter jusque-là.
  def monthly_cash_flow = (projection.year(1).cash_flow / 12).round(2)

  private

  def projection
    @projection ||= simulation.projection(regime)
  end

  def best
    return @best if defined?(@best)

    @best = exits.max_by(&:rate)
  end

  def exits
    Taxation::NAMES.flat_map do |name|
      projection = simulation.projection(name)

      projection.years.filter_map do |year|
        rate = projection.internal_rate_of_return(year)

        Exit.new(rate: rate, regime: name, year: year) if rate
      end
    end
  end
end
