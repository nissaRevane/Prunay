require "rails_helper"

# Les conditions économiques se règlent à deux endroits : une fois pour toutes les
# simulations à venir, et simulation par simulation dans l'onglet de chacune.
RSpec.describe "Economic conditions", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /conditions-economiques/edit" do
    it "opens on what Prunay assumes as long as nothing has been decided" do
      get edit_economic_conditions_path

      expect(response).to have_http_status(:success)

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("#economic_conditions_rent_growth_rate")["value"]).to eq("1.0")
      expect(doc.at_css("#economic_conditions_property_growth_rate")["value"]).to eq("1.0")
      expect(doc.at_css("#economic_conditions_inflation_rate")["value"]).to eq("2.0")
      # La tranche se choisit dans le barème, et non sur une échelle : cinq options, celle de
      # la plupart des foyers qui investissent étant sélectionnée.
      options = doc.css("#economic_conditions_marginal_tax_rate option")
      expect(options.map { |option| option["value"] }).to eq(%w[0 11 30 41 45])
      expect(options.find { |option| option["selected"] }["value"]).to eq("30")
    end

    it "opens on what the user has decided once he has decided it" do
      create(:economic_conditions, user: user, rent_growth_rate: 3)

      get edit_economic_conditions_path

      expect(Nokogiri::HTML(response.body).at_css("#economic_conditions_rent_growth_rate")["value"]).to eq("3.0")
    end
  end

  describe "PATCH /conditions-economiques" do
    it "writes the conditions of a user who had none" do
      expect {
        patch economic_conditions_path,
              params: { economic_conditions: { rent_growth_rate: "1.5", property_growth_rate: "2.5",
                                               inflation_rate: "3.5" } }
      }.to change(EconomicConditions, :count).by(1)

      expect(response).to redirect_to(edit_economic_conditions_path)
      expect(user.reload.economic_conditions)
        .to have_attributes(rent_growth_rate: 1.5, property_growth_rate: 2.5, inflation_rate: 3.5)
    end

    it "corrects those he had already given" do
      create(:economic_conditions, user: user, inflation_rate: 2)

      expect {
        patch economic_conditions_path, params: { economic_conditions: { inflation_rate: "4" } }
      }.not_to change(EconomicConditions, :count)

      expect(user.reload.economic_conditions.inflation_rate).to eq(4)
    end

    it "explains in French what it refuses, and writes nothing" do
      patch economic_conditions_path, params: { economic_conditions: { rent_growth_rate: "" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("doit être rempli(e)")
      expect(user.reload.economic_conditions).to be_nil
    end
  end

  # Les conditions déjà écrites dans une simulation sont les siennes : les valeurs par défaut
  # ne les rattrapent pas, sans quoi une projection changerait sans que personne n'y touche.
  describe "the conditions of a simulation" do
    let(:simulation) { create(:simulation, user: user, rent_growth_rate: 1, inflation_rate: 2) }

    it "opens in a tab of its own on the simulation page" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("#tab-economic_conditions").text.strip)
        .to eq(I18n.t("views.simulations.show.tab_economic_conditions"))
      expect(doc.at_css("#panel-economic_conditions form")["action"])
        .to eq(simulation_economic_conditions_path(simulation))
      expect(doc.at_css("#simulation_rent_growth_rate")["value"]).to eq("1.0")
    end

    # La tranche marginale se corrige là où se corrige le reste du contexte : c'est elle qui
    # dit ce que l'impôt prend des loyers, et la projection s'en trouve refaite.
    it "carries the tax bracket of the household next to the rates" do
      taxed = create(:simulation, user: user, marginal_tax_rate: 30)

      get simulation_path(taxed)

      doc = Nokogiri::HTML(response.body)
      selected = doc.css("#simulation_marginal_tax_rate option").find { |option| option["selected"] }
      expect(selected["value"]).to eq("30")

      patch simulation_economic_conditions_path(taxed), params: { simulation: { marginal_tax_rate: "41" } }

      expect(taxed.reload.marginal_tax_rate).to eq(41)
    end

    # Une tranche que le barème ne connaît pas n'est pas une hypothèse : c'est une faute.
    it "refuses a bracket the scale does not know" do
      taxed = create(:simulation, user: user, marginal_tax_rate: 30)

      patch simulation_economic_conditions_path(taxed), params: { simulation: { marginal_tax_rate: "25" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(taxed.reload.marginal_tax_rate).to eq(30)
    end

    it "comes back to that tab once corrected" do
      patch simulation_economic_conditions_path(simulation),
            params: { simulation: { rent_growth_rate: "2", property_growth_rate: "3", inflation_rate: "4" } }

      expect(response).to redirect_to(simulation_path(simulation, tab: "economic_conditions"))
      expect(simulation.reload)
        .to have_attributes(rent_growth_rate: 2, property_growth_rate: 3, inflation_rate: 4)
    end

    it "reopens that tab on its error when it refuses what it was given" do
      patch simulation_economic_conditions_path(simulation), params: { simulation: { inflation_rate: "" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(simulation.reload.inflation_rate).to eq(2)

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("#panel-economic_conditions")["hidden"]).to be_nil
      expect(doc.at_css("#panel-parameters")["hidden"]).not_to be_nil
      expect(response.body).to include("doit être rempli(e)")
    end

    # La simulation d'un autre n'est pas la sienne, pas même par ses conditions.
    it "does not correct the simulation of another user" do
      others = create(:simulation, rent_growth_rate: 1)

      patch simulation_economic_conditions_path(others), params: { simulation: { rent_growth_rate: "9" } }

      expect(others.reload.rent_growth_rate).to eq(1)
    end

    # Corriger les conditions par défaut ne doit pas réécrire l'histoire des simulations
    # déjà projetées : chacune porte les siennes.
    it "is left untouched when the general conditions change" do
      simulation

      patch economic_conditions_path, params: { economic_conditions: { rent_growth_rate: "9" } }

      expect(simulation.reload.rent_growth_rate).to eq(1)
    end
  end
end
