# La meilleure sortie que la simulation permette : le plus haut TRI parmi tous les régimes
# fiscaux et toutes les années de revente. C'est par lui que la liste compare les biens, avec
# la mise de départ et le cash-flow du régime qui l'emporte. Sans flux de signes opposés il
# n'y a pas de taux, et rien à annoncer.
class Simulation::BestReturn
  # Tout ce que la liste lit d'un bien, et rien de plus : c'est ce qui se garde en cache.
  Exit = Struct.new(:rate, :regime, :year, :date, :initial_outlay, :monthly_cash_flow, keyword_init: true)

  attr_reader :simulation

  def initialize(simulation)
    @simulation = simulation
  end

  def found? = !best.nil?

  def rate = best&.rate

  def regime = best&.regime

  def year = best&.year

  def date = best&.date

  def initial_outlay = best&.initial_outlay

  # Le cash-flow de la première année pleine, ramené au mois : ce qu'il faudra porter jusque-là.
  def monthly_cash_flow = best&.monthly_cash_flow

  private

  # Le balayage coûte une centaine de millisecondes et ne dépend que de la ligne de la simulation
  # — les hypothèses économiques y sont recopiées à la création : sa clé de version le date donc
  # exactement, et corriger un chiffre du bien suffit à le refaire.
  def best
    return @best if defined?(@best)

    @best = Rails.cache.fetch([simulation.cache_key_with_version, "best_return"]) { search }
  end

  def search
    found = scan
    return unless found

    winner = projection(found.regime)
    found.initial_outlay = winner.initial_outlay
    found.monthly_cash_flow = (winner.year(1).cash_flow / 12).round(2)

    found
  end

  # On ne cherche pas les cent vingt-quatre taux mais le plus haut : l'actualisation tranche au
  # taux exact, là où deux taux arrondis à la décimale se seraient dits égaux, et seule la sortie
  # qui bat le record vaut une dichotomie.
  def scan
    Taxation::NAMES.reduce(nil) do |found, regime|
      scanned = projection(regime)

      scanned.years.each do |year|
        next if found && !scanned.beats?(year, found.rate)

        rate = scanned.internal_rate_of_return(year)
        next unless rate

        found = Exit.new(rate: rate, regime: regime, year: year.number, date: year.date)
      end

      found
    end
  end

  # Le balayage les construit toutes : celle du régime qui l'emporte se relit sans se refaire.
  def projection(regime)
    @projections ||= {}
    @projections[regime] ||= simulation.projection(regime)
  end
end
