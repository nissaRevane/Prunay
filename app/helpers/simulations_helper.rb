module SimulationsHelper
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

  # La condition qui gouverne une charge, telle que le contrôleur `charges` la reconnaît :
  # le prédicat du modèle, sans son point d'interrogation. Nil pour une charge que rien ne
  # conditionne — l'attribut ne s'écrit alors pas.
  def charge_condition_name(field)
    Simulation::CHARGE_CONDITIONS[field]&.to_s&.delete("?")
  end
end
