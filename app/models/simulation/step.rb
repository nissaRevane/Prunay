# Une page de la création. Son nom est aussi un contexte de validation, sa condition dit à qui
# la page s'ouvre, et ses défauts sont ce qu'elle propose tant que rien n'y a été saisi : les
# trois se lisent ici, et une page de plus s'ajoute ici et dans les validations du modèle.
module Simulation::Step
  NAMES = %w[property purchase credit rental charges].freeze

  # La page du crédit ne s'ouvre qu'à qui en a coché un : un achat comptant n'a que quatre pages.
  CONDITIONS = { "credit" => :credit? }.freeze

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
    end.transform_values { |value| whole(value) }
  end

  # Un montant rond se propose en entier : le formulaire montre 500 et non 500,0.
  def whole(value) = value.is_a?(BigDecimal) && value.frac.zero? ? value.to_i : value

  def purchase_defaults(simulation)
    {
      "purchase_date" => Date.current >> simulation.assumptions.purchase_delay_months,
      "initial_works" => 0,
      "furniture" => simulation.estimate(:furniture),
      "down_payment" => down_payment(simulation)
    }
  end

  def credit_defaults(simulation)
    capital = simulation.borrowed_capital
    assumptions = simulation.assumptions

    {
      "loan_rate" => assumptions.loan_rate,
      "loan_duration_years" => assumptions.loan_duration_years,
      "loan_insurance" => Loan.default_insurance(capital, assumptions.loan_insurance_rate),
      "loan_guarantee_fees" => Loan.default_guarantee_fees(capital, assumptions.loan_guarantee_rate),
      "loan_application_fees" => Loan.default_application_fees(capital, assumptions.loan_application_rate,
                                                               assumptions.loan_application_fees_floor)
    }
  end

  def rental_defaults(simulation)
    {
      "monthly_rent" => simulation.estimate(:monthly_rent),
      "monthly_charges" => simulation.estimate(:monthly_charges),
      "occupancy_months" => simulation.assumptions.occupancy_months
    }
  end

  def charge_defaults(simulation)
    (Simulation::ANNUAL_CHARGES + Simulation::REGIME_CHARGES).to_h { |field| [field.to_s, simulation.estimate(field)] }
  end

  # Zéro tant qu'aucun prix n'a été tapé : un dixième de rien ne veut rien dire.
  def down_payment(simulation)
    return 0 if simulation.purchase_price.blank? || simulation.initial_works.blank?

    Simulation::Estimate.new(simulation.assumptions).down_payment(simulation.total_investment)
  end
end
