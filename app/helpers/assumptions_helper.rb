module AssumptionsHelper
  # La valeur reste le nombre que la colonne porte, le libellé se lit en pourcents.
  def marginal_tax_rate_options
    Taxation::MARGINAL_TAX_RATES.map { |rate| [number_to_percentage(rate, precision: 0), rate] }
  end

  # Le libellé porte déjà l'unité : un champ n'a que son pas et ses bornes à dire.
  def assumption_field(form, name, step: "0.01", min: 0, max: nil)
    assumption_line(form, name) do
      form.number_field(name, step: step, min: min, max: max, class: "form-control", required: true,
                              value: Assumptions.whole(form.object.public_send(name)))
    end
  end

  def assumption_line(form, name, &field) = tag.div(class: "assumption-field") { form.label(name) + capture(&field) }

  def assumption_grid(&fields) = tag.div(class: "assumption-grid") { capture(&fields) }
end
