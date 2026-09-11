require "rails_helper"

# La création rapide : une page, cinq réponses, une simulation complète en base.
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

    it "offers the detailed course as a way out" do
      get new_express_simulation_path

      expect(response.body).to include(new_simulation_path)
    end

    # L'accueil d'un connecté : le formulaire, et de quoi rouvrir les deux derniers biens.
    it "shows the two most recent purchases and the way to the whole list" do
      create(:simulation, user: user, city: "Rennes", purchase_date: Date.new(2024, 3, 1))
      create(:simulation, user: user, city: "Nantes", purchase_date: Date.new(2026, 1, 15))
      create(:simulation, user: user, city: "Brest", purchase_date: Date.new(2025, 7, 9))

      get root_path

      doc = Nokogiri::HTML(response.body)
      cards = doc.css(".recent-simulations .simulation-card .simulation-card-link")

      expect(cards.map { |link| link.text.strip }).to eq(["🏢 Nante-50", "🏢 Brest-50"])
      expect(doc.at_css(".recent-simulations a[href='#{simulations_path}']")).not_to be_nil
    end

    it "leaves the recent section out when nothing has been simulated yet" do
      get root_path

      expect(Nokogiri::HTML(response.body).at_css(".recent-simulations")).to be_nil
    end
  end

  describe "POST /simulations/rapide" do
    it "creates the simulation at once and opens it" do
      expect { post express_simulations_path, params: { simulation: ANSWERS } }
        .to change(user.simulations, :count).by(1)

      expect(response).to redirect_to(user.simulations.last)
    end

    # Les défauts se posent en base, sans qu'aucune page ne les ait demandés.
    it "completes the answers with the usual defaults" do
      post express_simulations_path, params: { simulation: ANSWERS }

      expect(user.simulations.last).to have_attributes(
        credit: true, initial_works: 0, down_payment: 21_660,
        loan_rate: BigDecimal("3.6"), loan_duration_years: 20, occupancy_months: 11,
        property_tax: 700, furniture: 2_110
      )
    end

    # Les conditions économiques ne se demandent pas plus ici que dans l'assistant.
    it "inherits the economic conditions of the user" do
      EconomicConditions.for(user).update!(rent_growth_rate: 1.5, property_growth_rate: 2.5,
                                          inflation_rate: 3)

      post express_simulations_path, params: { simulation: ANSWERS }

      expect(user.simulations.last).to have_attributes(rent_growth_rate: 1.5, property_growth_rate: 2.5,
                                                       inflation_rate: 3)
    end

    it "reopens the form when an answer is missing" do
      expect { post express_simulations_path, params: { simulation: ANSWERS.merge(surface: "") } }
        .not_to change(user.simulations, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
