require "rails_helper"

# La création d'une simulation, page par page. Rien n'est écrit en base avant la dernière :
# les tests le vérifient étape par étape, puisque c'est la promesse du formulaire.
RSpec.describe "Simulation steps", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  def submit(step, attributes)
    patch new_simulation_step_path(step: step), params: { simulation: attributes }
  end

  def field_value(name)
    Nokogiri::HTML(response.body).at_css("##{name}")["value"]
  end

  # Un champ qu'aucune condition ne justifie reste dans la page, masqué et désactivé :
  # requis et invisible, il bloquerait l'envoi du formulaire, et le modèle remet à zéro le
  # montant qu'il ne reçoit pas.
  def asked_for?(name)
    field = Nokogiri::HTML(response.body).at_css("##{name}")

    !field.nil? && field["disabled"].nil?
  end

  def checked?(name)
    !Nokogiri::HTML(response.body).at_css("##{name}")["checked"].nil?
  end

  PROPERTY = { property_type: "apartment", city: "Nantes", surface: "50", condominium: "1" }.freeze
  # Un achat comptant : sans crédit, la page du crédit ne s'ouvre pas.
  PURCHASE = { purchase_price: "200000", initial_works: "20000", purchase_date: "2026-01-15",
               credit: "0", down_payment: "0" }.freeze
  ON_CREDIT = PURCHASE.merge(credit: "1", down_payment: "25000").freeze
  CREDIT = { loan_rate: "3.5", loan_duration_years: "20", loan_insurance: "21.16" }.freeze
  RENTAL = { monthly_rent: "1000", occupancy_months: "11", rental_type: "unfurnished" }.freeze
  # Le bien de PROPERTY est en copropriété et RENTAL le loue nu : la page des charges lui
  # demande donc les charges de copro, mais ni CFE ni comptable.
  CHARGES = { property_tax: "700", insurance: "150", maintenance: "1000", condominium_fees: "1200",
              management_fees: "0", rent_guarantee: "0", other_charges: "150" }.freeze

  describe "GET /simulations/new" do
    it "opens the first page" do
      get new_simulation_path

      expect(response).to redirect_to(new_simulation_step_path(step: "property"))
    end

    # Rouvrir la porte, c'est repartir de zéro : un brouillon abandonné ne doit pas
    # ressurgir dans la simulation suivante.
    it "forgets a draft left behind" do
      submit("property", PROPERTY)

      get new_simulation_path
      follow_redirect!

      expect(field_value("simulation_city")).to eq("")
    end
  end

  describe "walking the four pages" do
    it "creates the simulation only once the last page is submitted" do
      expect {
        submit("property", PROPERTY)
        expect(response).to redirect_to(new_simulation_step_path(step: "purchase"))

        submit("purchase", PURCHASE)
        expect(response).to redirect_to(new_simulation_step_path(step: "rental"))

        submit("rental", RENTAL)
        expect(response).to redirect_to(new_simulation_step_path(step: "charges"))
      }.not_to change(Simulation, :count)

      expect { submit("charges", CHARGES) }.to change(Simulation, :count).by(1)

      simulation = Simulation.last
      expect(response).to redirect_to(simulation)
      expect(simulation).to have_attributes(
        user: user, name: "Appartement à Nantes, 50 m²",
        property_type: "apartment", city: "Nantes", surface: 50, condominium: true,
        purchase_price: 200_000, initial_works: 20_000, purchase_date: Date.new(2026, 1, 15),
        monthly_rent: 1_000, occupancy_months: 11, rental_type: "unfurnished",
        property_tax: 700, insurance: 150, maintenance: 1_000, condominium_fees: 1_200,
        management_fees: 0, rent_guarantee: 0, business_tax: 0, accounting_fees: 0,
        other_charges: 150
      )
    end

    # Le nom se demande à la première page sans être exigé : donné, il est gardé tel quel.
    it "keeps the name the first page was given" do
      submit("property", PROPERTY.merge(name: "Le studio du port"))
      submit("purchase", PURCHASE)
      submit("rental", RENTAL)
      submit("charges", CHARGES)

      expect(Simulation.last.name).to eq("Le studio du port")
    end

    # ... et laissé vide, la page du bien ne s'en formalise pas : le nom est le seul champ
    # qu'aucune page n'exige.
    it "lets the first page through without a name" do
      submit("property", PROPERTY.merge(name: ""))

      expect(response).to redirect_to(new_simulation_step_path(step: "purchase"))
    end

    # La page du crédit ne s'ouvre qu'à qui en coche un : le parcours passe alors de quatre
    # pages à cinq, et l'achat mène au crédit plutôt qu'à la location.
    it "walks a fifth page when the purchase is financed by a credit" do
      submit("property", PROPERTY)
      submit("purchase", ON_CREDIT)
      expect(response).to redirect_to(new_simulation_step_path(step: "credit"))

      submit("credit", CREDIT)
      expect(response).to redirect_to(new_simulation_step_path(step: "rental"))

      submit("rental", RENTAL)
      expect { submit("charges", CHARGES) }.to change(Simulation, :count).by(1)

      expect(Simulation.last).to have_attributes(
        credit: true, down_payment: 25_000, loan_rate: 3.5, loan_duration_years: 20,
        loan_insurance: 21.16, borrowed_capital: 211_612
      )
    end

    # Décocher le crédit referme sa page : elle n'est plus dans le parcours, et l'achat mène
    # de nouveau directement à la location.
    it "closes the credit page again when the purchase goes back to being paid outright" do
      submit("property", PROPERTY)
      submit("purchase", ON_CREDIT)
      submit("credit", CREDIT)

      submit("purchase", PURCHASE)

      expect(response).to redirect_to(new_simulation_step_path(step: "rental"))
    end

    # Une page hors parcours se traite comme une page qui n'existe pas : on repart du début.
    it "refuses the credit page to a purchase paid outright" do
      submit("property", PROPERTY)
      submit("purchase", PURCHASE)

      get new_simulation_step_path(step: "credit")

      expect(response).to redirect_to(new_simulation_step_path(step: "property"))
    end

    # Un achat comptant ne garde rien du crédit qu'il a pu déclarer en chemin.
    it "writes nothing of a credit the purchase gave up" do
      submit("property", PROPERTY)
      submit("purchase", ON_CREDIT)
      submit("credit", CREDIT)
      submit("purchase", PURCHASE)
      submit("rental", RENTAL)
      submit("charges", CHARGES)

      expect(Simulation.last).to have_attributes(credit: false, down_payment: 0, loan_rate: 0,
                                                 loan_duration_years: 0, loan_insurance: 0)
    end

    it "keeps what a previous page has already answered" do
      submit("property", PROPERTY)
      submit("purchase", PURCHASE)

      get new_simulation_step_path(step: "property")

      expect(field_value("simulation_city")).to eq("Nantes")
    end
  end

  # Aucune page ne les demande : la simulation naît avec les conditions de l'utilisateur, et
  # c'est son onglet, une fois qu'elle est écrite, qui les corrigera.
  describe "the economic conditions" do
    def walk
      submit("property", PROPERTY)
      submit("purchase", PURCHASE)
      submit("rental", RENTAL)
      submit("charges", CHARGES)
    end

    it "asks for none of them along the way" do
      names = EconomicConditions::RATES.map { |rate| "simulation[#{rate}]" }

      { "property" => PROPERTY, "purchase" => PURCHASE, "rental" => RENTAL, "charges" => CHARGES }.each do |step, answers|
        get new_simulation_step_path(step: step)

        expect(Nokogiri::HTML(response.body).css("input").map { |input| input["name"] }).not_to include(*names)
        submit(step, answers)
      end
    end

    it "gives the new simulation those of the user who creates it" do
      create(:economic_conditions, user: user, rent_growth_rate: 3, property_growth_rate: 4, inflation_rate: 5)

      walk

      expect(Simulation.last).to have_attributes(rent_growth_rate: 3, property_growth_rate: 4, inflation_rate: 5)
    end

    it "falls back on what Prunay assumes for a user who has never decided" do
      walk

      expect(Simulation.last).to have_attributes(EconomicConditions::DEFAULTS)
    end
  end

  # Un appartement est presque toujours en copropriété : la case se propose cochée, et rien
  # n'empêche de la décocher. Changer de type ensuite la fait suivre, mais dans le navigateur.
  describe "the condominium the property page supposes" do
    it "pre-checks the box for the apartment it opens on" do
      get new_simulation_step_path(step: "property")

      expect(checked?("simulation_condominium")).to be(true)
    end

    it "leaves an answer already given rather than proposing it again" do
      submit("property", PROPERTY.merge(condominium: "0"))

      get new_simulation_step_path(step: "property")

      expect(checked?("simulation_condominium")).to be(false)
    end
  end

  describe "the amounts a page proposes" do
    before { submit("property", PROPERTY.merge(surface: "200")) }

    it "dates the purchase three months out and assumes no works" do
      get new_simulation_step_path(step: "purchase")

      expect(field_value("simulation_purchase_date")).to eq((Date.current >> 3).to_s)
      expect(field_value("simulation_initial_works")).to eq("0")
    end

    # 650 € pour 50 m², mis à l'échelle par la racine carrée : 200 m² en font le double.
    it "estimates the rent from the surface and leaves a month of vacancy" do
      submit("purchase", PURCHASE)

      get new_simulation_step_path(step: "rental")

      expect(field_value("simulation_monthly_rent")).to eq("1300")
      expect(field_value("simulation_occupancy_months")).to eq("11")
    end

    it "estimates every charge the property is asked for" do
      submit("purchase", PURCHASE)
      submit("rental", RENTAL)

      get new_simulation_step_path(step: "charges")

      expect(field_value("simulation_property_tax")).to eq("1400")
      expect(field_value("simulation_insurance")).to eq("300")
      expect(field_value("simulation_maintenance")).to eq("2000")
      expect(field_value("simulation_condominium_fees")).to eq("2000")
      expect(field_value("simulation_other_charges")).to eq("200")
    end

    # Ni une gestion déléguée ni une garantie des loyers impayés ne se supposent : la page
    # les propose à zéro, et le bilan d'un meublé au forfait.
    it "proposes nothing for what it cannot deduce, and a flat fee for the accountant" do
      submit("purchase", PURCHASE)
      submit("rental", RENTAL.merge(rental_type: "furnished"))

      get new_simulation_step_path(step: "charges")

      expect(field_value("simulation_management_fees")).to eq("0")
      expect(field_value("simulation_rent_guarantee")).to eq("0")
      expect(field_value("simulation_accounting_fees")).to eq("500")
      expect(field_value("simulation_business_tax")).to eq("400")
    end

    # Hors copropriété, la façade, la toiture et les communs n'incombent à personne d'autre
    # qu'au propriétaire : l'entretien proposé double.
    it "asks a property outside any condominium to carry its own maintenance" do
      submit("property", PROPERTY.merge(surface: "200", condominium: "0"))
      submit("purchase", PURCHASE)
      submit("rental", RENTAL)

      get new_simulation_step_path(step: "charges")

      expect(field_value("simulation_maintenance")).to eq("4000")
      expect(asked_for?("simulation_condominium_fees")).to be(false)
    end

    it "spares a property let unfurnished the charges the furnished regime imposes" do
      submit("purchase", PURCHASE)
      submit("rental", RENTAL)

      get new_simulation_step_path(step: "charges")

      expect(asked_for?("simulation_business_tax")).to be(false)
      expect(asked_for?("simulation_accounting_fees")).to be(false)
      expect(asked_for?("simulation_condominium_fees")).to be(true)
    end

    # Les frais de notaire ne se saisissent pas : la page les calcule d'après le prix, et
    # n'offre donc aucun champ où les taper.
    it "computes the notary fees from the price instead of asking for them" do
      submit("purchase", PURCHASE)

      get new_simulation_step_path(step: "purchase")

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("#simulation_notary_fees")).to be_nil
      expect(doc.at_css("[data-notary-fees-target='amount']").text.gsub(/\s+/, " ").strip)
        .to eq(ActionController::Base.helpers.number_to_currency(16_612).gsub(/\s+/, " "))
    end

    # Vingt ans à 3,5 % : le crédit que la page propose tant que rien n'y a été saisi. La
    # prime d'assurance, elle, se lit sur le capital emprunté : un dix-millième de
    # 211 612 € fait 21,16 € par mois.
    it "proposes twenty years at 3.5 % and a premium on the capital borrowed" do
      submit("purchase", ON_CREDIT)

      get new_simulation_step_path(step: "credit")

      expect(field_value("simulation_loan_rate")).to eq("3.5")
      expect(field_value("simulation_loan_duration_years")).to eq("20")
      expect(field_value("simulation_loan_insurance")).to eq("21.16")
    end

    it "does not overwrite an amount already corrected by hand" do
      submit("purchase", PURCHASE)
      submit("rental", RENTAL.merge(monthly_rent: "990"))

      get new_simulation_step_path(step: "rental")

      expect(field_value("simulation_monthly_rent")).to eq("990")
    end
  end

  describe "a page that refuses what it was given" do
    it "explains in French and writes nothing" do
      expect {
        submit("property", PROPERTY.merge(city: "", surface: "0"))
      }.not_to change(Simulation, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Ville doit être rempli(e)")
      expect(response.body).to include(CGI.escapeHTML("Surface (m²) doit être supérieur à 0"))
      expect(response.body).not_to include("Translation missing")
    end

    # Une page ne juge que ses propres champs : refuser un prix d'achat sur la page du bien
    # rendrait le découpage inutile.
    it "says nothing about the pages that have not been reached" do
      submit("property", PROPERTY.merge(city: ""))

      expect(response.body).not_to include(CGI.escapeHTML("Prix d'achat"))
    end
  end

  describe "reaching a page out of order" do
    it "sends you back to where the draft stopped" do
      get new_simulation_step_path(step: "charges")

      expect(response).to redirect_to(new_simulation_step_path(step: "property"))
    end

    it "lets you back into a page already answered" do
      submit("property", PROPERTY)

      get new_simulation_step_path(step: "property")

      expect(response).to have_http_status(:success)
    end

    it "falls back to the first page when the step does not exist" do
      get new_simulation_step_path(step: "loan")

      expect(response).to redirect_to(new_simulation_step_path(step: "property"))
    end
  end

  describe "the progress bar" do
    it "shows the four pages of a purchase paid outright and marks the one being answered" do
      submit("property", PROPERTY)
      follow_redirect!

      doc = Nokogiri::HTML(response.body)
      steps = doc.css(".wizard-progress .wizard-progress-step")

      expect(steps.size).to eq(4)
      expect(steps.map { |step| step.at_css(".wizard-progress-label").text.strip })
        .not_to include(I18n.t("views.simulations.steps.credit.title"))
      expect(steps.first["class"]).to include("is-done")
      expect(steps[1]["class"]).to include("is-current")
    end

    # La barre ne doit pas annoncer une page qui ne s'ouvrira pas — ni taire celle qui vient
    # de s'ouvrir.
    it "announces the credit page as soon as the purchase declares one" do
      submit("property", PROPERTY)
      submit("purchase", ON_CREDIT)
      follow_redirect!

      doc = Nokogiri::HTML(response.body)
      steps = doc.css(".wizard-progress .wizard-progress-step")

      expect(steps.size).to eq(5)
      expect(steps[2]["class"]).to include("is-current")
      expect(steps[2].at_css(".wizard-progress-label").text.strip)
        .to eq(I18n.t("views.simulations.steps.credit.title"))
    end
  end
end
