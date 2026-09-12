module AssumptionsHelper
  def marginal_tax_rate_options
    Taxation::MARGINAL_TAX_RATES.map { |rate| [number_to_percentage(rate, precision: 0), rate] }
  end

  def assumption_field(form, name, step: "0.01", min: 0, max: nil)
    assumption_line(form, name) do
      form.number_field(name, step: step, min: min, max: max, class: "form-control", required: true,
                              value: Assumptions.whole(form.object.public_send(name)))
    end
  end

  def assumption_line(form, name, &field) = tag.div(class: "assumption-field") { form.label(name) + capture(&field) }

  def assumption_grid(&fields) = tag.div(class: "assumption-grid") { capture(&fields) }
end
