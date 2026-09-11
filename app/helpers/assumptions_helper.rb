module AssumptionsHelper
  # La valeur reste le nombre que la colonne porte, le libellé se lit en pourcents.
  def marginal_tax_rate_options
    Taxation::MARGINAL_TAX_RATES.map { |rate| [number_to_percentage(rate, precision: 0), rate] }
  end

  # Le libellé porte déjà l'unité : un champ n'a que son pas et ses bornes à dire.
  def assumption_field(form, name, step: "0.01", min: 0, max: nil)
    tag.div(class: "form-group form-group-half") do
      form.label(name) +
        form.number_field(name, step: step, min: min, max: max, class: "form-control", required: true)
    end
  end

  def assumption_row(form, *names, **options)
    tag.div(class: "form-row") { safe_join(names.map { |name| assumption_field(form, name, **options) }) }
  end
end
