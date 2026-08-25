module Simulations
  # La création d'une simulation, en quatre pages.
  #
  # Rien n'est écrit en base avant la dernière : les réponses s'accumulent en session, et
  # chaque page ne valide que ses propres champs — d'où les contextes de validation nommés
  # comme les étapes (voir +Simulation::STEPS+). Une simulation à moitié remplie n'existe
  # donc jamais en base, et l'utilisateur peut revenir en arrière sans rien casser.
  class StepsController < ApplicationController
    # Ce que chaque page a le droit de demander. La liste sert deux fois : à filtrer les
    # paramètres reçus, et à dire quels champs le brouillon garde.
    STEP_ATTRIBUTES = {
      "property" => [:name, :property_type, :address, :city, :energy_rating, :surface, :condominium],
      "purchase" => [:purchase_price, :initial_works, :purchase_date],
      "rental" => [:monthly_rent, :occupancy_months, :rental_type],
      "charges" => Simulation::ANNUAL_CHARGES
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

      last_step? ? create_simulation : redirect_to(new_simulation_step_path(step: next_step))
    end

    private

    def set_step
      @step = params[:step]
      @step_index = Simulation::STEPS.index(@step)

      return redirect_to(new_simulation_step_path(step: Simulation::STEPS.first)) if @step_index.nil?

      @previous_step = Simulation::STEPS[@step_index - 1] if @step_index.positive?
    end

    # On n'entre pas dans une page tant que les précédentes n'ont rien à dire : une adresse
    # tapée à la main renvoie là où le brouillon s'est arrêté, pas sur un formulaire dont
    # les valeurs par défaut n'auraient aucune surface d'où sortir.
    def ensure_step_reachable
      pending = first_pending_step
      return if pending.nil? || Simulation::STEPS.index(@step) <= Simulation::STEPS.index(pending)

      redirect_to new_simulation_step_path(step: pending)
    end

    def first_pending_step
      candidate = current_user.simulations.build(draft)

      Simulation::STEPS.find { |step| !candidate.valid?(step.to_sym) }
    end

    # La simulation telle que la page l'affiche : ses valeurs proposées, recouvertes par ce
    # que le brouillon sait déjà, recouvert à son tour par ce que le formulaire vient
    # d'envoyer. Un champ vidé à la main reste donc vide, il ne repasse pas au défaut.
    def build_simulation(overrides = {})
      attributes = Simulation.defaults_for(@step, surface: draft["surface"]).merge(draft).merge(overrides)

      current_user.simulations.build(attributes)
    end

    def create_simulation
      simulation = current_user.simulations.build(draft)

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
      Simulation::STEPS[Simulation::STEPS.index(@step) + 1]
    end

    def last_step?
      @step == Simulation::STEPS.last
    end
  end
end
