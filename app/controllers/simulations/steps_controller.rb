module Simulations
  class StepsController < ApplicationController
    STEP_ATTRIBUTES = {
      "property" => [:property_type, :address, :city, :energy_rating, :surface],
      "purchase" => [:purchase_price, :initial_works, :furniture, :purchase_date, :credit, :down_payment],
      "credit" => [:loan_rate, :loan_duration_years, :loan_insurance, :loan_guarantee_fees,
                   :loan_application_fees, :early_repayment_fee],
      "rental" => [:monthly_rent, :monthly_charges, :occupancy_months],
      "charges" => Simulation::ANNUAL_CHARGES + Simulation::REGIME_CHARGES
    }.freeze

    DRAFT_KEY = :simulation_draft

    before_action :set_step
    before_action :ensure_step_reachable

    def show
      @simulation = build_simulation
    end

    def update
      @simulation = build_simulation(step_params)

      return render :show, status: :unprocessable_entity unless @simulation.valid?(@step.to_sym)

      session[DRAFT_KEY] = draft.merge(step_params)

      @steps = steps

      last_step? ? create_simulation : redirect_to(new_simulation_step_path(step: next_step))
    end

    private

    def set_step
      @steps = steps
      @step = params[:step]
      @step_index = @steps.index(@step)

      return redirect_to(new_simulation_step_path(step: @steps.first)) if @step_index.nil?

      @previous_step = @steps[@step_index - 1] if @step_index.positive?
    end

    def ensure_step_reachable
      pending = first_pending_step
      return if pending.nil? || @step_index <= @steps.index(pending)

      redirect_to new_simulation_step_path(step: pending)
    end

    def first_pending_step
      candidate = current_user.simulations.build(draft)

      candidate.steps.find { |step| !candidate.valid?(step.to_sym) }
    end

    def steps
      current_user.simulations.build(draft).steps
    end

    def build_simulation(overrides = {})
      answers = draft.merge(overrides)
      simulation = current_user.simulations.build(answers)

      simulation.assign_attributes(simulation.defaults_for(@step).except(*answers.keys))
      simulation
    end

    def create_simulation
      simulation = current_user.simulations.build(Assumptions.for(current_user).economic.merge(draft))

      if simulation.save
        session.delete(DRAFT_KEY)
        redirect_to simulation, notice: t("flash.simulations.created")
      else
        @simulation = simulation
        render :show, status: :unprocessable_entity
      end
    end

    def draft
      session[DRAFT_KEY] || {}
    end

    def step_params
      params.fetch(:simulation, ActionController::Parameters.new)
            .permit(*STEP_ATTRIBUTES.fetch(@step))
            .to_h
            .stringify_keys
    end

    def next_step
      @steps[@steps.index(@step) + 1]
    end

    def last_step?
      @step == @steps.last
    end
  end
end
