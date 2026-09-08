# Une page de la création. Son nom est aussi un contexte de validation, sa condition dit à qui
# la page s'ouvre, et ses défauts sont ce qu'elle propose tant que rien n'y a été saisi : les
# trois se lisent ici, et une page de plus s'ajoute ici et dans les validations du modèle.
module Simulation::Step
  NAMES = %w[property purchase credit rental charges].freeze

  # La page du crédit ne s'ouvre qu'à qui en a coché un : un achat comptant n'a que quatre pages.
  CONDITIONS = { "credit" => :credit? }.freeze

  # Trois mois entre la simulation et la signature — le temps d'un compromis.
  PURCHASE_DELAY_MONTHS = 3

  # Onze mois sur douze : la vacance moyenne d'un bien correctement loué.
  OCCUPANCY_MONTHS = 11

  module_function

  def all_for(simulation) = NAMES.select { |name| applicable?(name, simulation) }

  def applicable?(name, simulation)
    condition = CONDITIONS[name.to_s]

    condition.nil? || simulation.public_send(condition)
  end

  # Ils se déduisent des réponses déjà données : la première page n'en propose donc aucun.
  def defaults(name, simulation)
    case name.to_s
    when "purchase" then purchase_defaults(simulation)
    when "credit" then credit_defaults(simulation)
    when "rental" then rental_defaults(simulation)
    when "charges" then charge_defaults(simulation)
    else {}
    end
  end

  def purchase_defaults(simulation)
    {
      "purchase_date" => Date.current >> PURCHASE_DELAY_MONTHS,
      "initial_works" => 0,
      "down_payment" => down_payment(simulation)
    }
  end

  def credit_defaults(simulation)
    capital = simulation.borrowed_capital

    {
      "loan_rate" => Loan::DEFAULT_RATE,
      "loan_duration_years" => Loan::DEFAULT_DURATION_YEARS,
      "loan_insurance" => Loan.default_insurance(capital),
      "loan_guarantee_fees" => Loan.default_guarantee_fees(capital),
      "loan_application_fees" => Loan.default_application_fees(capital)
    }
  end

  def rental_defaults(simulation)
    {
      "monthly_rent" => simulation.estimate(:monthly_rent),
      "monthly_charges" => simulation.estimate(:monthly_charges),
      "occupancy_months" => OCCUPANCY_MONTHS
    }
  end

  def charge_defaults(simulation)
    Simulation::ANNUAL_CHARGES.to_h { |field| [field.to_s, simulation.estimate(field)] }
  end

  # Zéro tant qu'aucun prix n'a été tapé : un dixième de rien ne veut rien dire.
  def down_payment(simulation)
    return 0 if simulation.purchase_price.blank? || simulation.initial_works.blank?

    Simulation::Estimate.down_payment(simulation.total_investment)
  end
end
