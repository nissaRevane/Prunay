# Une page de la création : son nom est un contexte de validation, sa condition dit à qui elle
# s'ouvre. Une page de plus s'ajoute ici et dans les validations du modèle.
module Simulation::Step
  NAMES = %w[property purchase credit rental charges].freeze

  CONDITIONS = { "credit" => :credit? }.freeze

  module_function

  def all_for(simulation) = NAMES.select { |name| applicable?(name, simulation) }

  def applicable?(name, simulation)
    condition = CONDITIONS[name.to_s]

    condition.nil? || simulation.public_send(condition)
  end

  def defaults(name, simulation)
    case name.to_s
    when "purchase" then purchase_defaults(simulation)
    when "credit" then credit_defaults(simulation)
    when "rental" then rental_defaults(simulation)
    when "charges" then charge_defaults(simulation)
    else {}
    end.transform_values { |value| Assumptions.whole(value) }
  end

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

  def down_payment(simulation)
    return 0 if simulation.purchase_price.blank? || simulation.initial_works.blank?

    Simulation::Estimate.new(simulation.assumptions).down_payment(simulation.total_investment)
  end
end
