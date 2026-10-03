require "rails_helper"

RSpec.describe "Express simulations", type: :request do
  let(:user) { create(:user) }

  ANSWERS = { property_type: "apartment", city: "Nantes", surface: "50",
              purchase_price: "200000", monthly_rent: "800" }.freeze

  before { sign_in user }

  describe "GET /simulations/rapide" do
    it "asks the five answers and nothing else" do
      get new_express_simulation_path

      doc = Nokogiri::HTML(response.body)
      expect(doc.css("input, select").map { |field| field["id"] }.compact.grep(/^simulation_/))
        .to eq(%w[simulation_property_type simulation_city simulation_surface
                  simulation_purchase_price simulation_monthly_rent])
    end

    it "wires the rent field to the market without asking for a click" do
      get new_express_simulation_path

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("form.form")["data-rent-estimate-url-value"]).to eq(express_simulation_rent_reference_path)
      expect(doc.at_css("#simulation_monthly_rent")["data-rent-estimate-target"]).to eq("rent")
      expect(doc.at_css("turbo-frame#rent_reference")["data-rent-estimate-target"]).to eq("frame")
    end

    it "lets the rent be left empty, the estimate standing in for it" do
      get new_express_simulation_path

      rent = Nokogiri::HTML(response.body).at_css("#simulation_monthly_rent")
      expect(rent["required"]).to be_nil
      expect(rent["placeholder"]).to eq("Estimé")
    end

    it "offers the detailed course as a way out" do
      get new_express_simulation_path

      expect(response.body).to include(new_simulation_path)
    end

    it "shows the most recent purchase and the way to the whole list" do
      create(:simulation, user: user, city: "Rennes", purchase_date: Date.new(2024, 3, 1))
      create(:simulation, user: user, city: "Nantes", purchase_date: Date.new(2026, 1, 15))
      create(:simulation, user: user, city: "Brest", purchase_date: Date.new(2025, 7, 9))

      get root_path

      doc = Nokogiri::HTML(response.body)
      cards = doc.css(".recent-simulations .simulation-card .panel-link-target")

      expect(cards.map { |link| link.text.strip }).to eq(["🏢 Nante-50"])
      expect(doc.at_css(".recent-simulations-all")["href"]).to eq(simulations_path)
    end

    it "leaves the recent section out when nothing has been simulated yet" do
      get root_path

      expect(Nokogiri::HTML(response.body).at_css(".recent-simulations")).to be_nil
    end
  end

  describe "GET /simulations/rapide/loyer" do
    it "reads the market of the city and carries the amount it proposes" do
      create(:assumptions, user: user, monthly_charges: 50)

      get express_simulation_rent_reference_path(property_type: "apartment", city: "Orléans", surface: "30")

      rate = Nokogiri::HTML(response.body).at_css(".form-reference-rate a")
      expect(rate.text).to eq("14,75 €/m²")
      expect(rate["href"]).to eq(RentReference::SOURCE_URL)
      expect(Nokogiri::HTML(response.body).at_css("[data-rent-estimate-placeholder]")["data-rent-estimate-placeholder"])
        .to eq("≈ 393 €")
    end

    it "falls back on the account's reference for a commune the barometer does not cover" do
      get express_simulation_rent_reference_path(property_type: "apartment", city: "Prunay-le-Temple", surface: "50")

      expect(response.body).to include("Pas de données pour cette commune, saisissez le loyer manuellement.")
      expect(Nokogiri::HTML(response.body).at_css("[data-rent-estimate-placeholder]")["data-rent-estimate-placeholder"])
        .to eq("≈ 650 €")
    end

    it "proposes for a building the rents of its lots: 2 × 650 × √(35/50), rounded to 540" do
      get express_simulation_rent_reference_path(property_type: "building", city: "Nantes", surface: "70")

      expect(Nokogiri::HTML(response.body).at_css("[data-rent-estimate-placeholder]")["data-rent-estimate-placeholder"])
        .to eq("≈ 1 080 €")
    end

    it "says nothing at all while the city is still to be typed" do
      get express_simulation_rent_reference_path(property_type: "apartment", city: "", surface: "30")

      expect(Nokogiri::HTML(response.body).at_css("p")).to be_nil
    end
  end

  describe "POST /simulations/rapide" do
    it "creates the simulation at once and opens it" do
      expect { post express_simulations_path, params: { simulation: ANSWERS } }
        .to change(user.simulations, :count).by(1)

      expect(response).to redirect_to(user.simulations.last)
    end

    it "takes the proposed rent when the field is left empty: 14,75 €/m² on 30 m² less 50 € of charges" do
      create(:assumptions, user: user, monthly_charges: 50)

      post express_simulations_path,
           params: { simulation: ANSWERS.merge(city: "Orléans", surface: "30", monthly_rent: "") }

      expect(user.simulations.last).to have_attributes(monthly_rent: 393, monthly_charges: 50)
    end

    it "keeps the rent typed rather than the market's" do
      post express_simulations_path, params: { simulation: ANSWERS.merge(city: "Orléans", surface: "30") }

      expect(user.simulations.last.monthly_rent).to eq(800)
    end

    it "completes the answers with the usual defaults" do
      post express_simulations_path, params: { simulation: ANSWERS }

      expect(user.simulations.last).to have_attributes(
        credit: true, initial_works: 0, down_payment: 21_660,
        loan_rate: BigDecimal("3.6"), loan_duration_years: 20, occupancy_months: 11,
        property_tax: 700, furniture: 2_110
      )
    end

    it "divides a building into lots: 380 m² into 6 lots of 50 and one of 80" do
      post express_simulations_path,
           params: { simulation: ANSWERS.merge(property_type: "building", surface: "380", monthly_rent: "1900") }

      expect(user.simulations.last.lots.map { |lot| lot.values_at("surface", "monthly_rent") })
        .to eq([*Array.new(6, %w[50 250]), %w[80 400]])
    end

    it "inherits the economic conditions of the user" do
      Assumptions.for(user).update!(rent_growth_rate: 1.5, property_growth_rate: 2.5, inflation_rate: 3)

      post express_simulations_path, params: { simulation: ANSWERS }

      expect(user.simulations.last).to have_attributes(rent_growth_rate: 1.5, property_growth_rate: 2.5,
                                                       inflation_rate: 3)
    end

    it "sends a turbo stream out of the frame when the pop-in asked" do
      post express_simulations_path, params: { simulation: ANSWERS }, as: :turbo_stream

      expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
      expect(Nokogiri::HTML(response.body).at_css("turbo-stream[action=redirect]")["target"])
        .to eq(simulation_path(user.simulations.last))
    end

    it "keeps the errors in the frame rather than reopening the home page" do
      post express_simulations_path, params: { simulation: ANSWERS.merge(surface: "") }, as: :turbo_stream

      expect(response.media_type).to eq("text/html")
      expect(Nokogiri::HTML(response.body).at_css("turbo-frame#express_form .alert-danger")).to be_present
    end

    it "reopens the form when an answer is missing" do
      expect { post express_simulations_path, params: { simulation: ANSWERS.merge(surface: "") } }
        .not_to change(user.simulations, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
