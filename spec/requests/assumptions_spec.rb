require "rails_helper"

RSpec.describe "Assumptions", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /hypotheses/edit" do
    it "opens on what Prunay assumes as long as nothing has been decided" do
      get edit_assumptions_path

      expect(response).to have_http_status(:success)

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("#assumptions_rent_growth_rate")["value"]).to eq("1")
      expect(doc.at_css("#assumptions_property_growth_rate")["value"]).to eq("1")
      expect(doc.at_css("#assumptions_inflation_rate")["value"]).to eq("2")
      options = doc.css("#assumptions_marginal_tax_rate option")
      expect(options.map { |option| option["value"] }).to eq(%w[0 11 30 41 45])
      expect(options.find { |option| option["selected"] }["value"]).to eq("30")
    end

    it "opens on what the user has decided once he has decided it" do
      create(:assumptions, user: user, rent_growth_rate: 3)

      get edit_assumptions_path

      expect(Nokogiri::HTML(response.body).at_css("#assumptions_rent_growth_rate")["value"]).to eq("3")
    end

    it "carries a field for every assumption an account can settle" do
      get edit_assumptions_path

      doc = Nokogiri::HTML(response.body)
      expect(Assumptions::EDITABLE.map { |name| doc.at_css("#assumptions_#{name}") }).to all(be_present)
    end
  end

  describe "PATCH /hypotheses" do
    it "writes the assumptions of a user who had none" do
      expect {
        patch assumptions_path,
              params: { assumptions: { rent_growth_rate: "1.5", property_growth_rate: "2.5",
                                     inflation_rate: "3.5" } }
      }.to change(Assumptions, :count).by(1)

      expect(response).to redirect_to(edit_assumptions_path)
      expect(user.reload.assumptions)
        .to have_attributes(rent_growth_rate: 1.5, property_growth_rate: 2.5, inflation_rate: 3.5)
    end

    it "writes the amounts proposed, the credit and what a resale costs" do
      patch assumptions_path,
            params: { assumptions: { monthly_rent: "900", loan_duration_years: "25",
                                     sale_diagnostics: "600" } }

      expect(user.reload.assumptions)
        .to have_attributes(monthly_rent: 900, loan_duration_years: 25, sale_diagnostics: 600)
    end

    it "corrects those he had already given" do
      create(:assumptions, user: user, inflation_rate: 2)

      expect {
        patch assumptions_path, params: { assumptions: { inflation_rate: "4" } }
      }.not_to change(Assumptions, :count)

      expect(user.reload.assumptions.inflation_rate).to eq(4)
    end

    it "explains in French what it refuses, and writes nothing" do
      patch assumptions_path, params: { assumptions: { rent_growth_rate: "" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("doit être rempli(e)")
      expect(user.reload.assumptions).to be_nil
    end
  end

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

    it "carries one self-saving field per assumption, and one for the discount" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      panel = doc.at_css("#panel-economic_conditions")

      expect(panel.css("form").map { |form| form["action"] }.uniq)
        .to eq([simulation_economic_conditions_path(simulation)])
      expect(panel.css("input[type=submit], button[type=submit]")).to be_empty
      expect(panel.css(".detail-item").size).to eq(Assumptions::ECONOMIC.size + 1)
    end

    it "returns the whole page on that tab once a rate is saved" do
      patch simulation_economic_conditions_path(simulation),
            params: { simulation: { rent_growth_rate: "3" } }, as: :turbo_stream

      expect(response).to have_http_status(:success)
      expect(simulation.reload.rent_growth_rate).to eq(3)

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("turbo-stream")["target"]).to eq("simulation_#{simulation.id}")
      expect(doc.at_css("#panel-economic_conditions")["hidden"]).to be_nil
    end

    it "answers a refused rate with the message alone" do
      patch simulation_economic_conditions_path(simulation),
            params: { simulation: { inflation_rate: "" } }, as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_entity)
      expect(simulation.reload.inflation_rate).to eq(2)

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("turbo-stream")["target"]).to eq("flash")
      expect(doc.at_css(".alert-danger").text).to include("doit être rempli(e)")
    end

    it "carries the tax bracket of the household next to the rates" do
      taxed = create(:simulation, user: user, marginal_tax_rate: 30)

      get simulation_path(taxed)

      doc = Nokogiri::HTML(response.body)
      selected = doc.css("#simulation_marginal_tax_rate option").find { |option| option["selected"] }
      expect(selected["value"]).to eq("30")

      patch simulation_economic_conditions_path(taxed), params: { simulation: { marginal_tax_rate: "41" } }

      expect(taxed.reload.marginal_tax_rate).to eq(41)
    end

    it "carries the discount obtained at the purchase next to the rates" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("#simulation_purchase_discount")).to be_present

      patch simulation_economic_conditions_path(simulation), params: { simulation: { purchase_discount: "15000" } }

      expect(simulation.reload.purchase_discount).to eq(15_000)
    end

    it "refuses a discount that would put the property under its price" do
      patch simulation_economic_conditions_path(simulation), params: { simulation: { purchase_discount: "-1000" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(simulation.reload.purchase_discount).to eq(0)
    end

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

    it "does not correct the simulation of another user" do
      others = create(:simulation, rent_growth_rate: 1)

      patch simulation_economic_conditions_path(others), params: { simulation: { rent_growth_rate: "9" } }

      expect(others.reload.rent_growth_rate).to eq(1)
    end

    it "is left untouched when the general conditions change" do
      simulation

      patch assumptions_path, params: { assumptions: { rent_growth_rate: "9" } }

      expect(simulation.reload.rent_growth_rate).to eq(1)
    end
  end
end
