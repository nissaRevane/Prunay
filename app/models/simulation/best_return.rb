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

  # On ne cherche pas les cent vingt-quatre taux mais le plus haut : un seul encadrement les
  # départage tous, resserré duel après duel, et le vainqueur seul finit par une dichotomie.
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

  # Une sortie sans flux de signes opposés n'a pas de taux, et une sortie sous le plancher de
  # l'encadrement est déjà battue : ni l'une ni l'autre ne vaut un duel.
  def contender?(candidate)
    candidate.above?(@low) && !candidate.above?(InternalRateOfReturn::HIGHEST_RATE)
  end

  # Deux sorties se départagent sans qu'on calcule leur taux : chaque milieu de l'encadrement les
  # actualise toutes deux, et la première à passer sous zéro a perdu. L'encadrement qui reste
  # sert au duel suivant — c'est ce qui fait tenir tout le balayage en une seule dichotomie.
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

  # Au-dessus du plafond de l'encadrement, la sortie l'emporte sans duel et en ouvre un nouveau.
  def outright(challenger)
    @low = @high
    @high = InternalRateOfReturn::HIGHEST_RATE

    challenger
  end

  # Le balayage les construit toutes : celle du régime qui l'emporte se relit sans se refaire.
  def projection(regime)
    @projections ||= {}
    @projections[regime] ||= simulation.projection(regime)
  end
end
