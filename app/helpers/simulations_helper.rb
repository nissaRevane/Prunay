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
end
