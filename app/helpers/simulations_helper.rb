module SimulationsHelper
  # L'onglet des conditions économiques. Le nom sert quatre fois : le partiel qui le remplit,
  # la traduction qui l'intitule, l'identifiant du panneau et le paramètre `tab` qui le rouvre.
  ECONOMIC_CONDITIONS_TAB = "economic_conditions".freeze

  # Les listes déroulantes du formulaire : la valeur reste en base, le libellé se traduit.
  def property_type_options
    Simulation::PROPERTY_TYPES.map { |type| [t("simulations.property_types.#{type}"), type] }
  end

  def rental_type_options
    Simulation::RENTAL_TYPES.map { |type| [t("simulations.rental_types.#{type}"), type] }
  end

  def energy_rating_options
    Simulation::ENERGY_RATINGS
  end

  # Les onglets de la fiche, dans l'ordre où ils se lisent : le tableau d'amortissement n'en
  # est un que pour une simulation qui porte un crédit. Chaque nom est aussi celui du partiel
  # qui le remplit et de la traduction qui l'intitule.
  def simulation_tabs(schedule)
    tabs = %w[parameters projection]
    tabs << "amortization" if schedule

    tabs << ECONOMIC_CONDITIONS_TAB
  end

  # La condition qui gouverne une charge, telle que le contrôleur `charges` la reconnaît :
  # le prédicat du modèle, sans son point d'interrogation. Nil pour une charge que rien ne
  # conditionne — l'attribut ne s'écrit alors pas.
  def charge_condition_name(field)
    Simulation::CHARGE_CONDITIONS[field]&.to_s&.delete("?")
  end
end
