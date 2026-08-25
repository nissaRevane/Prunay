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

  PROPERTY = { property_type: "apartment", city: "Nantes", surface: "50", condominium: "1" }.freeze
  PURCHASE = { purchase_price: "200000", initial_works: "20000", purchase_date: "2026-01-15" }.freeze
  RENTAL = { monthly_rent: "1000", occupancy_months: "11", rental_type: "unfurnished" }.freeze
  CHARGES = { property_tax: "700", maintenance: "1000", insurance: "150", other_charges: "150" }.freeze

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
        property_tax: 700, maintenance: 1_000, insurance: 150, other_charges: 150
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

    it "keeps what a previous page has already answered" do
      submit("property", PROPERTY)
      submit("purchase", PURCHASE)

      get new_simulation_step_path(step: "property")

      expect(field_value("simulation_city")).to eq("Nantes")
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

    it "estimates every annual charge from the surface" do
      submit("purchase", PURCHASE)
      submit("rental", RENTAL)

      get new_simulation_step_path(step: "charges")

      expect(field_value("simulation_property_tax")).to eq("1400")
      expect(field_value("simulation_maintenance")).to eq("2000")
      expect(field_value("simulation_insurance")).to eq("300")
      expect(field_value("simulation_other_charges")).to eq("200")
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
    it "shows the four pages and marks the one being answered" do
      submit("property", PROPERTY)
      follow_redirect!

      doc = Nokogiri::HTML(response.body)
      steps = doc.css(".wizard-progress .wizard-progress-step")

      expect(steps.size).to eq(Simulation::STEPS.size)
      expect(steps.first["class"]).to include("is-done")
      expect(steps[1]["class"]).to include("is-current")
    end
  end
end
