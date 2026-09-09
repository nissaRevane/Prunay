module SimulationsHelper
  # Le nom sert de partiel, de traduction, d'identifiant de panneau et de paramètre `tab`.
  PARAMETERS_TAB = "parameters".freeze
  AMORTIZATION_TAB = "amortization".freeze
  ECONOMIC_CONDITIONS_TAB = "economic_conditions".freeze

  COMPARISON_TAB = "comparison".freeze

  # L'onglet fiscal n'a pas de panneau à lui : il ouvre celui du régime choisi dans sa liste.
  TAXATION_TAB = "taxation".freeze

  # Ce que l'onglet de comparaison met côte à côte : une année d'un régime se lit sur les deux.
  COMPARISON_MEASURES = %i[immobilized_capital sale_profit].freeze

  INLINE_EDIT_ACTIONS = "change->inline-edit#save keydown.enter->inline-edit#confirm " \
                        "focusout->inline-edit#close keydown.esc->inline-edit#cancel " \
                        "submit->inline-edit#lock turbo:submit-end->inline-edit#release".freeze

  # Un mot de la phrase n'est pas un bouton : le clavier l'ouvre comme le clic.
  WORD_ACTIONS = "click->inline-edit#open keydown.enter->inline-edit#open keydown.space->inline-edit#open".freeze

  # Les listes déroulantes du formulaire : la valeur reste en base, le libellé se traduit.
  def property_type_options
    Simulation::PROPERTY_TYPES.map { |type| [t("simulations.property_types.#{type}"), type] }
  end

  def energy_rating_options
    Simulation::ENERGY_RATINGS
  end

  # Un booléen se corrige mieux dans une liste que dans une case : la fiche l'affiche déjà ainsi.
  def answer_options
    [[t("views.simulations.show.answer_yes"), true], [t("views.simulations.show.answer_no"), false]]
  end

  # La barre des onglets : un seul pour la fiscalité, et l'amortissement pour qui porte un crédit.
  def simulation_tabs(schedule)
    tabs = [PARAMETERS_TAB, TAXATION_TAB, COMPARISON_TAB]
    tabs << AMORTIZATION_TAB if schedule

    tabs << ECONOMIC_CONDITIONS_TAB
  end

  # Un panneau par régime derrière l'onglet fiscal : le serveur les rend tous, un seul se montre.
  def simulation_panels(schedule)
    simulation_tabs(schedule).flat_map { |name| taxation_tab?(name) ? Taxation::NAMES.map(&:to_s) : name }
  end

  def taxation_tab?(name) = name == TAXATION_TAB

  def taxation_regime?(name) = Taxation::NAMES.include?(name.to_s.to_sym)

  # Le régime que l'onglet fiscal présente : celui de l'onglet ouvert, celui d'où l'on revient, le réel à défaut.
  def opened_regime(tab, regime)
    [tab, regime].find { |name| taxation_regime?(name) }&.to_s || Taxation::REVIEW_REGIME.to_s
  end

  # Le panneau d'un régime est titré par son entrée dans la liste déroulante, les autres par leur onglet.
  def panel_label_id(name) = taxation_regime?(name) ? "regime-#{name}" : "tab-#{name}"

  # Les régimes qu'un poste de charge concerne : la CFE ne vaut qu'au meublé, le comptable qu'au LMNP.
  def regimes_paying(simulation, charge)
    Taxation::NAMES.select { |name| simulation.taxation(name).own_charge_lines.key?(charge) }
  end

  # Les régimes qui majorent le loyer saisi : le meublé se loue plus cher que le nu.
  def regimes_with_rent_premium = Taxation::NAMES.select { |name| Taxation.rent_premium_rate(name).positive? }

  def regimes_without_rent_premium = Taxation::NAMES - regimes_with_rent_premium

  # Les régimes qui louent meublé : eux seuls achètent les meubles et les entretiennent.
  def regimes_furnished = Taxation::NAMES.select { |name| Taxation.furnished?(name) }

  # La prime du meublé telle que la fiche l'annonce, à côté du loyer qu'elle majore.
  def rent_premium_label(regime) = rate_label(Taxation.rent_premium_rate(regime))

  # Une ligne que le régime ouvert seul mérite : le serveur les rend toutes, l'onglet fiscal choisit.
  def regime_scope(regimes) = { tabs_target: "regimeScoped", regimes: Array(regimes).join(" ") }

  # Ce que le régime paie en plus des charges que tous supportent : son total de l'année.
  def annual_charges_under(simulation, regime) = simulation.annual_charges + simulation.taxation(regime).own_charges

  # Une courbe par régime sur la même mesure : les quatre projections sont déjà là, il n'y a
  # qu'à leur demander l'année après l'année.
  def comparison_chart(projections, measure)
    LineChart.new(projections.map do |regime, projection|
      LineChart::Series.new(name: regime.to_s, label: t("views.simulations.show.tab_#{regime}"),
                            values: projection.years.map(&measure))
    end)
  end

  # Une valeur modifiable au clic : le libellé vient du modèle sauf mention contraire, le champ du bloc.
  def editable_detail(simulation, field, value, url: parameters_url(simulation),
                      label: Simulation.human_attribute_name(field), note: nil, value_class: nil,
                      regimes: nil, &block)
    render(layout: "simulations/editable", locals: {
             simulation: simulation, label: label, note: note,
             value: value, url: url, value_class: value_class, regimes: regimes
           }, &block)
  end

  # Un mot de la phrase : bâti sans un blanc pour que la ponctuation lui colle, et un span
  # plutôt qu'un bouton — Chrome coupe la ligne après un bouton, laissant le point orphelin.
  def editable_word(simulation, field, value, display_class: nil, &block)
    tag.span(class: "inline-word", data: { controller: "inline-edit" }) do
      tag.span(value, class: class_names("inline-edit-display", display_class),
               title: Simulation.human_attribute_name(field), role: "button", tabindex: 0,
               data: { inline_edit_target: "display", action: WORD_ACTIONS }) +
        inline_edit_form(simulation, parameters_url(simulation), &block)
    end
  end

  # L'étiquette énergie à même le nom de la fiche : la couleur de la classe, et la lettre qui se corrige au clic.
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

  # Une correction rouvre la fiche sur ses paramètres, et l'onglet fiscal sur le régime d'où elle part.
  def parameters_url(simulation) = simulation_path(simulation, tab: PARAMETERS_TAB, regime: params[:regime])

  # Le formulaire d'une valeur corrigée d'un clic : il part seul au changement, sans bouton.
  def inline_edit_form(simulation, url, &block)
    form_with model: simulation, url: url, method: :patch, class: "inline-edit-form", html: { hidden: true },
              data: { inline_edit_target: "form", action: INLINE_EDIT_ACTIONS }, &block
  end

  # Une explication au survol, jamais un pavé : le libellé la porte à côté de lui.
  def statement_hint(key)
    text = t("views.simulations.show.hint_#{key}")

    tag.span("?", class: "statement-hint", tabindex: 0, role: "note", aria: { label: text },
                  data: { hint: text })
  end

  # Le loyer se saisit au mois : la fiche redit le mois indexé et les mois effectivement loués.
  def rent_detail_lines(projection, year)
    return {} if year.number.zero?

    rent = monthly_label(:rent_excluding_charges, projection.monthly_rent_of(year), projection)
    unless projection.provision_in_receipts? && year.provision_for_charges.positive?
      return { rent => year.rent_excluding_charges }
    end

    provision = monthly_label(:provision_for_charges, projection.monthly_provision_of(year), projection)

    { rent => year.rent_excluding_charges, provision => year.provision_for_charges }
  end

  # Chaque poste tel que l'année le porte ; hors meublé, la provision remboursée s'en retranche.
  def charge_detail_lines(projection, year)
    lines = projection.charge_lines(year).to_h { |field, amount| [charge_detail_label(field), -amount] }
    return lines if lines.empty? || projection.provision_in_receipts? || year.provision_for_charges.zero?

    lines.merge(statement_label(:provision_repaid) => year.provision_for_charges)
  end

  # Sans assurance, la ligne redirait les intérêts : le crédit ne se déplie que s'il en porte une.
  def loan_detail_lines(year)
    return {} unless year.loan_insurance.positive?

    { statement_label(:loan_interest) => -year.interest_excluding_insurance,
      statement_label(:loan_insurance) => -year.loan_insurance }
  end

  # Le chemin de l'impôt : ce qui se déclare, ce que l'abattement ou l'amortissement en ôte, et
  # les deux taux qui frappent. L'amortissement se montre même quand il ne laisse rien à imposer :
  # c'est là tout ce que le LMNP a à dire.
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

  def property_value_detail_lines(projection, year)
    growth = year.property_value - projection.purchase_price
    return {} if growth.zero?

    { statement_label(:purchase_price) => projection.purchase_price,
      statement_label(:property_growth) => growth }
  end

  def sale_cost_detail_lines(projection, year)
    projection.sale_cost_lines(year).to_h { |field, amount| [statement_label(field), -amount] }
  end

  # La plus-value ne se lit pas sur le prix payé mais sur la valeur fiscale, que les amortissements
  # du LMNP creusent, et chaque taux a son abattement.
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

  # Ce qui reste engagé : l'investissement du premier jour, moins les cash-flows déjà encaissés.
  def immobilized_capital_detail_lines(projection, year)
    { statement_label(:initial_outlay) => -projection.initial_outlay,
      statement_label(:cumulative_cash_flow) => projection.cumulative_cash_flow(year) }
  end

  private

  def statement_label(key, **options) = t("views.simulations.show.detail_#{key}", **options)

  def charge_detail_label(field)
    return t("views.simulations.show.business_tax") if field == :business_tax

    Simulation.human_attribute_name(field)
  end

  # Ce que le LMNP a amorti année après année, que la revente lui reprend.
  def reintegration_lines(gain)
    return {} unless gain.depreciation.positive?

    { statement_label(:reintegrated_depreciation) => -gain.depreciation }
  end

  # Ce que le plan inscrit, ce que les années passées ont laissé en attente, et ce qui attendra
  # encore : la somme est ce que l'année déduit. Les charges, elles, se lisent déjà plus haut.
  def depreciation_lines(taxation)
    lines = taxation.depreciation_lines.to_h do |component, amount|
      [statement_label(:"depreciation_#{component}"), -amount]
    end
    deferred = taxation.deferred_depreciation.values.sum
    carried = taxation.carried_forward_depreciation.values.sum
    lines[statement_label(:deferred_depreciation)] = -deferred if deferred.positive?
    lines[statement_label(:carried_forward_depreciation)] = carried if carried.positive?
    lines
  end

  def allowance_lines(taxation)
    return {} unless taxation.allowance.positive?

    { statement_label(:receipts) => taxation.receipts,
      statement_label(:allowance, rate: rate_label(taxation.allowance_rate)) => -taxation.allowance }
  end

  # « 1 000,00 € par mois × 12 mois loués » : le montant de l'année se refait de tête.
  def monthly_label(key, amount, projection)
    statement_label(key, amount: number_to_currency(amount), months: months_label(projection))
  end

  def months_label(projection)
    number_with_precision(projection.occupancy_months, precision: 1, strip_insignificant_zeros: true)
  end

  def rate_label(rate) = number_to_percentage(rate, precision: 2, strip_insignificant_zeros: true)
end
