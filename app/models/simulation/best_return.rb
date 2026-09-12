# La meilleure sortie possible : le plus haut TRI parmi tous les régimes et toutes les années
# de revente. C'est par lui que la liste compare les biens.
class Simulation::BestReturn
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

  def monthly_cash_flow = best&.monthly_cash_flow

  private

  def best
    return @best if defined?(@best)

    # Le balayage coûte ~100 ms et ne dépend que de la ligne de la simulation.
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

  def scan
    @low = InternalRateOfReturn::LOWEST_RATE
    @high = InternalRateOfReturn::HIGHEST_RATE
    champion = nil
    won = nil

    Taxation::NAMES.each do |regime|
      scanned = projection(regime)

      scanned.years.each do |year|
        challenger = scanned.rate_of_return(year)
        next unless contender?(challenger)
        next if champion && duel(champion, challenger).equal?(champion)

        champion = challenger
        won = [regime, year]
      end
    end

    return unless champion

    regime, year = won
    Exit.new(rate: champion.percentage, regime: regime, year: year.number, date: year.date)
  end

  def contender?(candidate)
    candidate.above?(@low) && !candidate.above?(InternalRateOfReturn::HIGHEST_RATE)
  end

  # Deux sorties se départagent par actualisation, sans calculer leur taux.
  def duel(champion, challenger)
    return outright(challenger) if challenger.above?(@high)

    while @high - @low > InternalRateOfReturn::PRECISION
      middle = (@low + @high) / 2
      champion_above = champion.above?(middle)

      if champion_above == challenger.above?(middle)
        champion_above ? @low = middle : @high = middle
      else
        @low = middle
        return champion_above ? champion : challenger
      end
    end

    champion
  end

  def outright(challenger)
    @low = @high
    @high = InternalRateOfReturn::HIGHEST_RATE

    challenger
  end

  def projection(regime)
    @projections ||= {}
    @projections[regime] ||= simulation.projection(regime)
  end
end
