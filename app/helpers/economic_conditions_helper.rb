module EconomicConditionsHelper
  # La valeur reste le nombre que la colonne porte, le libellé se lit en pourcents.
  def marginal_tax_rate_options
    Taxation::MARGINAL_TAX_RATES.map { |rate| [number_to_percentage(rate, precision: 0), rate] }
  end
end
