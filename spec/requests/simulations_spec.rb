require "rails_helper"

RSpec.describe "Simulations", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  def currency(amount)
    ActionController::Base.helpers.number_to_currency(amount)
  end

  describe "GET /simulations" do
    it "returns success" do
      get simulations_path
      expect(response).to have_http_status(:success)
    end

    # La liste EST l'accueil d'un utilisateur connecté : il n'y a pas de tableau de bord
    # au-dessus d'elle (voir la contrainte `authenticated :user` des routes).
    it "is what the root serves to a signed-in user" do
      get root_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("views.simulations.index.title"))
    end

    it "groups simulations by purchase year in an accordion" do
      create(:simulation, user: user, purchase_date: Date.new(2025, 12, 31))
      create(:simulation, user: user, purchase_date: Date.new(2025, 6, 30))
      create(:simulation, user: user, purchase_date: Date.new(2024, 12, 31))

      get simulations_path

      doc = Nokogiri::HTML(response.body)
      items = doc.css(".simulations-accordion .accordion-item")

      expect(items.map { |item| item.at_css(".accordion-year")&.text&.strip }).to eq(["2025", "2024"])
      expect(items.first["open"]).not_to be_nil
      expect(items.drop(1).map { |item| item["open"] }).to all(be_nil)
      expect(items.first.at_css(".badge")&.text&.strip).to eq("2")
    end

    it "links the row cells to the simulation instead of a dedicated button" do
      simulation = create(:simulation, user: user)

      get simulations_path

      doc = Nokogiri::HTML(response.body)
      row = doc.at_css(".table tbody tr")

      row_links = row.css("a.row-link")
      expect(row_links).not_to be_empty
      expect(row_links.map { |link| link["href"] }).to all(eq(simulation_path(simulation)))
      expect(doc.at_css(".table-actions a.btn-primary")).to be_nil
    end

    it "says plainly when there is nothing to list" do
      get simulations_path

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css(".empty-state").text.strip).to eq(I18n.t("views.simulations.index.empty"))
    end

    it "ignores the simulations of another user" do
      create(:simulation, user: create(:user), purchase_price: 999_999)

      get simulations_path

      expect(response.body).not_to include(currency(999_999))
    end
  end

  describe "GET /simulations/:id" do
    let(:simulation) do
      create(:simulation, user: user, purchase_date: Date.new(2025, 3, 10), purchase_price: 200_000, monthly_rent: 800)
    end

    it "returns success" do
      get simulation_path(simulation)
      expect(response).to have_http_status(:success)
    end

    it "renders one row per year of the horizon" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      rows = doc.css(".section .table tbody tr")

      expect(rows.size).to eq(Simulation::HORIZON_YEARS)
    end

    it "renders the year, its date, its rent, its cash flow and the capital still immobilized" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      cells = doc.css(".section .table tbody tr").first.css("td").map { |td| td.text.gsub(/\s+/, " ").strip }

      expect(cells).to eq([
        "1",
        "10 mars 2026 10/03/2026",
        currency(9_600).gsub(/\s+/, " "),
        currency(9_600).gsub(/\s+/, " "),
        currency(190_400).gsub(/\s+/, " ")
      ])
    end

    it "does not serve the simulation of another user" do
      other = create(:simulation, user: create(:user))

      get simulation_path(other)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /simulations" do
    it "creates a new simulation" do
      expect {
        post simulations_path, params: { simulation: { purchase_date: "2025-03-10", purchase_price: "200000", monthly_rent: "800" } }
      }.to change(Simulation, :count).by(1)

      expect(response).to redirect_to(Simulation.last)
    end

    it "explains in French why a price of zero is refused" do
      expect {
        post simulations_path, params: { simulation: { purchase_date: "2025-03-10", purchase_price: "0", monthly_rent: "800" } }
      }.not_to change(Simulation, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(CGI.escapeHTML("Prix d'achat doit être supérieur à 0"))
      expect(response.body).not_to include("Translation missing")
    end
  end

  describe "PATCH /simulations/:id" do
    it "updates the simulation" do
      simulation = create(:simulation, user: user, monthly_rent: 800)

      patch simulation_path(simulation), params: { simulation: { monthly_rent: "1000" } }

      expect(response).to redirect_to(simulation)
      expect(simulation.reload.monthly_rent).to eq(1_000)
    end
  end

  describe "DELETE /simulations/:id" do
    it "destroys the simulation" do
      simulation = create(:simulation, user: user)

      expect {
        delete simulation_path(simulation)
      }.to change(Simulation, :count).by(-1)

      expect(response).to redirect_to(simulations_path)
    end
  end

  describe "the navigation shell" do
    # Il n'y a qu'une page à voir : la marque y mène, et un menu qui répéterait ce lien
    # n'aurait rien à dire de plus.
    it "carries no top menu for a signed-in user" do
      get simulations_path

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css(".navbar-logo")["href"]).to eq(root_path)
      expect(doc.css(".navbar-links .nav-link")).to be_empty
      expect(doc.at_css(".nav-user-name")["href"]).to eq(account_path)
      expect(doc.at_css(".nav-user-name").text).to eq(user.full_name)
    end
  end
end
