module SimulationsHelper
  PARAMETERS_TAB = "parameters".freeze
  AMORTIZATION_TAB = "amortization".freeze
  ECONOMIC_CONDITIONS_TAB = "economic_conditions".freeze

  COMPARISON_TAB = "comparison".freeze

  TAXATION_TAB = "taxation".freeze

  COMPARISON_MEASURES = %i[immobilized_capital sale_profit internal_rate_of_return].freeze

  RATE_MEASURE = :internal_rate_of_return

  EXIT_YEAR_GLYPHS = { previous: "‹", next: "›" }.freeze

  UNCHARGED_TAXES = %i[income_tax social_charges capital_gain_tax].freeze

  INLINE_EDIT_ACTIONS = "change->inline-edit#save keydown.enter->inline-edit#confirm " \
                        "focusout->inline-edit#close keydown.esc->inline-edit#cancel " \
                        "submit->inline-edit#lock turbo:submit-end->inline-edit#release".freeze

  WORD_ACTIONS = "click->inline-edit#open keydown.enter->inline-edit#open keydown.space->inline-edit#open".freeze

  def credit_values(simulation)
    { credit_rate_value: Simulation::NOTARY_FEES_RATE.to_f, credit_base_value: Simulation::NOTARY_FEES_BASE,
      credit_share_value: (simulation.assumptions.down_payment_share / 100).to_f,
      credit_rounding_value: Simulation::Estimate::ROUNDING }
  end

  def property_type_options
    Simulation::PROPERTY_TYPES.map { |type| [t("simulations.property_types.#{type}"), type] }
  end

  def energy_rating_options
    Simulation::ENERGY_RATINGS
  end

  def answer_options
    [[t("views.simulations.show.answer_yes"), true], [t("views.simulations.show.answer_no"), false]]
  end

  def simulation_tabs(schedule)
    tabs = [PARAMETERS_TAB, TAXATION_TAB, COMPARISON_TAB]
    tabs << AMORTIZATION_TAB if schedule

    tabs << ECONOMIC_CONDITIONS_TAB
  end

  def simulation_panels(schedule)
    simulation_tabs(schedule).flat_map { |name| taxation_tab?(name) ? Taxation::NAMES.map(&:to_s) : name }
  end

  def taxation_tab?(name) = name == TAXATION_TAB

  def taxation_regime?(name) = Taxation::NAMES.include?(name.to_s.to_sym)

  def opened_regime(tab, regime)
    [tab, regime].find { |name| taxation_regime?(name) }&.to_s || Taxation::REVIEW_REGIME.to_s
  end

  def panel_label_id(name) = taxation_regime?(name) ? "regime-#{name}" : "tab-#{name}"

  def regimes_paying(simulation, charge)
    Taxation::NAMES.select { |name| simulation.taxation(name).own_charge_lines.key?(charge) }
  end

  def regimes_with_rent_premium = Taxation::NAMES.select { |name| Taxation.rent_premium_rate(name).positive? }

  def regimes_without_rent_premium = Taxation::NAMES - regimes_with_rent_premium

  def regimes_furnished = Taxation::NAMES.select { |name| Taxation.furnished?(name) }

  def rent_premium_label(regime) = rate_label(Taxation.rent_premium_rate(regime))

  def regime_scope(regimes) = { tabs_target: "regimeScoped", regimes: Array(regimes).join(" ") }

  def annual_charges_under(simulation, regime) = simulation.annual_charges + simulation.taxation(regime).own_charges

  def comparison_chart(projections, measure)
    LineChart.new(projections.map do |regime, projection|
      LineChart::Series.new(name: regime.to_s, label: t("views.simulations.show.tab_#{regime}"),
                            values: comparison_values(projection, measure))
    end)
  end

  def tax_burden_chart(projections, exit_year)
    BarChart.new(projections.map do |regime, projection|
      BarChart::Bar.new(name: regime.to_s, label: t("views.simulations.show.tab_#{regime}"),
                        lines: projection.tax_lines(projection.year(exit_year)))
    end)
  end

  def exit_year_step(simulation, year, direction)
    glyph = EXIT_YEAR_GLYPHS.fetch(direction)
    return tag.span(glyph, class: "exit-year-step exit-year-step-off", aria: { hidden: true }) unless year.between?(1, Projection::HORIZON_YEARS)

    link_to glyph, tax_burden_simulation_path(simulation, exit_year: year), class: "exit-year-step",
            aria: { label: t("views.simulations.show.exit_year_#{direction}") },
            data: { action: "exit-year#remember", exit_year_year_param: year }
  end

  def tax_component_label(component)
    return t("views.simulations.show.tax_#{component}") if UNCHARGED_TAXES.include?(component)

    charge_detail_label(component)
  end

  def chart_tick_label(value, measure)
    return return_rate_label(value) if rate_measure?(measure)

    number_to_currency(value, precision: 0)
  end

  def editable_detail(simulation, field, value, url: parameters_url(simulation),
                      label: Simulation.human_attribute_name(field), note: nil, value_class: nil,
                      regimes: nil, &block)
    render(layout: "simulations/editable", locals: {
             simulation: simulation, label: label, note: note,
             value: value, url: url, value_class: value_class, regimes: regimes
           }, &block)
  end

  # Un span et non un bouton : Chrome coupe la ligne après un bouton.
  def editable_word(simulation, field, value, display_class: nil, &block)
    tag.span(class: "inline-word", data: { controller: "inline-edit" }) do
      tag.span(value, class: class_names("inline-edit-display", display_class),
               title: Simulation.human_attribute_name(field), role: "button", tabindex: 0,
               data: { inline_edit_target: "display", action: WORD_ACTIONS }) +
        inline_edit_form(simulation, parameters_url(simulation), &block)
    end
  end

  def energy_rating_badge(simulation)
    rating = simulation.energy_rating
    letter = rating.presence || t("views.simulations.show.energy_rating_unknown")
    label = safe_join([tag.small(Simulation.human_attribute_name(:energy_rating)),
                       tag.span(letter, class: "dpe-letter")])

    editable_word(simulation, :energy_rating, label,
                  display_class: ["dpe", ("dpe-#{rating.downcase}" if rating.present?)]) do |f|
      f.select :energy_rating, energy_rating_options,
               { include_blank: t("views.simulations.steps.property.energy_rating_blank") }, class: "form-control"
    end
  end

  def parameters_url(simulation) = simulation_path(simulation, tab: PARAMETERS_TAB, regime: params[:regime])

  def inline_edit_form(simulation, url, &block)
    form_with model: simulation, url: url, method: :patch, class: "inline-edit-form", html: { hidden: true },
              data: { inline_edit_target: "form", action: INLINE_EDIT_ACTIONS }, &block
  end

  def statement_hint(key)
    text = t("views.simulations.show.hint_#{key}")

    tag.span("?", class: "statement-hint", tabindex: 0, role: "note", aria: { label: text },
                  data: { hint: text })
  end

  def rent_detail_lines(projection, year)
    return {} if year.number.zero?

    rent = monthly_label(:rent_excluding_charges, projection.monthly_rent_of(year), projection)
    unless projection.provision_in_receipts? && year.provision_for_charges.positive?
      return { rent => year.rent_excluding_charges }
    end

    provision = monthly_label(:provision_for_charges, projection.monthly_provision_of(year), projection)

    { rent => year.rent_excluding_charges, provision => year.provision_for_charges }
  end

  def charge_detail_lines(projection, year)
    lines = projection.charge_lines(year).to_h { |field, amount| [charge_detail_label(field), -amount] }
    return lines if lines.empty? || projection.provision_in_receipts? || year.provision_for_charges.zero?

    lines.merge(statement_label(:provision_repaid) => year.provision_for_charges)
  end

  def loan_detail_lines(year)
    return {} unless year.loan_insurance.positive?

    { statement_label(:loan_interest) => -year.interest_excluding_insurance,
      statement_label(:loan_insurance) => -year.loan_insurance }
  end

  # L'amortissement se montre même quand il ne laisse rien à imposer.
  def tax_detail_lines(year)
    taxation = year.taxation
    depreciation = depreciation_lines(taxation)
    return {} unless taxation.taxable_income.positive? || depreciation.any?

    allowance_lines(taxation).merge(depreciation).merge(
      statement_label(:taxable_income) => taxation.taxable_income,
      statement_label(:income_tax, rate: rate_label(taxation.marginal_tax_rate)) => -taxation.income_tax,
      statement_label(:social_charges, rate: rate_label(taxation.social_charges_rate)) => -taxation.social_charges
    )
  end

  # La décote est acquise dès la signature ; la revalorisation court après.
  def property_value_detail_lines(projection, year)
    growth = year.property_value - projection.market_value
    lines = { statement_label(:purchase_discount) => projection.purchase_discount,
              statement_label(:property_growth) => growth }.reject { |_, amount| amount.zero? }
    return {} if lines.empty?

    { statement_label(:purchase_price) => projection.purchase_price }.merge(lines)
  end

  def sale_cost_detail_lines(projection, year)
    projection.sale_cost_lines(year).to_h { |field, amount| [statement_label(field), -amount] }
  end

  def capital_gain_detail_lines(year)
    gain = year.gain
    return {} unless gain.amount.positive?

    taxes = {
      statement_label(:capital_gain) => gain.amount,
      statement_label(:capital_gain_income_tax, rate: rate_label(Taxation::CapitalGain::INCOME_TAX_RATE),
                      allowance: rate_label(gain.income_tax_allowance_rate)) => -gain.income_tax,
      statement_label(:capital_gain_social_charges, rate: rate_label(Taxation::SOCIAL_CHARGES_RATE),
                      allowance: rate_label(gain.social_charges_allowance_rate)) => -gain.social_charges
    }

    { statement_label(:fiscal_value) => gain.acquisition_value }.merge(reintegration_lines(gain)).merge(taxes)
  end

  def immobilized_capital_detail_lines(projection, year)
    { statement_label(:initial_outlay) => -projection.initial_outlay,
      statement_label(:cumulative_cash_flow) => projection.cumulative_cash_flow(year) }
  end

  def internal_rate_of_return_label(rate)
    return t("views.simulations.show.no_internal_rate_of_return") if rate.nil?

    return_rate_label(rate)
  end

  private

  def rate_measure?(measure) = measure == RATE_MEASURE

  def comparison_values(projection, measure)
    return projection.years.map(&measure) unless rate_measure?(measure)

    projection.years.map { |year| positive_rate(projection.internal_rate_of_return(year)) }
  end

  def positive_rate(rate) = (rate if rate&.positive?)

  def statement_label(key, **options) = t("views.simulations.show.detail_#{key}", **options)

  def charge_detail_label(field)
    return t("views.simulations.show.business_tax") if field == :business_tax

    Simulation.human_attribute_name(field)
  end

  def reintegration_lines(gain)
    return {} unless gain.depreciation.positive?

    { statement_label(:reintegrated_depreciation) => -gain.depreciation }
  end

  def depreciation_lines(taxation)
    lines = taxation.capitalized_lines.to_h do |component, amount|
      [statement_label(:"capitalized_#{component}", share: capitalized_share_label(component)), amount]
    end
    taxation.depreciation_lines.each do |component, amount|
      lines[statement_label(:"depreciation_#{component}")] = -amount
    end
    deferred = taxation.deferred_depreciation.values.sum
    carried = taxation.carried_forward_depreciation.values.sum
    lines[statement_label(:deferred_depreciation)] = -deferred if deferred.positive?
    lines[statement_label(:carried_forward_depreciation)] = carried if carried.positive?
    lines
  end

  def capitalized_share_label(component)
    rate_label(Taxation::DepreciationPlan::CAPITALIZED_SHARES.fetch(component) * 100)
  end

  def allowance_lines(taxation)
    return {} unless taxation.allowance.positive?

    { statement_label(:receipts) => taxation.receipts,
      statement_label(:allowance, rate: rate_label(taxation.allowance_rate)) => -taxation.allowance }
  end

  def monthly_label(key, amount, projection)
    statement_label(key, amount: number_to_currency(amount), months: months_label(projection))
  end

  def months_label(projection)
    number_with_precision(projection.occupancy_months, precision: 1, strip_insignificant_zeros: true)
  end

  def rate_label(rate) = number_to_percentage(rate, precision: 2, strip_insignificant_zeros: true)

  def return_rate_label(rate) = number_to_percentage(rate, precision: 1)
end
