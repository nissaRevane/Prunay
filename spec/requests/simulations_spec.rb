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

    # Une simulation que personne n'a nommée se reconnaît à son bien : type, ville, surface.
    it "names each row after the property it describes" do
      create(:simulation, user: user, property_type: "house", city: "Rennes", surface: 62.5)

      get simulations_path

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css(".table tbody tr td a.row-link").text.strip).to eq("Maison à Rennes, 62,5 m²")
    end

    it "carries the name given at the creation when there is one" do
      create(:simulation, user: user, name: "Le studio du port")

      get simulations_path

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css(".table tbody tr td a.row-link").text.strip).to eq("Le studio du port")
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
      other = create(:simulation, user: create(:user), purchase_price: 999_999)

      get simulations_path

      expect(response.body).not_to include(currency(other.total_investment))
    end
  end

  describe "GET /simulations/:id" do
    let(:simulation) do
      create(:simulation, user: user, purchase_date: Date.new(2025, 3, 10), purchase_price: 200_000,
                          initial_works: 20_000, monthly_rent: 1_000, occupancy_months: 11,
                          property_tax: 700, maintenance: 1_000, insurance: 150, other_charges: 150)
    end

    it "returns success" do
      get simulation_path(simulation)
      expect(response).to have_http_status(:success)
    end

    it "renders one row per year of the horizon" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      rows = doc.css(".table-scroll .table tbody tr")

      expect(rows.size).to eq(Simulation::HORIZON_YEARS)
    end

    it "renders the year, its date, its rent, its charges, its cash flow and the capital still immobilized" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      cells = doc.css(".table-scroll .table tbody tr").first.css("td").map { |td| td.text.gsub(/\s+/, " ").strip }

      expect(cells).to eq([
        "1",
        "10 mars 2026 10/03/2026",
        currency(11_000).gsub(/\s+/, " "),
        currency(2_000).gsub(/\s+/, " "),
        currency(9_000).gsub(/\s+/, " "),
        currency(227_612).gsub(/\s+/, " ")
      ])
    end

    # Les frais de notaire ne sont pas un champ : la fiche les calcule d'après le prix et
    # les additionne au capital immobilisé le premier jour.
    it "details the purchase, notary fees included, and totals what it immobilizes" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      section = doc.css(".section").find { |node| node.at_css("h2")&.text&.strip == I18n.t("views.simulations.show.purchase_detail") }

      amounts = section.css(".detail-item").to_h do |item|
        [item.at_css(".detail-label").text.strip, item.at_css(".detail-value").text.gsub(/\s+/, " ").strip]
      end

      expect(amounts).to eq(
        Simulation.human_attribute_name(:purchase_price) => currency(200_000).gsub(/\s+/, " "),
        Simulation.human_attribute_name(:notary_fees) => currency(16_612).gsub(/\s+/, " "),
        Simulation.human_attribute_name(:initial_works) => currency(20_000).gsub(/\s+/, " ")
      )
      expect(section.at_css(".section-total").text.gsub(/\s+/, " ")).to include(currency(236_612).gsub(/\s+/, " "))
    end

    # Une ligne à zéro se lirait comme une charge oubliée : la fiche ne détaille que les
    # charges que le bien se voit demander.
    it "details only the charges the property is asked for" do
      let_unfurnished = create(:simulation, user: user, condominium: false, rental_type: "unfurnished",
                                           property_tax: 700)

      get simulation_path(let_unfurnished)

      doc = Nokogiri::HTML(response.body)
      section = doc.css(".section").find { |node| node.at_css("h2")&.text&.strip == I18n.t("views.simulations.show.charges_detail") }
      labels = section.css(".detail-label").map { |label| label.text.strip }

      expect(labels).to include(Simulation.human_attribute_name(:property_tax))
      expect(labels).not_to include(Simulation.human_attribute_name(:condominium_fees))
      expect(labels).not_to include(Simulation.human_attribute_name(:business_tax))
      expect(labels).not_to include(Simulation.human_attribute_name(:accounting_fees))
    end

    # Un achat comptant n'a pas de tableau d'amortissement, et sa projection n'a donc pas de
    # colonne d'annuités : une colonne à zéro se lirait comme un crédit oublié.
    it "carries neither an amortization tab nor an annuity column without a credit" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("#tab-amortization")).to be_nil
      expect(doc.css(".tabs .tab").size).to eq(2)
      expect(doc.css("#panel-projection thead th").map { |th| th.text.strip })
        .not_to include(I18n.t("views.simulations.show.loan_payments_column"))
    end

    describe "of a purchase financed by a credit" do
      let(:on_credit) do
        create(:simulation, :with_credit, user: user, purchase_date: Date.new(2025, 3, 10),
                                          purchase_price: 200_000, initial_works: 0,
                                          monthly_rent: 1_000, occupancy_months: 11)
      end

      it "opens a third tab on the amortization table, one line per payment" do
        get simulation_path(on_credit)

        doc = Nokogiri::HTML(response.body)
        expect(doc.css(".tabs .tab").size).to eq(3)
        expect(doc.css("#panel-amortization tbody tr").size).to eq(on_credit.loan_duration_months)

        cells = doc.css("#panel-amortization tbody tr").first.css("td").map { |td| td.text.gsub(/\s+/, " ").strip }
        expect(cells.first).to eq("1")
        expect(cells.second).to include("10 avril 2025")
        expect(cells.third).to eq(currency(on_credit.monthly_payment).gsub(/\s+/, " "))
      end

      # L'annuité pèse sur le cash-flow de chaque année où le crédit court.
      it "adds an annuity column to the projection and takes it out of the cash flow" do
        get simulation_path(on_credit)

        doc = Nokogiri::HTML(response.body)
        headers = doc.css("#panel-projection thead th").map { |th| th.text.strip }
        cells = doc.css("#panel-projection tbody tr").first.css("td").map { |td| td.text.gsub(/\s+/, " ").strip }

        expect(headers).to include(I18n.t("views.simulations.show.loan_payments_column"))
        # Année, date, loyers, charges, annuités, cash-flow, capital immobilisé.
        expect(cells[4]).to eq(currency(on_credit.annual_loan_payment).gsub(/\s+/, " "))
        expect(cells[5]).to eq(currency(11_000 - on_credit.annual_loan_payment).gsub(/\s+/, " "))
      end

      # Ce qui est réellement immobilisé le premier jour, c'est l'apport : le capital
      # emprunté se rembourse par les annuités, et le compter deux fois ferait payer le bien
      # deux fois.
      it "details the credit and immobilizes the down payment alone" do
        get simulation_path(on_credit)

        doc = Nokogiri::HTML(response.body)
        section = doc.css(".section").find { |node| node.at_css("h2")&.text&.strip == I18n.t("views.simulations.show.credit_detail") }
        amounts = section.css(".detail-item").to_h do |item|
          [item.at_css(".detail-label").text.strip, item.at_css(".detail-value").text.gsub(/\s+/, " ").strip]
        end

        expect(amounts).to include(
          Simulation.human_attribute_name(:borrowed_capital) => currency(193_224).gsub(/\s+/, " "),
          Simulation.human_attribute_name(:down_payment) => currency(23_388).gsub(/\s+/, " "),
          Simulation.human_attribute_name(:monthly_payment) => currency(on_credit.monthly_payment).gsub(/\s+/, " ")
        )
        expect(section.at_css(".section-total").text.gsub(/\s+/, " ")).to include(currency(23_388).gsub(/\s+/, " "))
      end
    end

    it "does not serve the simulation of another user" do
      other = create(:simulation, user: create(:user))

      get simulation_path(other)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "PATCH /simulations/:id" do
    it "renames the simulation" do
      simulation = create(:simulation, user: user, name: "Le studio du port")

      patch simulation_path(simulation), params: { simulation: { name: "Le deux-pièces du port" } }

      expect(simulation.reload.name).to eq("Le deux-pièces du port")
    end

    # Le formulaire de modification rassemble les cinq pages : la case du crédit y est, et
    # ses conditions avec elle.
    it "turns a purchase paid outright into a purchase financed by a credit" do
      simulation = create(:simulation, user: user, purchase_price: 200_000, initial_works: 0)

      patch simulation_path(simulation), params: {
        simulation: { credit: "1", down_payment: "23388", loan_rate: "3.0", loan_duration_years: "20" }
      }

      expect(simulation.reload).to have_attributes(credit: true, down_payment: 23_388,
                                                   borrowed_capital: 193_224)
    end

    it "updates the simulation" do
      simulation = create(:simulation, user: user, monthly_rent: 800)

      patch simulation_path(simulation), params: { simulation: { monthly_rent: "1000" } }

      expect(response).to redirect_to(simulation)
      expect(simulation.reload.monthly_rent).to eq(1_000)
    end

    # La modification tient sur une seule page : les quatre étapes n'ont de sens que pour
    # qui découvre le formulaire.
    it "edits every page of the creation on a single form" do
      simulation = create(:simulation, user: user)

      get edit_simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      expect(doc.css(".form-fieldset legend").map { |legend| legend.text.strip }).to eq(
        Simulation::STEPS.map { |step| I18n.t("views.simulations.steps.#{step}.title") }
      )
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
