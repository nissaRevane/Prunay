module Simulations
  # La création d'une simulation, page par page.
  #
  # Rien n'est écrit en base avant la dernière : les réponses s'accumulent en session, et
  # chaque page ne valide que ses propres champs — d'où les contextes de validation nommés
  # comme les étapes (voir +Simulation::Step::NAMES+). Une simulation à moitié remplie n'existe
  # donc jamais en base, et l'utilisateur peut revenir en arrière sans rien casser.
  #
  # Les pages ne sont pas les mêmes pour tout le monde : celle du crédit ne s'ouvre qu'à qui
  # en a coché un sur la page de l'achat. La liste des pages se demande donc au brouillon
  # (+Simulation#steps+) et non à la constante — et elle se redemande après chaque réponse,
  # puisque c'est une réponse qui la change.
  class StepsController < ApplicationController
    # Ce que chaque page a le droit de demander. La liste sert deux fois : à filtrer les
    # paramètres reçus, et à dire quels champs le brouillon garde.
    STEP_ATTRIBUTES = {
      "property" => [:name, :property_type, :address, :city, :energy_rating, :surface, :condominium],
      "purchase" => [:purchase_price, :initial_works, :purchase_date, :credit, :down_payment],
      "credit" => [:loan_rate, :loan_duration_years, :loan_insurance, :loan_guarantee_fees,
                   :loan_application_fees],
      "rental" => [:monthly_rent, :monthly_charges, :occupancy_months],
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

      # Le parcours se relit sur le brouillon mis à jour : c'est la page de l'achat qui dit
      # s'il y a un crédit, donc si la page du crédit vient de s'ouvrir ou de se refermer.
      @steps = steps

      last_step? ? create_simulation : redirect_to(new_simulation_step_path(step: next_step))
    end

    private

    # La page demandée, située dans le parcours de CE brouillon-là. Une page que le brouillon
    # ne traverse pas — celle du crédit, pour un achat comptant — est traitée comme une page
    # qui n'existe pas : on repart du début.
    def set_step
      @steps = steps
      @step = params[:step]
      @step_index = @steps.index(@step)

      return redirect_to(new_simulation_step_path(step: @steps.first)) if @step_index.nil?

      @previous_step = @steps[@step_index - 1] if @step_index.positive?
    end

    # On n'entre pas dans une page tant que les précédentes n'ont rien à dire : une adresse
    # tapée à la main renvoie là où le brouillon s'est arrêté, pas sur un formulaire dont
    # les valeurs par défaut n'auraient aucune surface d'où sortir.
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

    # La simulation telle que la page l'affiche : ce que le brouillon sait déjà, recouvert par
    # ce que le formulaire vient d'envoyer, puis complété par ce que la page propose là où
    # personne n'a encore répondu. Un champ vidé à la main reste donc vide, il ne repasse pas
    # au défaut.
    #
    # Les valeurs proposées se demandent à la simulation en construction, et non à la classe :
    # elles se déduisent des réponses déjà données — la surface, la copropriété —
    # et c'est cet objet-là qui les porte, déjà converties.
    def build_simulation(overrides = {})
      answers = draft.merge(overrides)
      simulation = current_user.simulations.build(answers)

      simulation.assign_attributes(simulation.defaults_for(@step).except(*answers.keys))
      simulation
    end

    # Les conditions économiques ne sont demandées par aucune page — la tranche d'imposition
    # comprise : la simulation naît avec celles de l'utilisateur, et son onglet les corrigera
    # ensuite pour elle seule.
    def create_simulation
      simulation = current_user.simulations.build(EconomicConditions.for(current_user).assumptions.merge(draft))

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
