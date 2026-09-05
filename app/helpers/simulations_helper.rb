module SimulationsHelper
  # Le nom sert de partiel, de traduction, d'identifiant de panneau et de paramètre `tab`.
  ECONOMIC_CONDITIONS_TAB = "economic_conditions".freeze

  # Les listes déroulantes du formulaire : la valeur reste en base, le libellé se traduit.
  def property_type_options
    Simulation::PROPERTY_TYPES.map { |type| [t("simulations.property_types.#{type}"), type] }
  end

  def energy_rating_options
    Simulation::ENERGY_RATINGS
  end

  # Une projection par régime, et l'amortissement pour la seule simulation qui porte un crédit.
  def simulation_tabs(schedule)
    tabs = ["parameters"] + Taxation::NAMES.map(&:to_s)
    tabs << "amortization" if schedule

    tabs << ECONOMIC_CONDITIONS_TAB
  end

  # Le prédicat du modèle sans son point d'interrogation ; nil quand rien ne conditionne la charge.
  def charge_condition_name(field)
    Simulation::CHARGE_CONDITIONS[field]&.to_s&.delete("?")
  end
end
