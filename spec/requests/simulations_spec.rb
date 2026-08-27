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

    # L'horizon plus la ligne de l'achat : elle ne porte ni loyer ni charge, seulement le
    # capital immobilisé le premier jour.
    it "renders one row per year of the horizon, the purchase date opening the table" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      rows = doc.css("#panel-micro_foncier tbody tr.row-expandable")

      expect(rows.size).to eq(Projection::HORIZON_YEARS + 1)
      expect(rows.first.css("td").map { |td| td.text.gsub(/\s+/, " ").strip }).to eq([
        "0",
        "mar.-2025",
        currency(0).gsub(/\s+/, " "),
        currency(0).gsub(/\s+/, " "),
        currency(236_612).gsub(/\s+/, " ")
      ])
    end

    # Le tableau ne porte que ce qu'on y cherche, et la date s'y lit au mois : une projection
    # par anniversaires n'a que faire du jour. Les charges, l'impôt et les annuités pèsent sur
    # le cash-flow sans colonne à elles — l'onglet des paramètres les détaille.
    it "renders the year, its month, its rent, its cash flow and the capital still immobilized" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      cells = doc.css("#panel-micro_foncier tbody tr.row-expandable")[1].css("td").map { |td| td.text.gsub(/\s+/, " ").strip }

      # 11 000 € de loyers, 2 000 € de charges et 1 324,40 € de prélèvements sociaux.
      expect(cells).to eq([
        "1",
        "mar.-2026",
        currency(11_000).gsub(/\s+/, " "),
        currency(BigDecimal("7675.60")).gsub(/\s+/, " "),
        currency(BigDecimal("228936.40")).gsub(/\s+/, " ")
      ])
    end

    # Ce que le tableau ne montre pas se lit dans la pop-in de l'année : un compte de résultat,
    # du loyer au cash-flow, les charges en négatif et chaque solde derrière ce qui l'a produit.
    it "renders the statement of each year as a dialog, closed until its row is clicked" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      statement = doc.at_css("#panel-micro_foncier dialog#micro_foncier-year-2-statement")
      lines = statement.css(".statement-line").map do |line|
        [line.at_css(".statement-label").text.strip, line.at_css(".statement-amount").text.gsub(/\s+/, " ").strip]
      end

      expect(statement["open"]).to be_nil
      expect(lines).to eq([
        [I18n.t("views.simulations.show.annual_rent_column"), currency(11_000).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.annual_charges_column"), currency(-2_000).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.loan_interest_column"), currency(0).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.pre_tax_result"), currency(9_000).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.annual_taxes_column"), currency(BigDecimal("-1324.40")).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.net_result"), currency(BigDecimal("7675.60")).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.capital_repayment_column"), currency(0).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.cash_flow"), currency(BigDecimal("7675.60")).gsub(/\s+/, " ")]
      ])
      expect(statement.at_css(".statement-footer").text.gsub(/\s+/, " "))
        .to include(currency(200_000).gsub(/\s+/, " "))
    end

    # La provision pour charges ne se déclare pas, et la dépense qu'elle rembourse pas
    # davantage : le tableau ne montre que le loyer hors charges, et la fiche des charges
    # allégées d'autant, une note disant de combien.
    it "shows the rent excluding charges and says discreetly what the provision took off them" do
      let_out = create(:simulation, user: user, monthly_rent: 1_000, monthly_charges: 100,
                                    occupancy_months: 12, condominium: true, condominium_fees: 1_500)

      get simulation_path(let_out)

      doc = Nokogiri::HTML(response.body)
      rent = doc.css("#panel-micro_foncier tbody tr.row-expandable")[1].css("td")[2]
      charges = doc.css("#panel-micro_foncier dialog#micro_foncier-year-1-statement .statement-line")[1]

      expect(rent.text.gsub(/\s+/, " ").strip).to eq(currency(12_000).gsub(/\s+/, " "))
      expect(charges.at_css(".statement-note").text.gsub(/\s+/, " ").strip)
        .to eq(I18n.t("views.simulations.show.provision_deducted", amount: currency(1_200)).gsub(/\s+/, " "))
      expect(charges.at_css(".statement-amount").text.gsub(/\s+/, " ").strip)
        .to eq(currency(-300).gsub(/\s+/, " "))
    end

    # Le foncier réel a son onglet à côté du micro-foncier, et son tableau porte le même
    # horizon : ce sont les deux lectures d'une seule et même projection.
    it "opens a tab of its own on the foncier réel projection" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      rows = doc.css("#panel-foncier_reel tbody tr.row-expandable")

      expect(doc.at_css("#tab-foncier_reel")).not_to be_nil
      expect(rows.size).to eq(Projection::HORIZON_YEARS + 1)
    end

    it "taxes the real result under the foncier réel, the charges deducted" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      cells = doc.css("#panel-foncier_reel tbody tr.row-expandable")[1].css("td").map { |td| td.text.gsub(/\s+/, " ").strip }
      statement = doc.at_css("#panel-foncier_reel dialog#foncier_reel-year-1-statement")
      amounts = statement.css(".statement-line").to_h do |line|
        [line.at_css(".statement-label").text.strip, line.at_css(".statement-amount").text.gsub(/\s+/, " ").strip]
      end

      # 11 000 € de loyers moins 2 000 € de charges réelles : 9 000 € d'assiette, et
      # 1 548 € de prélèvements sociaux, là où le micro-foncier en compte 1 324,40 €.
      expect(cells).to eq([
        "1",
        "mar.-2026",
        currency(11_000).gsub(/\s+/, " "),
        currency(7_452).gsub(/\s+/, " "),
        currency(229_160).gsub(/\s+/, " ")
      ])
      expect(amounts).to include(
        I18n.t("views.simulations.show.annual_taxes_column") => currency(-1_548).gsub(/\s+/, " "),
        I18n.t("views.simulations.show.cash_flow") => currency(7_452).gsub(/\s+/, " ")
      )
    end

    # Tout l'intérêt de la paire : la même année, les mêmes loyers et les mêmes charges, et
    # le seul impôt pour les séparer — le résultat net et le cash-flow n'en découlent.
    it "renders the same year under both regimes, the tax apart" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      statements = Taxation::NAMES.index_with do |regime|
        doc.at_css("#panel-#{regime} dialog##{regime}-year-1-statement").css(".statement-line").to_h do |line|
          [line.at_css(".statement-label").text.strip, line.at_css(".statement-amount").text.gsub(/\s+/, " ").strip]
        end
      end
      taxed = ["annual_taxes_column", "net_result", "cash_flow"].map { |key| I18n.t("views.simulations.show.#{key}") }

      expect(statements[:micro_foncier].except(*taxed)).to eq(statements[:foncier_reel].except(*taxed))
      expect(statements[:micro_foncier].values_at(*taxed))
        .not_to eq(statements[:foncier_reel].values_at(*taxed))
    end

    # À 0 % de barème seuls les prélèvements sociaux pèsent : c'est à 30 %, et à crédit, que les
    # deux régimes s'écartent le plus — les intérêts s'y déduisent vraiment.
    it "separates the regimes furthest when a real bracket meets deducted interest" do
      taxed = create(:simulation, :with_credit, user: user, purchase_date: Date.new(2025, 3, 10),
                                                purchase_price: 200_000, initial_works: 0,
                                                monthly_rent: 1_000, occupancy_months: 11,
                                                property_tax: 700, marginal_tax_rate: 30)

      get simulation_path(taxed)

      doc = Nokogiri::HTML(response.body)
      amounts = Taxation::NAMES.index_with do |regime|
        doc.at_css("#panel-#{regime} dialog##{regime}-year-1-statement").css(".statement-line").to_h do |line|
          [line.at_css(".statement-label").text.strip, line.at_css(".statement-amount").text.gsub(/\s+/, " ").strip]
        end
      end

      # Le forfait impose 7 700 € à 47,2 % ; le réel, les 4 601,21 € que 700 € de charges et
      # 5 698,79 € d'intérêts laissent des 11 000 € de loyers.
      expect(amounts[:micro_foncier]).to include(
        I18n.t("views.simulations.show.annual_taxes_column") => currency(BigDecimal("-3634.40")).gsub(/\s+/, " "),
        I18n.t("views.simulations.show.net_result") => currency(BigDecimal("966.81")).gsub(/\s+/, " "),
        I18n.t("views.simulations.show.cash_flow") => currency(BigDecimal("-6193.84")).gsub(/\s+/, " ")
      )
      expect(amounts[:foncier_reel]).to include(
        I18n.t("views.simulations.show.annual_taxes_column") => currency(BigDecimal("-2171.77")).gsub(/\s+/, " "),
        I18n.t("views.simulations.show.net_result") => currency(BigDecimal("2429.44")).gsub(/\s+/, " "),
        I18n.t("views.simulations.show.cash_flow") => currency(BigDecimal("-4731.21")).gsub(/\s+/, " ")
      )
    end

    # `tab` rouvre l'onglet d'où l'on revient : son panneau est le seul que le serveur montre.
    it "opens the panel that tab names and leaves the others hidden" do
      get simulation_path(simulation, tab: "foncier_reel")

      doc = Nokogiri::HTML(response.body)

      expect(doc.at_css("#panel-foncier_reel")["hidden"]).to be_nil
      expect(doc.at_css("#panel-micro_foncier")["hidden"]).not_to be_nil
      expect(doc.at_css("#tab-foncier_reel")["aria-selected"]).to eq("true")
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

    # Le loyer est ce que la simulation a de plus concret : il se lit sur la fiche, au mois
    # comme un bail l'énonce, et non seulement dans la colonne annuelle de la projection.
    it "details the letting, its rent first" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      section = doc.css(".section").find { |node| node.at_css("h2")&.text&.strip == I18n.t("views.simulations.show.rental_detail") }
      amounts = section.css(".detail-item").to_h do |item|
        [item.at_css(".detail-label").text.strip, item.at_css(".detail-value").text.gsub(/\s+/, " ").strip]
      end

      expect(amounts).to include(
        Simulation.human_attribute_name(:monthly_rent) => currency(1_000).gsub(/\s+/, " "),
        Simulation.human_attribute_name(:monthly_charges) => currency(0).gsub(/\s+/, " "),
        Simulation.human_attribute_name(:occupancy_months) => I18n.t("views.simulations.show.occupancy_value", months: 11)
      )
      # Onze mois loués, et non douze : la vacance se paie.
      expect(section.at_css(".section-total").text.gsub(/\s+/, " ")).to include(currency(11_000).gsub(/\s+/, " "))
    end

    # Une ligne à zéro se lirait comme une charge oubliée : la fiche ne détaille que les
    # charges que le bien se voit demander.
    it "details only the charges the property is asked for" do
      sole_owner = create(:simulation, user: user, condominium: false, property_tax: 700)

      get simulation_path(sole_owner)

      doc = Nokogiri::HTML(response.body)
      section = doc.css(".section").find { |node| node.at_css("h2")&.text&.strip == I18n.t("views.simulations.show.charges_detail") }
      labels = section.css(".detail-label").map { |label| label.text.strip }

      expect(labels).to include(Simulation.human_attribute_name(:property_tax))
      expect(labels).not_to include(Simulation.human_attribute_name(:condominium_fees))
    end

    # Un achat comptant n'a rien à amortir : l'onglet du tableau ne s'ouvre pas.
    it "carries no amortization tab without a credit" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("#tab-amortization")).to be_nil
      expect(doc.css(".tabs .tab").size).to eq(4)
    end

    describe "of a purchase financed by a credit" do
      let(:on_credit) do
        create(:simulation, :with_credit, user: user, purchase_date: Date.new(2025, 3, 10),
                                          purchase_price: 200_000, initial_works: 0,
                                          loan_insurance: 19.32, loan_guarantee_fees: 3_220,
                                          loan_application_fees: 1_932,
                                          monthly_rent: 1_000, occupancy_months: 11)
      end

      it "opens a tab of its own on the amortization table, one line per payment" do
        get simulation_path(on_credit)

        doc = Nokogiri::HTML(response.body)
        expect(doc.css(".tabs .tab").size).to eq(5)
        expect(doc.css("#panel-amortization tbody tr").size).to eq(on_credit.loan.duration_months)

        # Échéance, date, mensualité, intérêts, capital remboursé, assurance, capital restant
        # dû : la mensualité est ce que la banque prélève, prime comprise.
        cells = doc.css("#panel-amortization tbody tr").first.css("td").map { |td| td.text.gsub(/\s+/, " ").strip }
        expect(cells.first).to eq("1")
        expect(cells.second).to include("05 avril 2025")
        expect(cells.third).to eq(currency(on_credit.loan.total_monthly_payment).gsub(/\s+/, " "))
        expect(cells[5]).to eq(currency(19.32).gsub(/\s+/, " "))
      end

      # L'annuité n'a pas de colonne, mais elle pèse sur le cash-flow de chaque année où le
      # crédit court : c'est là qu'elle se lit.
      it "takes the annuity out of the cash flow without giving it a column" do
        get simulation_path(on_credit)

        doc = Nokogiri::HTML(response.body)
        headers = doc.css("#panel-micro_foncier thead th").map { |th| th.text.strip }
        cells = doc.css("#panel-micro_foncier tbody tr.row-expandable")[1].css("td").map { |td| td.text.gsub(/\s+/, " ").strip }

        # Année, date, loyers, cash-flow, capital immobilisé.
        expect(headers.size).to eq(5)
        expect(cells.third).to eq(currency(11_000).gsub(/\s+/, " "))
        expect(cells.fourth)
          .to eq(currency(11_000 - on_credit.annual_taxes - on_credit.loan.annual_payment).gsub(/\s+/, " "))
      end

      # L'annuité se coupe en deux sur le compte de résultat : les intérêts et la prime sont
      # une charge, le capital rendu ne l'est pas — il passe sous le résultat net.
      it "splits the annuity between the interest it charges and the capital it gives back" do
        get simulation_path(on_credit)

        doc = Nokogiri::HTML(response.body)
        statement = doc.at_css("#panel-micro_foncier dialog#micro_foncier-year-1-statement")
        amounts = statement.css(".statement-line").to_h do |line|
          [line.at_css(".statement-label").text.strip, line.at_css(".statement-amount").text.gsub(/\s+/, " ").strip]
        end
        year = on_credit.projection(:micro_foncier).years[1]

        expect(year.loan_interest + year.capital_repayment).to eq(on_credit.loan.annual_payment)
        expect(amounts).to include(
          I18n.t("views.simulations.show.loan_interest_column") => currency(-year.loan_interest).gsub(/\s+/, " "),
          I18n.t("views.simulations.show.capital_repayment_column") => currency(-year.capital_repayment).gsub(/\s+/, " "),
          I18n.t("views.simulations.show.cash_flow") => currency(year.cash_flow).gsub(/\s+/, " ")
        )
      end

      # Ce qui est réellement immobilisé le premier jour, c'est l'apport et les frais que la
      # signature coûte : le capital emprunté, lui, se rembourse par les annuités, et le
      # compter deux fois ferait payer le bien deux fois.
      it "details the credit and immobilizes the down payment and the fees of the signature" do
        get simulation_path(on_credit)

        doc = Nokogiri::HTML(response.body)
        section = doc.css(".section").find { |node| node.at_css("h2")&.text&.strip == I18n.t("views.simulations.show.credit_detail") }
        amounts = section.css(".detail-item").to_h do |item|
          [item.at_css(".detail-label").text.strip, item.at_css(".detail-value").text.gsub(/\s+/, " ").strip]
        end

        expect(amounts).to include(
          Simulation.human_attribute_name(:borrowed_capital) => currency(193_224).gsub(/\s+/, " "),
          Simulation.human_attribute_name(:down_payment) => currency(23_388).gsub(/\s+/, " "),
          Simulation.human_attribute_name(:monthly_payment) => currency(on_credit.loan.monthly_payment).gsub(/\s+/, " "),
          Simulation.human_attribute_name(:loan_insurance) => currency(19.32).gsub(/\s+/, " "),
          Simulation.human_attribute_name(:loan_guarantee_fees) => currency(3_220).gsub(/\s+/, " "),
          Simulation.human_attribute_name(:loan_application_fees) => currency(1_932).gsub(/\s+/, " "),
          Simulation.human_attribute_name(:total_monthly_payment) =>
            currency(on_credit.loan.total_monthly_payment).gsub(/\s+/, " ")
        )
        # 23 388 d'apport, 3 220 de cautionnement et 1 932 de frais de dossier.
        expect(section.at_css(".section-total").text.gsub(/\s+/, " ")).to include(currency(28_540).gsub(/\s+/, " "))
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
        Simulation::Step::NAMES.map { |step| I18n.t("views.simulations.steps.#{step}.title") }
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
    # La marque mène à la liste : le menu ne porte que ce qu'elle ne mène pas déjà, soit les
    # conditions économiques par défaut, et rien d'autre tant qu'il n'y a rien d'autre à voir.
    it "carries the general settings alone in the top menu of a signed-in user" do
      get simulations_path

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css(".navbar-logo")["href"]).to eq(root_path)
      expect(doc.css(".navbar-links .nav-link").map { |link| link["href"] }).to eq([edit_economic_conditions_path])
      expect(doc.at_css(".nav-user-name")["href"]).to eq(account_path)
      expect(doc.at_css(".nav-user-name").text).to eq(user.full_name)
    end
  end
end
