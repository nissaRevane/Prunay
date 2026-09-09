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

  # Le balayage les construit toutes : celle du régime qui l'emporte se relit sans se refaire.
  def projection(name = regime)
    @projections ||= {}
    @projections[name] ||= simulation.projection(name)
  end

  def best
    return @best if defined?(@best)

    @best = Taxation::NAMES.reduce(nil) { |found, name| best_exit_of(name, found) }
  end

  # On ne cherche pas les cent vingt-quatre taux mais le plus haut : une actualisation suffit à
  # écarter une sortie qui ne bat pas le record, et seule celle qui le bat vaut une dichotomie.
  def best_exit_of(regime, found)
    scanned = projection(regime)

    scanned.years.each do |year|
      next if found && !scanned.beats?(year, found.rate)

      rate = scanned.internal_rate_of_return(year)
      found = Exit.new(rate: rate, regime: regime, year: year) if rate && (found.nil? || rate > found.rate)
    end

    found
  end
end
