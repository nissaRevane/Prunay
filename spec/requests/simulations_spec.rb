require "rails_helper"

RSpec.describe "Simulations", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  def currency(amount, **options)
    ActionController::Base.helpers.number_to_currency(amount, **options)
  end

  def percentage(rate)
    ActionController::Base.helpers.number_to_percentage(rate, precision: 2, strip_insignificant_zeros: true)
  end

  def return_percentage(rate)
    ActionController::Base.helpers.number_to_percentage(rate, precision: 1)
  end

  # La fiche d'une année ne vit plus dans la page : elle se demande, et le serveur ne rend qu'elle.
  def statement_doc(simulation, regime, year)
    get statement_simulation_path(simulation, regime: regime, year: year)

    Nokogiri::HTML(response.body)
  end

  describe "GET /simulations" do
    it "returns success" do
      get simulations_path
      expect(response).to have_http_status(:success)
    end

    # Le dernier bien acheté d'abord, quel que soit son taux.
    it "lays the cards out most recent purchase first" do
      create(:simulation, user: user, city: "Rennes", purchase_date: Date.new(2024, 3, 1))
      create(:simulation, user: user, city: "Nantes", purchase_date: Date.new(2026, 1, 15))
      create(:simulation, user: user, city: "Brest", purchase_date: Date.new(2025, 7, 9))

      get simulations_path

      doc = Nokogiri::HTML(response.body)
      cities = doc.css(".simulation-grid .simulation-card .simulation-card-link").map { |link| link.text.strip }

      expect(cities).to eq(["🏢 Nante-50", "🏢 Brest-50", "🏢 Renne-50"])
    end

    # Une simulation se reconnaît à son bien : son type, sa ville et sa surface.
    it "names each card after the property it describes" do
      simulation = create(:simulation, user: user, property_type: "house", city: "Rennes", surface: 62.5)

      get simulations_path

      doc = Nokogiri::HTML(response.body)
      link = doc.at_css(".simulation-card .simulation-card-link")

      expect(link.text.strip).to eq("🏠 Renne-63")
      expect(link["href"]).to eq(simulation_path(simulation))
    end

    # 4,04 % au LMNP revendu la trentième année, contre 3,96 au micro-BIC, 3,75 au micro-foncier et
    # 3,51 au foncier réel : la carte annonce le meilleur des quatre régimes, et l'année qui le donne.
    it "announces the best rate across every regime and every resale year" do
      create(:simulation, user: user, purchase_price: 200_000, monthly_rent: 800,
                          purchase_date: Date.new(2025, 1, 15))

      get simulations_path

      doc = Nokogiri::HTML(response.body)

      expect(doc.at_css(".simulation-card-header .simulation-card-rate").text.strip).to eq(return_percentage(4))
      expect(doc.at_css(".simulation-card-exit").text.gsub(/\s+/, " ").strip).to eq(
        I18n.t("views.simulations.index.best_exit", date: 2055, year: 30)
      )
    end

    # Les trois chiffres se lisent sous le même régime : il se nomme une fois, devant la revente,
    # et celle-ci ne le reprend pas — elle n'en cadrait qu'un tiers.
    it "names the winning regime once, above the figures it frames" do
      create(:simulation, user: user, purchase_price: 200_000, monthly_rent: 800)

      get simulations_path

      doc = Nokogiri::HTML(response.body)
      regime = I18n.t("views.simulations.show.tab_lmnp")

      expect(doc.at_css(".simulation-card-return .simulation-card-regime").text.strip).to eq(
        I18n.t("views.simulations.index.under_regime", regime: regime)
      )
      expect(doc.at_css(".simulation-card-exit").text).not_to include(regime)
    end

    # 216 612 € engagés le premier jour et 9 070,19 € la première année pleine, soit 755,85 € par
    # mois — l'euro près, la carte se lisant d'un coup d'œil et non à la décimale.
    it "shows what the winning regime asks up front and leaves each month" do
      create(:simulation, user: user, purchase_price: 200_000, monthly_rent: 800)

      get simulations_path

      doc = Nokogiri::HTML(response.body)
      figures = doc.css(".simulation-card-figure dd").map { |cell| cell.text.gsub(/\s+/, " ").strip }

      expect(figures).to eq([
        currency(216_612, precision: 0).gsub(/\s+/, " "),
        currency(756, precision: 0).gsub(/\s+/, " ")
      ])
    end

    # La date d'achat situe l'horizon et se lit à côté du nom ; l'adresse, quand elle est saisie,
    # tient la ligne suivante à elle seule.
    it "carries the purchase date beside the name, and the address below it" do
      create(:simulation, user: user, purchase_date: Date.new(2026, 6, 30), address: "14 rue du Beau Laurier")

      get simulations_path

      doc = Nokogiri::HTML(response.body)

      expect(doc.at_css(".simulation-card-title .simulation-card-date").text.strip).to eq(
        I18n.l(Date.new(2026, 6, 30), format: :month_year)
      )
      expect(doc.at_css(".simulation-card-meta .simulation-card-address").text.strip).to eq("14 rue du Beau Laurier")
    end

    # Sans adresse, la ligne qui la portait ne se rend pas : elle aurait coûté sa hauteur pour rien.
    it "drops the address line of a property that has none" do
      create(:simulation, user: user, address: nil)

      get simulations_path

      expect(Nokogiri::HTML(response.body).at_css(".simulation-card-meta")).to be_nil
    end

    # On ne modifie rien depuis la liste : la fiche corrige chaque valeur d'un clic. Reste la
    # corbeille, en tête de carte, hors du lien qui couvre le reste.
    it "carries the delete button alone, in the card header" do
      simulation = create(:simulation, user: user)

      get simulations_path

      doc = Nokogiri::HTML(response.body)
      removal = doc.at_css(".simulation-card-header form.button_to")

      expect(doc.css("a[href='#{edit_simulation_path(simulation)}']")).to be_empty
      expect(removal["action"]).to eq(simulation_path(simulation))
      expect(removal.at_css("input[name=_method]")["value"]).to eq("delete")
      expect(removal.at_css("button")["aria-label"]).to eq(I18n.t("views.simulations.index.destroy"))
    end

    # Le plus ne dit rien de lui-même : l'action garde son libellé pour qui ne voit pas l'écran.
    it "shrinks the new-simulation label to a plus without losing it" do
      get simulations_path

      doc = Nokogiri::HTML(response.body)
      action = doc.at_css(".page-header a.btn-primary")

      expect(action["aria-label"]).to eq(I18n.t("views.simulations.index.new"))
      expect(action.at_css(".hide-on-mobile").text.strip).to eq(I18n.t("views.simulations.index.new"))
      expect(action.at_css(".show-on-mobile").text.strip).to eq("+")
    end

    it "says plainly when there is nothing to list" do
      get simulations_path

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css(".empty-state").text.strip).to eq(I18n.t("views.simulations.index.empty"))
    end

    it "ignores the simulations of another user" do
      create(:simulation, user: create(:user), purchase_price: 999_999)

      get simulations_path

      doc = Nokogiri::HTML(response.body)
      expect(doc.css(".simulation-card")).to be_empty
      expect(doc.at_css(".empty-state")).to be_present
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

    # L'horizon plus la ligne de l'achat, qui ne porte que le capital immobilisé le premier jour.
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
        currency(236_612).gsub(/\s+/, " "),
        I18n.t("views.simulations.show.no_internal_rate_of_return")
      ])
    end

    # Charges, impôt et annuités pèsent sur le cash-flow sans colonne à elles.
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
        currency(BigDecimal("228936.40")).gsub(/\s+/, " "),
        return_percentage(BigDecimal("-12.6")).gsub(/\s+/, " ")
      ])
    end

    # La pop-in de l'année porte le compte de résultat, du loyer au cash-flow.
    it "renders the statement of each year as a dialog, closed until its row is clicked" do
      doc = statement_doc(simulation, :micro_foncier, 2)
      statement = doc.at_css("dialog#micro_foncier-year-2-statement")
      lines = statement.css("#micro_foncier-year-2-result .statement-line").map do |line|
        [line.at_css(".statement-label").text.strip, line.at_css(".statement-amount").text.gsub(/\s+/, " ").strip]
      end

      expect(statement["open"]).to be_nil
      expect(lines).to eq([
        [I18n.t("views.simulations.show.annual_rent_column"), currency(11_000).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.annual_charges_column"), currency(-2_000).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.loan_interest_column"), currency(0).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.pre_tax_result"), currency(9_000).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.income_tax_column"), currency(BigDecimal("-1324.40")).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.net_result"), currency(BigDecimal("7675.60")).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.capital_repayment_column"), currency(0).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.cash_flow"), currency(BigDecimal("7675.60")).gsub(/\s+/, " ")]
      ])
      # La valeur du bien n'est ni un produit ni une charge : elle ne figure pas au compte de résultat.
      result = statement.at_css("#micro_foncier-year-2-result").text.gsub(/\s+/, " ")
      expect(result).not_to include(currency(200_000).gsub(/\s+/, " "))
    end

    # On passe d'une année à l'autre sans refermer la fiche, sauf aux deux bouts de la projection.
    it "offers a step to each neighbouring year, disabled at both ends of the projection" do
      steps = ->(year) do
        statement_doc(simulation, :micro_foncier, year).css(".statement-step").map do |step|
          [step["data-projection-step-param"], step["disabled"]]
        end
      end

      expect(steps.call(0)).to eq([["-1", "disabled"], ["1", nil]])
      expect(steps.call(15)).to eq([["-1", nil], ["1", nil]])
      expect(steps.call(Projection::HORIZON_YEARS)).to eq([["-1", nil], ["1", "disabled"]])
    end

    # Le bien vaut toujours 200 000 € : la revente ne doit aucun impôt, mais 900 € de diagnostics et de remise en état.
    it "simulates a sale from the same statement, behind a tab of its own" do
      doc = statement_doc(simulation, :micro_foncier, 2)
      sale = doc.at_css("dialog#micro_foncier-year-2-statement #micro_foncier-year-2-sale")
      lines = sale.css(".statement-line").map do |line|
        [line.at_css(".statement-label").text.strip.lines.first.strip,
         line.at_css(".statement-amount").text.gsub(/\s+/, " ").strip]
      end

      expect(sale["hidden"]).not_to be_nil
      expect(lines).to eq([
        [I18n.t("views.simulations.show.sale_property_value"), currency(200_000).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.sale_costs"), currency(-900).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.sale_capital_gain_tax"), currency(0).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.remaining_capital"), currency(0).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.sale_early_repayment_fee"), currency(0).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.sale_proceeds"), currency(199_100).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.immobilized_capital"), currency(BigDecimal("-221260.80")).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.sale_profit"), currency(BigDecimal("-22160.80")).gsub(/\s+/, " ")]
      ])
    end

    # Le détail se demande : replié sous chaque ligne, il en porte le calcul poste par poste.
    it "folds the calculation of each line under it, hidden until the detail is asked for" do
      let_out = create(:simulation, user: user, monthly_rent: 1_000, monthly_charges: 100, occupancy_months: 12,
                                    condominium_fees: 1_500, property_tax: 800,
                                    marginal_tax_rate: 30)

      doc = statement_doc(let_out, :micro_foncier, 1)
      result = doc.at_css("#micro_foncier-year-1-result")
      details = result.css(".statement-detail")
      lines = details.css(".statement-detail-line").map do |line|
        [line.at_css(".statement-detail-label").text.strip,
         line.at_css(".statement-amount").text.gsub(/\s+/, " ").strip]
      end

      expect(details.map { |detail| detail["hidden"] }).to all(be_truthy)
      # 12 000 € de loyers et 1 200 € de provision ; 2 300 € de charges dont la provision rembourse 1 200 €.
      # Micro-foncier : 30 % d'abattement, 8 400 € imposables, 30 % de TMI et 17,2 % de prélèvements sociaux.
      expect(lines).to eq([
        [I18n.t("views.simulations.show.detail_rent_excluding_charges", amount: currency(1_000), months: "12"),
         currency(12_000).gsub(/\s+/, " ")],
        [Simulation.human_attribute_name(:property_tax), currency(-800).gsub(/\s+/, " ")],
        [Simulation.human_attribute_name(:condominium_fees), currency(-1_500).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.detail_provision_repaid"), currency(1_200).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.detail_receipts"), currency(12_000).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.detail_allowance", rate: percentage(30)), currency(-3_600).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.detail_taxable_income"), currency(8_400).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.detail_income_tax", rate: percentage(30)), currency(-2_520).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.detail_social_charges", rate: percentage(BigDecimal("17.2"))),
         currency(BigDecimal("-1444.80")).gsub(/\s+/, " ")]
      ])
    end

    # Le LMNP se lit dans son détail : ce qu'il paie vraiment, puis l'amortissement qui n'est
    # qu'une écriture — il n'apparaît nulle part ailleurs dans le compte de l'année.
    it "shows the accountant among the charges of the LMNP and its depreciation in the tax alone" do
      furnished = create(:simulation, user: user, monthly_rent: 1_000, occupancy_months: 12,
                                      purchase_price: 200_000, accounting_fees: 500, property_tax: 800,
                                      marginal_tax_rate: 30)

      result = statement_doc(furnished, :lmnp, 1).at_css("#lmnp-year-1-result")
      lines = result.css(".statement-detail-line").map do |line|
        [line.at_css(".statement-detail-label").text.strip,
         line.at_css(".statement-amount").text.gsub(/\s+/, " ").strip]
      end

      # 12 600 € de recettes prime de meublé comprise, 1 615 € de charges CFE et comptable compris,
      # 5 753,76 € d'amortissement du bâti.
      expect(lines).to eq([
        [I18n.t("views.simulations.show.detail_rent_excluding_charges", amount: currency(1_050), months: "12"),
         currency(12_600).gsub(/\s+/, " ")],
        [Simulation.human_attribute_name(:property_tax), currency(-800).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.business_tax"), currency(-315).gsub(/\s+/, " ")],
        [Simulation.human_attribute_name(:accounting_fees), currency(-500).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.detail_depreciation_building"), currency(BigDecimal("-5753.76")).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.detail_taxable_income"), currency(BigDecimal("5231.24")).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.detail_income_tax", rate: percentage(30)),
         currency(BigDecimal("-1569.37")).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.detail_social_charges", rate: percentage(BigDecimal("18.6"))),
         currency(BigDecimal("-973.01")).gsub(/\s+/, " ")]
      ])
    end

    # À crédit, la deuxième année : 5 481 € d'intérêts laissent 5 504 € de résultat pour 5 753,76 €
    # d'annuité et 467,55 € reportés de la première — 717,31 € attendront la troisième, et rien n'est dû.
    it "shows what the LMNP defers and what it takes back from the years before" do
      indebted = create(:simulation, :with_credit, user: user, monthly_rent: 1_000, occupancy_months: 12,
                                                   purchase_price: 200_000, accounting_fees: 500,
                                                   property_tax: 800, marginal_tax_rate: 30)

      result = statement_doc(indebted, :lmnp, 2).at_css("#lmnp-year-2-result")
      lines = result.css(".statement-detail-line").map do |line|
        [line.at_css(".statement-detail-label").text.strip,
         line.at_css(".statement-amount").text.gsub(/\s+/, " ").strip]
      end

      expect(lines).to include(
        [I18n.t("views.simulations.show.detail_depreciation_building"), currency(BigDecimal("-5753.76")).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.detail_deferred_depreciation"), currency(BigDecimal("-467.55")).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.detail_carried_forward_depreciation"), currency(BigDecimal("717.31")).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.detail_taxable_income"), currency(0).gsub(/\s+/, " ")]
      )
    end

    # 1 000 € d'entretien et 350 € pour les meubles sont payés en entier, mais 500 € et 280 € ne se
    # déduisent pas : ils remontent dans l'assiette et reviennent amortis, 41,67 € et 40 € la première année.
    it "shows the upkeep the LMNP capitalizes coming back through the plan" do
      upkept = create(:simulation, user: user, monthly_rent: 1_000, occupancy_months: 12, purchase_price: 200_000,
                                   accounting_fees: 500, maintenance: 1_000, furniture_maintenance: 350)

      result = statement_doc(upkept, :lmnp, 1).at_css("#lmnp-year-1-result")
      lines = result.css(".statement-detail-line").map do |line|
        [line.at_css(".statement-detail-label").text.strip,
         line.at_css(".statement-amount").text.gsub(/\s+/, " ").strip]
      end

      expect(lines).to include(
        [Simulation.human_attribute_name(:maintenance), currency(-1_000).gsub(/\s+/, " ")],
        [Simulation.human_attribute_name(:furniture_maintenance), currency(-350).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.detail_capitalized_works", share: percentage(50)), currency(500).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.detail_capitalized_furniture", share: percentage(80)), currency(280).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.detail_depreciation_works"), currency(BigDecimal("-41.67")).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.detail_depreciation_furniture"), currency(-40).gsub(/\s+/, " ")]
      )
    end

    # Une explication au survol, à côté du libellé : la fiche explique sans devenir un texte.
    it "carries a hover explanation beside the labels that need one" do
      hint = statement_doc(simulation, :micro_foncier, 1).at_css(".statement-hint")

      expect(hint["data-hint"]).to eq(I18n.t("views.simulations.show.hint_annual_rent_column"))
      expect(hint["aria-label"]).to eq(I18n.t("views.simulations.show.hint_annual_rent_column"))
    end

    # La revente détaille ce qu'elle coûte et l'impôt qu'elle doit, à même la fiche.
    it "details the costs and the capital gain tax of a sale" do
      growing = create(:simulation, user: user, property_growth_rate: 2)

      sale = statement_doc(growing, :micro_foncier, 10).at_css("#micro_foncier-year-10-sale")
      lines = sale.css(".statement-detail-line").map do |line|
        [line.at_css(".statement-detail-label").text.strip,
         line.at_css(".statement-amount").text.gsub(/\s+/, " ").strip]
      end

      # 200 000 € à 2 % pendant dix ans : 243 798,88 €, pour une valeur fiscale de 246 612 € travaux forfaitaires
      # compris — pas de plus-value, donc pas d'impôt à détailler. Dix cash-flows de 8 444,16 € sont encaissés.
      expect(lines).to eq([
        [I18n.t("views.simulations.show.detail_purchase_price"), currency(200_000).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.detail_property_growth"), currency(BigDecimal("43798.88")).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.detail_diagnostics"), currency(-400).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.detail_refurbishment"), currency(-500).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.detail_initial_outlay"), currency(-216_612).gsub(/\s+/, " ")],
        [I18n.t("views.simulations.show.detail_cumulative_cash_flow"),
         currency(BigDecimal("84441.60")).gsub(/\s+/, " ")]
      ])
    end

    # 200 000 € payés pour un bien qui en vaut 220 000 : la revente le dit sur une ligne à elle.
    it "names the discount obtained at the purchase in the value of the property" do
      discounted = create(:simulation, user: user, purchase_discount: 20_000)

      sale = statement_doc(discounted, :micro_foncier, 10).at_css("#micro_foncier-year-10-sale")
      lines = sale.css(".statement-detail-line").map { |line| line.at_css(".statement-detail-label").text.strip }

      expect(lines.first(2)).to eq([I18n.t("views.simulations.show.detail_purchase_price"),
                                    I18n.t("views.simulations.show.detail_purchase_discount")])
    end

    # Le tableau ne montre que le loyer hors charges, et la fiche des charges allégées d'autant.
    it "shows the rent excluding charges and says discreetly what the provision took off them" do
      let_out = create(:simulation, user: user, monthly_rent: 1_000, monthly_charges: 100,
                                    occupancy_months: 12, condominium_fees: 1_500)

      get simulation_path(let_out)

      doc = Nokogiri::HTML(response.body)
      rent = doc.css("#panel-micro_foncier tbody tr.row-expandable")[1].css("td")[2]
      charges = statement_doc(let_out, :micro_foncier, 1).css(".statement-line")[1]

      expect(rent.text.gsub(/\s+/, " ").strip).to eq(currency(12_000).gsub(/\s+/, " "))
      expect(charges.at_css(".statement-note").text.gsub(/\s+/, " ").strip)
        .to eq(I18n.t("views.simulations.show.provision_deducted", amount: currency(1_200)).gsub(/\s+/, " "))
      expect(charges.at_css(".statement-amount").text.gsub(/\s+/, " ").strip)
        .to eq(currency(-300).gsub(/\s+/, " "))
    end

    # Le meublé déclare les 13 800 € encaissés, prime comprise, et déduit ses 1 815 € de charges, sans
    # note : il déduit tout.
    it "shows the rent charges included and the whole charges under the micro-BIC" do
      let_out = create(:simulation, user: user, monthly_rent: 1_000, monthly_charges: 100,
                                    occupancy_months: 12, condominium_fees: 1_500)

      get simulation_path(let_out)

      doc = Nokogiri::HTML(response.body)
      lines = statement_doc(let_out, :micro_bic, 1).css(".statement-line")
      rent = lines[0]
      charges = lines[1]

      expect(doc.at_css("#panel-micro_bic thead th:nth-child(3)").text.strip)
        .to eq(I18n.t("views.simulations.show.annual_rent_including_charges_column"))
      expect(rent.at_css(".statement-amount").text.gsub(/\s+/, " ").strip).to eq(currency(13_800).gsub(/\s+/, " "))
      expect(charges.at_css(".statement-note")).to be_nil
      expect(charges.at_css(".statement-amount").text.gsub(/\s+/, " ").strip)
        .to eq(currency(-1_815).gsub(/\s+/, " "))
    end

    # Deux lectures d'une seule et même projection : même horizon, régime à part.
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
      statement = statement_doc(simulation, :foncier_reel, 1)
      amounts = statement.css(".statement-line").to_h do |line|
        [line.at_css(".statement-label").text.strip, line.at_css(".statement-amount").text.gsub(/\s+/, " ").strip]
      end

      # 9 000 € d'assiette et 1 548 € de prélèvements, là où le micro-foncier en compte 1 324,40 €.
      expect(cells).to eq([
        "1",
        "mar.-2026",
        currency(11_000).gsub(/\s+/, " "),
        currency(7_452).gsub(/\s+/, " "),
        currency(229_160).gsub(/\s+/, " "),
        percentage(BigDecimal("-12.70")).gsub(/\s+/, " ")
      ])
      expect(amounts).to include(
        I18n.t("views.simulations.show.income_tax_column") => currency(-1_548).gsub(/\s+/, " "),
        I18n.t("views.simulations.show.cash_flow") => currency(7_452).gsub(/\s+/, " ")
      )
    end

    # 11 550 € de loyer prime comprise, moitié imposée à 18,6 % : 1 074,15 € d'impôt, et 315 € de CFE.
    it "opens a tab of its own on the micro-BIC projection, half the receipts taxed" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      cells = doc.css("#panel-micro_bic tbody tr.row-expandable")[1].css("td").map { |td| td.text.gsub(/\s+/, " ").strip }
      regime_tab = doc.at_css("#regime-micro_bic")
      amounts = statement_doc(simulation, :micro_bic, 1)
                  .css("#micro_bic-year-1-result .statement-line").to_h do |line|
        [line.at_css(".statement-label").text.strip, line.at_css(".statement-amount").text.gsub(/\s+/, " ").strip]
      end

      expect(regime_tab).not_to be_nil
      expect(cells).to eq([
        "1",
        "mar.-2026",
        currency(11_550).gsub(/\s+/, " "),
        currency(BigDecimal("8160.85")).gsub(/\s+/, " "),
        currency(BigDecimal("228451.15")).gsub(/\s+/, " "),
        percentage(BigDecimal("-12.40")).gsub(/\s+/, " ")
      ])
      expect(amounts).to include(
        I18n.t("views.simulations.show.income_tax_column") => currency(BigDecimal("-1074.15")).gsub(/\s+/, " "),
        I18n.t("views.simulations.show.cash_flow") => currency(BigDecimal("8160.85")).gsub(/\s+/, " ")
      )
    end

    # La même année sous quatre régimes : le meublé y met sa prime de loyer, sa CFE et son impôt.
    it "renders the same year under every regime, the furnished rent and the tax apart" do
      statements = Taxation::NAMES.index_with do |regime|
        statement_doc(simulation, regime, 1)
          .css("##{regime}-year-1-result .statement-line").to_h do |line|
          # Le libellé seul : les notes qui le suivent disent justement ce qui distingue le régime.
          [line.at_css(".statement-label").children.first.text.strip,
           line.at_css(".statement-amount").text.gsub(/\s+/, " ").strip]
        end
      end
      taxed = ["income_tax_column", "net_result", "cash_flow"].map { |key| I18n.t("views.simulations.show.#{key}") }
      # Le meublé titre son loyer autrement, et sa CFE alourdit ses charges jusqu'au résultat avant impôt.
      own = taxed + ["annual_charges_column", "pre_tax_result", "annual_rent_column",
                     "annual_rent_including_charges_column"].map { |key| I18n.t("views.simulations.show.#{key}") }

      # Deux loyers seulement : 11 000 € au nu, et 5 % de plus au meublé.
      expect(statements.values.map { |lines| lines.values.first })
        .to eq([11_000, 11_000, 11_550, 11_550].map { |amount| currency(amount).gsub(/\s+/, " ") })
      expect(statements.values.map { |lines| lines.except(*own) }.uniq.size).to eq(1)
      expect(statements.values.map { |lines| lines.values_at(*taxed) }.uniq.size).to eq(Taxation::NAMES.size)
    end

    # C'est à 30 % de barème et à crédit que les régimes s'écartent le plus : les intérêts s'y déduisent.
    it "separates the regimes furthest when a real bracket meets deducted interest" do
      taxed = create(:simulation, :with_credit, user: user, purchase_date: Date.new(2025, 3, 10),
                                                purchase_price: 200_000, initial_works: 0,
                                                monthly_rent: 1_000, occupancy_months: 11,
                                                property_tax: 700, marginal_tax_rate: 30)

      amounts = Taxation::NAMES.index_with do |regime|
        statement_doc(taxed, regime, 1)
          .css("##{regime}-year-1-result .statement-line").to_h do |line|
          [line.at_css(".statement-label").text.strip, line.at_css(".statement-amount").text.gsub(/\s+/, " ").strip]
        end
      end

      # Le forfait impose 7 700 € ; le réel, les 4 601,21 € que charges et intérêts laissent des loyers.
      expect(amounts[:micro_foncier]).to include(
        I18n.t("views.simulations.show.income_tax_column") => currency(BigDecimal("-3634.40")).gsub(/\s+/, " "),
        I18n.t("views.simulations.show.net_result") => currency(BigDecimal("966.81")).gsub(/\s+/, " "),
        I18n.t("views.simulations.show.cash_flow") => currency(BigDecimal("-6193.84")).gsub(/\s+/, " ")
      )
      expect(amounts[:foncier_reel]).to include(
        I18n.t("views.simulations.show.income_tax_column") => currency(BigDecimal("-2171.77")).gsub(/\s+/, " "),
        I18n.t("views.simulations.show.net_result") => currency(BigDecimal("2429.44")).gsub(/\s+/, " "),
        I18n.t("views.simulations.show.cash_flow") => currency(BigDecimal("-4731.21")).gsub(/\s+/, " ")
      )
    end

    # La barre ne porte qu'un onglet fiscal, sur le foncier réel ; les autres régimes sont dans sa liste.
    it "carries a single taxation tab, on the real regime, and the others in its dropdown" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      toggle = doc.at_css(".tabs .tab-select .tab")

      expect(toggle["id"]).to eq("tab-foncier_reel")
      expect(toggle.text.strip).to eq(I18n.t("views.simulations.show.tab_foncier_reel"))
      expect(doc.css(".tab-select .tab-option").map { |option| option["data-tab-name"] })
        .to eq(Taxation::NAMES.map(&:to_s))
      expect(doc.at_css(".tab-select .tab-options")["hidden"]).not_to be_nil
      expect(doc.at_css("#regime-foncier_reel")["aria-checked"]).to eq("true")
    end

    # `tab` rouvre l'onglet d'où l'on revient : son panneau est le seul que le serveur montre.
    it "opens the panel that tab names and leaves the others hidden" do
      get simulation_path(simulation, tab: "foncier_reel")

      doc = Nokogiri::HTML(response.body)

      expect(doc.at_css("#panel-foncier_reel")["hidden"]).to be_nil
      expect(doc.at_css("#panel-micro_foncier")["hidden"]).not_to be_nil
      expect(doc.at_css("#tab-foncier_reel")["aria-selected"]).to eq("true")
    end

    # `regime` rouvre l'onglet fiscal sur le régime choisi, même depuis un autre onglet.
    it "opens the taxation tab on the regime that regime names" do
      get simulation_path(simulation, tab: "parameters", regime: "lmnp")

      doc = Nokogiri::HTML(response.body)
      toggle = doc.at_css(".tabs .tab-select .tab")

      expect(toggle["id"]).to eq("tab-lmnp")
      expect(toggle.text.strip).to eq(I18n.t("views.simulations.show.tab_lmnp"))
      expect(doc.at_css("#regime-lmnp")["aria-checked"]).to eq("true")
      # Le panneau ouvert reste celui de l'onglet : le régime n'en change pas.
      expect(doc.at_css("#panel-parameters")["hidden"]).to be_nil
    end

    # Une valeur corrigée revient sur les paramètres sans perdre le régime d'où elle part.
    it "carries the opened regime in the url of an editable value" do
      get simulation_path(simulation, tab: "parameters", regime: "lmnp")

      doc = Nokogiri::HTML5(response.body)
      form = doc.at_css("#panel-parameters .inline-edit-form")

      expect(form["action"]).to eq(simulation_path(simulation, tab: "parameters", regime: "lmnp"))
    end

    # L'en-tête dit le bien : une phrase dont chaque mot saisi se clique, sous le nom de la fiche.
    # HTML5 parse comme le navigateur : un formulaire dans un paragraphe le fermerait, et la phrase avec.
    it "presents the property in a sentence under the name of the simulation" do
      simulation.update!(address: "14 rue du Beau Laurier")

      get simulation_path(simulation)

      doc = Nokogiri::HTML5(response.body)
      summary = doc.at_css(".page-header .summary")
      words = summary.css(".inline-word .inline-edit-display").map(&:text)
      summary.css("form").remove

      expect(summary.text.gsub(/\s+/, " ").strip)
        .to eq("Appartement de 50 m² au 14 rue du Beau Laurier à Nantes. Acheté le 10 mars 2025.")
      expect(words).to eq(["Appartement", "50 m²", "14 rue du Beau Laurier", "Nantes", "10 mars 2025"])
      # La phrase se lit depuis tous les onglets : elle vit dans l'en-tête, hors des panneaux.
      expect(doc.at_css("#panel-parameters .summary")).to be_nil
    end

    # Un achat à venir ne s'annonce pas au passé : seul le verbe change, la phrase tient.
    it "announces a purchase still to come in the future" do
      date = Date.current.next_year
      simulation.update!(purchase_date: date, address: "14 rue du Beau Laurier")

      get simulation_path(simulation)

      doc = Nokogiri::HTML5(response.body)
      summary = doc.at_css(".page-header .summary")
      summary.css("form").remove

      expect(summary.text.gsub(/\s+/, " ").strip)
        .to eq("Appartement de 50 m² au 14 rue du Beau Laurier à Nantes. " \
               "Achat prévu le #{I18n.l(date, format: :long)}.")
    end

    # Le DPE se lit d'un coup d'œil à côté du nom, dans la couleur de sa classe, et s'y corrige.
    it "labels the energy rating beside the name, in the colour of its band" do
      simulation.update!(energy_rating: "E")

      get simulation_path(simulation)

      doc = Nokogiri::HTML5(response.body)
      badge = doc.at_css(".page-title .dpe")

      expect(badge["class"].split).to include("dpe", "dpe-e")
      expect(badge.at_css(".dpe-letter").text.strip).to eq("E")
      expect(badge.at_css("small").text.strip).to eq(Simulation.human_attribute_name(:energy_rating))
      expect(doc.at_css(".page-title #simulation_energy_rating")).not_to be_nil
    end

    # Un DPE non renseigné garde son étiquette, sans couleur de classe : c'est par elle qu'on le saisit.
    it "keeps a colourless badge to click when the energy rating is unknown" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML5(response.body)
      badge = doc.at_css(".page-title .dpe")

      expect(badge["class"].split).to eq(["inline-edit-display", "dpe"])
      expect(badge.at_css(".dpe-letter").text.strip)
        .to eq(I18n.t("views.simulations.show.energy_rating_unknown"))
    end

    # Sans adresse, la phrase le dit à sa place, et le mot reste à cliquer pour la renseigner.
    it "keeps a word to click when the address is not provided" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML5(response.body)
      summary = doc.at_css(".page-header .summary")
      address = summary.css(".inline-word").find { |word| word.at_css("#simulation_address") }
      summary.css("form").remove

      expect(summary.text.gsub(/\s+/, " ").strip)
        .to eq("Appartement de 50 m² à Nantes, adresse non renseignée. Acheté le 10 mars 2025.")
      expect(address.at_css(".inline-edit-display").text).to eq(I18n.t("views.simulations.show.address_not_provided"))
    end

    # Les frais de notaire ne sont pas un champ : la fiche les calcule d'après le prix, et le total tire le trait.
    it "adds up the purchase, notary fees included, into the cost of the project" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      section = doc.css(".section").find { |node| node.at_css("h2")&.text&.strip == I18n.t("views.simulations.show.purchase_detail") }
      lines = section.css(".sum .detail-item").to_h do |item|
        [item.at_css(".detail-label").text.strip, item.at_css(".detail-value").text.gsub(/\s+/, " ").strip]
      end

      expect(lines).to eq(
        Simulation.human_attribute_name(:purchase_price) => currency(200_000).gsub(/\s+/, " "),
        Simulation.human_attribute_name(:notary_fees) => currency(16_612).gsub(/\s+/, " "),
        Simulation.human_attribute_name(:initial_works) => currency(20_000).gsub(/\s+/, " "),
        Simulation.human_attribute_name(:furniture) => currency(0).gsub(/\s+/, " "),
        I18n.t("views.simulations.show.project_cost") => currency(236_612).gsub(/\s+/, " ")
      )
      expect(section.at_css(".sum-total .detail-label").text.strip)
        .to eq(I18n.t("views.simulations.show.project_cost"))
    end

    # Les meubles ne se paient que sous un régime du meublé : la ligne et le total lui sont réservés.
    it "reserves the furniture and the cost it adds to the furnished regimes" do
      simulation.update!(furniture: 2_110)

      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      section = doc.css(".section").find { |node| node.at_css("h2")&.text&.strip == I18n.t("views.simulations.show.purchase_detail") }
      furniture = section.css(".detail-item").find do |item|
        item.at_css(".detail-label").text.strip == Simulation.human_attribute_name(:furniture)
      end
      totals = section.css(".sum-total").to_h do |item|
        [item["data-regimes"], item.at_css(".detail-value").text.gsub(/\s+/, " ").strip]
      end

      expect(furniture["data-regimes"]).to eq("micro_bic lmnp")
      expect(totals["micro_foncier"]).to eq(currency(236_612).gsub(/\s+/, " "))
      expect(totals["lmnp"]).to eq(currency(238_722).gsub(/\s+/, " "))
    end

    # Le loyer se lit sur la fiche au mois, comme un bail l'énonce.
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
      expect(section.at_css(".sum-total").text.gsub(/\s+/, " ")).to include(currency(11_000).gsub(/\s+/, " "))
    end

    # Le loyer saisi est celui d'un nu : le meublé lit le sien, majoré, sous ses deux régimes.
    it "reads the rent raised by the premium under the furnished regimes" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      section = doc.css(".section").find { |node| node.at_css("h2")&.text&.strip == I18n.t("views.simulations.show.rental_detail") }
      premiums = section.css(".detail-item").select { |node| node.at_css(".detail-label").text.include?(I18n.t("views.simulations.show.furnished_rent")) }
      totals = section.css(".sum-total").to_h do |node|
        [node["data-regimes"], node.at_css(".detail-value").text.gsub(/\s+/, " ").strip]
      end

      # 1 000 € majorés de 5 % font 1 050 €, et onze mois loués 11 550 €.
      expect(premiums.map { |node| node["data-regimes"] }).to eq(["micro_bic", "lmnp"])
      # Le loyer saisi cède la place au loyer meublé au lieu de se lire à côté de lui.
      expect(section.css(".detail-item").find { |node| node.at_css(".detail-label").text.strip == Simulation.human_attribute_name(:monthly_rent) }["data-regimes"])
        .to eq("micro_foncier foncier_reel")
      expect(premiums.map { |node| node.at_css(".detail-value").text.gsub(/\s+/, " ").strip })
        .to eq([currency(1_050).gsub(/\s+/, " ")] * 2)
      expect(totals).to eq(
        "micro_foncier" => currency(11_000).gsub(/\s+/, " "),
        "foncier_reel" => currency(11_000).gsub(/\s+/, " "),
        "micro_bic" => currency(11_550).gsub(/\s+/, " "),
        "lmnp" => currency(11_550).gsub(/\s+/, " ")
      )
    end

    it "details every annual charge" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      section = doc.css(".section").find { |node| node.at_css("h2")&.text&.strip == I18n.t("views.simulations.show.charges_detail") }
      labels = section.css(".detail-label").map { |label| label.text.strip }

      expect(labels).to include(*Simulation::ANNUAL_CHARGES.map { |charge| Simulation.human_attribute_name(charge) })
    end

    # La CFE ne se saisit pas et ne pèse que sur le meublé : sa ligne n'appartient qu'à ces régimes.
    it "shows the business tax among the charges, kept for the furnished regimes" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      section = doc.css(".section").find { |node| node.at_css("h2")&.text&.strip == I18n.t("views.simulations.show.charges_detail") }
      item = section.css(".detail-item").find do |node|
        node.at_css(".detail-label").text.strip == I18n.t("views.simulations.show.business_tax")
      end

      expect(item.at_css(".detail-value").text).to include(currency(315).gsub(/\s+/, " "))
      expect(item["data-regimes"]).to eq("micro_bic lmnp")
    end

    # Le comptable se saisit, lui, mais un seul régime le paie.
    it "shows the accounting fees among the charges, kept for the LMNP regime" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      item = doc.css("#panel-parameters .detail-item").find do |node|
        node.at_css(".detail-label")&.text&.strip == Simulation.human_attribute_name(:accounting_fees)
      end

      expect(item["data-regimes"]).to eq("lmnp")
      expect(item.at_css("form")).not_to be_nil
    end

    # Le total suit le régime ouvert : le micro-BIC y ajoute la CFE, le LMNP le comptable en plus.
    it "totals the charges once per regime" do
      simulation.update!(accounting_fees: 500)
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      section = doc.css(".section").find { |node| node.at_css("h2")&.text&.strip == I18n.t("views.simulations.show.charges_detail") }
      totals = section.css(".sum-total").to_h do |node|
        [node["data-regimes"], node.at_css(".detail-value").text.gsub(/\s+/, " ").strip]
      end

      expect(totals).to eq(
        "micro_foncier" => currency(2_000).gsub(/\s+/, " "),
        "foncier_reel" => currency(2_000).gsub(/\s+/, " "),
        "micro_bic" => currency(2_315).gsub(/\s+/, " "),
        "lmnp" => currency(2_815).gsub(/\s+/, " ")
      )
    end

    # Le plan du LMNP se lit sous son seul régime : 216 612 € moins 15 % de terrain sur 32 ans,
    # 12 000 € de travaux sur douze, 2 100 € de meubles sur sept, et les 500 € de gros travaux que
    # chaque année ouvre sur douze ans.
    it "details the depreciation plan for the LMNP alone" do
      simulation.update!(initial_works: 12_000, furniture: 2_100)
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      section = doc.css(".section").find { |node| node.at_css("h2")&.text&.strip == I18n.t("views.simulations.show.depreciation_plan_detail") }
      amounts = section.css(".detail-item").to_h do |item|
        [item.at_css(".detail-label").text.gsub(/\s+/, " ").strip, item.at_css(".detail-value").text.gsub(/\s+/, " ").strip]
      end

      expect(section["data-regimes"]).to eq("lmnp")
      expect(section["hidden"]).not_to be_nil
      expect(amounts).to eq(
        "#{I18n.t("views.simulations.show.depreciation_plan_building", share: percentage(85))} " \
        "#{I18n.t("views.simulations.show.depreciation_plan_hint", base: currency(BigDecimal("184120.20")), years: 32)}" =>
          currency(BigDecimal("5753.76")).gsub(/\s+/, " "),
        "#{I18n.t("views.simulations.show.depreciation_plan_works")} " \
        "#{I18n.t("views.simulations.show.depreciation_plan_hint", base: currency(12_000), years: 12)}" =>
          currency(1_000).gsub(/\s+/, " "),
        "#{I18n.t("views.simulations.show.depreciation_plan_furniture")} " \
        "#{I18n.t("views.simulations.show.depreciation_plan_hint", base: currency(2_100), years: 7)}" =>
          currency(300).gsub(/\s+/, " "),
        "#{I18n.t("views.simulations.show.depreciation_plan_capitalized_works", share: percentage(50))} " \
        "#{I18n.t("views.simulations.show.depreciation_plan_tranche_hint", base: currency(500), years: 12)}" =>
          currency(BigDecimal("41.67")).gsub(/\s+/, " "),
        I18n.t("views.simulations.show.depreciation_plan_total") => currency(BigDecimal("7095.43")).gsub(/\s+/, " ")
      )
    end

    # On corrige un chiffre là où on le lit : pas de bouton Modifier, pas de bouton Enregistrer.
    it "carries a field of its own behind each value the user answered" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      forms = doc.css("#panel-parameters form")

      expect(doc.css("a[href='#{edit_simulation_path(simulation)}']")).to be_empty
      expect(forms.map { |form| form["action"] }.uniq)
        .to eq([simulation_path(simulation, tab: "parameters")])
      expect(forms.css("input[type=submit], button[type=submit]")).to be_empty
      expect(doc.at_css("#simulation_monthly_rent")["value"]).to eq("1000.0")
    end

    # Le texte reste la valeur mise en forme : le champ, lui, porte le chiffre brut.
    it "shows each value as text until its field is asked for" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      item = doc.css("#panel-parameters .detail-item").find do |node|
        node.at_css(".detail-label").text.strip == Simulation.human_attribute_name(:purchase_price)
      end

      expect(item.at_css(".inline-edit-display").text.gsub(/\s+/, " ")).to eq(currency(200_000).gsub(/\s+/, " "))
      expect(item.at_css("form")["hidden"]).not_to be_nil
    end

    # Un achat comptant n'a rien à amortir : l'onglet du tableau ne s'ouvre pas.
    it "carries no amortization tab without a credit" do
      get simulation_path(simulation)

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("#tab-amortization")).to be_nil
      # Les paramètres, la fiscalité, la comparaison et le contexte : les régimes n'en font qu'un.
      expect(doc.css("[data-controller=tabs] > .tabs .tab").size).to eq(4)
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
        expect(doc.css("[data-controller=tabs] > .tabs .tab").size).to eq(5)
        expect(doc.css("#panel-amortization tbody tr").size).to eq(on_credit.loan.duration_months)

        # La mensualité de la ligne est ce que la banque prélève, prime comprise.
        cells = doc.css("#panel-amortization tbody tr").first.css("td").map { |td| td.text.gsub(/\s+/, " ").strip }
        expect(cells.first).to eq("1")
        expect(cells.second).to include("05 avril 2025")
        expect(cells.third).to eq(currency(on_credit.loan.total_monthly_payment).gsub(/\s+/, " "))
        expect(cells[5]).to eq(currency(19.32).gsub(/\s+/, " "))
      end

      # L'annuité n'a pas de colonne : elle se lit sur le cash-flow des années où le crédit court.
      it "takes the annuity out of the cash flow without giving it a column" do
        get simulation_path(on_credit)

        doc = Nokogiri::HTML(response.body)
        headers = doc.css("#panel-micro_foncier thead th").map { |th| th.text.strip }
        cells = doc.css("#panel-micro_foncier tbody tr.row-expandable")[1].css("td").map { |td| td.text.gsub(/\s+/, " ").strip }

        # Année, date, loyers, cash-flow, capital immobilisé, TRI.
        expect(headers.size).to eq(6)
        expect(cells.third).to eq(currency(11_000).gsub(/\s+/, " "))
        expect(cells.fourth)
          .to eq(currency(11_000 - on_credit.annual_taxes - on_credit.loan.annual_payment).gsub(/\s+/, " "))
      end

      # Intérêts et prime sont une charge, le capital rendu non : il passe sous le résultat net.
      it "splits the annuity between the interest it charges and the capital it gives back" do
        statement = statement_doc(on_credit, :micro_foncier, 1)
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

      # Seuls l'apport et les frais de la signature s'immobilisent : le capital se rend par les annuités.
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
          Simulation.human_attribute_name(:loan_guarantee_fees) => currency(3_220).gsub(/\s+/, " "),
          Simulation.human_attribute_name(:loan_application_fees) => currency(1_932).gsub(/\s+/, " "),
          # 1 071,62 d'échéance et 19,32 d'assurance se lisent d'un bloc.
          Simulation.human_attribute_name(:monthly_payment) =>
            "#{currency(1_090.94)} #{I18n.t('views.simulations.show.insurance_included',
                                            amount: currency(19.32))}".gsub(/\s+/, " ")
        )
        # 23 388 d'apport, 3 220 de cautionnement et 1 932 de frais de dossier : le capital, lui, reste dehors.
        outlay = section.at_css(".sum").css(".detail-item").to_h do |item|
          [item.at_css(".detail-label").text.strip, item.at_css(".detail-value").text.gsub(/\s+/, " ").strip]
        end

        expect(outlay).to eq(
          Simulation.human_attribute_name(:down_payment) => currency(23_388).gsub(/\s+/, " "),
          Simulation.human_attribute_name(:loan_guarantee_fees) => currency(3_220).gsub(/\s+/, " "),
          Simulation.human_attribute_name(:loan_application_fees) => currency(1_932).gsub(/\s+/, " "),
          Simulation.human_attribute_name(:furniture) => currency(0).gsub(/\s+/, " "),
          I18n.t("views.simulations.show.initial_outlay") => currency(28_540).gsub(/\s+/, " ")
        )
      end
    end

    # Un onglet met les quatre régimes sur les mêmes axes : le capital encore engagé, ce que
    # revendre cette année-là laisserait, et le taux que l'opération aurait rendu.
    context "the comparison tab" do
      let(:neutral) { create(:simulation, user: user) }

      it "draws one curve per regime on each of the three charts" do
        get simulation_path(neutral)

        doc = Nokogiri::HTML(response.body)
        charts = doc.css("#panel-comparison .chart")

        expect(doc.at_css("#tab-comparison")).not_to be_nil
        expect(charts.size).to eq(4)
        expect(charts.take(2).map { |chart| chart.css("polyline.chart-line").size }).to eq([4, 4])
        expect(charts.first.css(".chart-legend-item").map { |item| item.at_css(".chart-legend-label").text.strip })
          .to eq(Taxation::NAMES.map { |name| I18n.t("views.simulations.show.tab_#{name}") })
      end

      # Le micro-foncier ne rend un taux positif qu'à partir de la troisième année : sa courbe
      # ne part que de là, et l'axe des taux commence au zéro plutôt qu'au plus bas des quatre.
      it "leaves the years without a positive rate off the rate chart" do
        get simulation_path(neutral)

        doc = Nokogiri::HTML(response.body)
        chart = doc.css("#panel-comparison .chart")[2]

        expect(chart.at_css(".chart-label-y").text.gsub(/\s+/, " ").strip).to eq("0,0 %")
        expect(chart.css(".chart-label-y").last.text.gsub(/\s+/, " ").strip).to eq("4,0 %")
        expect(chart.at_css("polyline.chart-micro_foncier")["points"].split.size).to eq(28)
      end

      # La fiche revend la quinzième année à défaut : 16 612 € de frais de notaire et, au
      # micro-foncier, 17,2 % des 6 720 € imposables que laissent 9 600 € de loyers, quinze fois.
      # Le barème n'atteint pas ce foyer, qui ne paie ni taxe foncière ni CFE.
      it "stacks the taxes paid up to the year of sale, one bar per regime" do
        get simulation_path(neutral)

        doc = Nokogiri::HTML(response.body)
        chart = doc.css("#panel-comparison .chart").last
        amounts = chart.css("text.chart-bar-label").map { |label| label.text.gsub(/\s+/, " ").strip }

        expect(doc.at_css("#panel-comparison .exit-year-value").text)
          .to eq(I18n.t("views.simulations.show.exit_year", year: 15))
        expect(amounts.first(2)).to eq([currency(16_612, precision: 0).gsub(/\s+/, " "),
                                        currency(17_338, precision: 0).gsub(/\s+/, " ")])
        expect(chart.css("text.chart-bar-total").first.text.gsub(/\s+/, " ").strip)
          .to eq(currency(33_950, precision: 0).gsub(/\s+/, " "))
      end

      # Le prix n'a pas bougé et personne ne dégage de plus-value — sauf le LMNP, à qui la revente
      # reprend quinze ans d'amortissements et qui seul porte la ligne.
      it "taxes the sale of the LMNP alone when the price has not moved" do
        get simulation_path(neutral)

        doc = Nokogiri::HTML(response.body)
        chart = doc.css("#panel-comparison .chart").last

        columns = chart.css("rect.chart-bar").map { |rect| rect["x"] }.uniq

        expect(chart.css("rect.chart-tax-capital_gain_tax").map { |rect| rect["x"] }).to eq([columns.last])
      end

      # L'année de revente ne redessine que son cadre : la fiche entière ne repart pas, et la
      # dixième année ajoute l'impôt d'une plus-value que la trentième aurait effacé.
      it "redraws the tax chart alone on the chosen year of sale" do
        selling = create(:simulation, user: user, property_growth_rate: 5)

        get tax_burden_simulation_path(selling, exit_year: 10)

        doc = Nokogiri::HTML(response.body)

        expect(doc.at_css("turbo-frame#tax_burden")).not_to be_nil
        expect(doc.css(".chart").size).to eq(1)
        expect(doc.at_css(".exit-year-value").text).to eq(I18n.t("views.simulations.show.exit_year", year: 10))
        expect(doc.css(".chart-legend-label").map(&:text))
          .to include(I18n.t("views.simulations.show.tax_capital_gain_tax"))
      end

      # Une année hors de l'horizon ne casse rien : la fiche revend celle où la liste la lit.
      it "falls back on the year the listing reads" do
        get simulation_path(neutral, tab: "comparison", exit_year: 99)

        doc = Nokogiri::HTML(response.body)

        expect(doc.at_css("#panel-comparison .exit-year-value").text)
          .to eq(I18n.t("views.simulations.show.exit_year", year: 15))
      end

      # Les flèches font défiler les années une à une, et s'éteignent aux deux bords de l'horizon.
      it "steps to the neighbouring years and stops at the edges" do
        get simulation_path(neutral, tab: "comparison", exit_year: 1)

        doc = Nokogiri::HTML(response.body)
        steps = doc.css("#panel-comparison .exit-year-step")

        expect(steps.first.name).to eq("span")
        expect(steps.last["href"]).to eq(tax_burden_simulation_path(neutral, exit_year: 2))
      end
    end

    it "does not serve the simulation of another user" do
      other = create(:simulation, user: create(:user))

      get simulation_path(other)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /simulations/:id/annee" do
    let(:simulation) do
      create(:simulation, user: user, purchase_date: Date.new(2025, 3, 10), purchase_price: 200_000,
                          initial_works: 20_000, monthly_rent: 1_000, occupancy_months: 11)
    end

    # Les cent vingt-quatre fiches d'année pesaient quatre-vingts pour cent de la page : elles se demandent.
    it "leaves the statements out of the listing until one is asked for" do
      get simulation_path(simulation)

      expect(response.body).not_to include("micro_foncier-year-1-statement")
      expect(response.body).to include("panel-micro_foncier")
    end

    # Rendue seule, la fiche ne coûte que son régime et porte la même année que le tableau.
    it "renders the statement of one year under one regime" do
      get statement_simulation_path(simulation, regime: :foncier_reel, year: 1)

      doc = Nokogiri::HTML(response.body)
      statement = doc.at_css("dialog#foncier_reel-year-1-statement")

      expect(response).to have_http_status(:success)
      expect(doc.css("dialog").size).to eq(1)
      expect(statement["data-year"]).to eq("1")
      expect(statement.at_css("#foncier_reel-year-1-result .statement-amount").text.gsub(/\s+/, " ").strip)
        .to eq(currency(11_000).gsub(/\s+/, " "))
    end

    it "answers a year outside the horizon with a not found" do
      get statement_simulation_path(simulation, regime: :foncier_reel, year: Projection::HORIZON_YEARS + 1)

      expect(response).to have_http_status(:not_found)
    end

    it "answers an unknown regime with a not found" do
      get statement_simulation_path(simulation, regime: "impot_sur_les_societes", year: 1)

      expect(response).to have_http_status(:not_found)
    end

    it "refuses the statement of a simulation held by someone else" do
      other = create(:simulation, user: create(:user))

      get statement_simulation_path(other, regime: :foncier_reel, year: 1)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "PATCH /simulations/:id" do
    # Le nom suit le bien : corriger la ville, c'est renommer la simulation.
    it "renames the simulation by moving the property" do
      simulation = create(:simulation, user: user, property_type: "house", city: "Rennes", surface: 62.5)

      patch simulation_path(simulation), params: { simulation: { city: "Nantes" } }

      expect(simulation.reload.name).to eq("🏠 Nante-63")
    end

    # Le formulaire de modification rassemble les cinq pages, la case du crédit comprise.
    it "turns a purchase paid outright into a purchase financed by a credit" do
      simulation = create(:simulation, user: user, purchase_price: 200_000, initial_works: 0)

      patch simulation_path(simulation), params: {
        simulation: { credit: "1", down_payment: "23388", loan_rate: "3.0", loan_duration_years: "20" }
      }

      expect(simulation.reload).to have_attributes(credit: true, down_payment: 23_388,
                                                   borrowed_capital: 193_224)
    end

    # L'indemnité de remboursement anticipé se décoche : c'est une clause qui se négocie.
    it "waives the early repayment indemnity when the box is unchecked" do
      simulation = create(:simulation, :with_credit, user: user)

      patch simulation_path(simulation), params: { simulation: { early_repayment_fee: "0" } }

      expect(simulation.reload.early_repayment_fee).to be(false)
      expect(simulation.loan.early_repayment_fee(100_000)).to eq(0)
    end

    it "updates the simulation" do
      simulation = create(:simulation, user: user, monthly_rent: 800)

      patch simulation_path(simulation), params: { simulation: { monthly_rent: "1000" } }

      expect(response).to redirect_to(simulation)
      expect(simulation.reload.monthly_rent).to eq(1_000)
    end

    # Tout est dérivé : un loyer corrigé refait la projection, d'où la fiche entière en retour.
    it "returns the whole page when a single value is saved on its own" do
      simulation = create(:simulation, user: user, monthly_rent: 800, occupancy_months: 12)

      patch simulation_path(simulation, tab: "micro_foncier"),
            params: { simulation: { monthly_rent: "1000" } }, as: :turbo_stream

      expect(response).to have_http_status(:success)
      expect(simulation.reload.monthly_rent).to eq(1_000)

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("turbo-stream")["target"]).to eq("simulation_#{simulation.id}")
      # L'onglet d'où part la correction est celui qui se rouvre.
      expect(doc.at_css("#panel-micro_foncier")["hidden"]).to be_nil
      expect(doc.at_css("#panel-parameters .detail-value").text).to be_present
      expect(doc.css("#panel-micro_foncier tbody tr")[1].text).to include(currency(12_000).gsub(/\s+/, " "))
    end

    # Un refus ne renvoie pas la fiche : elle porte encore la valeur d'avant, seul le message change.
    it "answers a refused value with the message alone" do
      simulation = create(:simulation, user: user, monthly_rent: 800)

      patch simulation_path(simulation), params: { simulation: { monthly_rent: "-1" } }, as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_entity)
      expect(simulation.reload.monthly_rent).to eq(800)

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("turbo-stream")["target"]).to eq("flash")
      expect(doc.at_css(".alert-danger").text)
        .to include(Simulation.human_attribute_name(:monthly_rent), "doit être supérieur ou égal à 0")
    end

    # Les étapes n'ont de sens que pour qui découvre le formulaire : la modification tient sur une page.
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
    # La marque mène à l'accueil : la liste des simulations se prend dans le menu.
    it "carries the simulations and the general settings in the top menu of a signed-in user" do
      get simulations_path

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css(".navbar-logo")["href"]).to eq(root_path)
      expect(doc.css(".navbar-menu .nav-link").map { |link| link["href"] })
        .to eq([simulations_path, edit_assumptions_path])
      expect(doc.at_css(".nav-user-name")["href"]).to eq(account_path)
      expect(doc.at_css(".nav-user-name").text).to eq(user.full_name)
    end

    # Sur mobile le burger commande le panneau : le compte et la déconnexion y sont avec les liens.
    it "folds the menu, the account and the sign out behind one button" do
      get simulations_path

      doc = Nokogiri::HTML(response.body)
      menu = doc.at_css("##{doc.at_css('.navbar-burger')['aria-controls']}")
      expect(menu["class"]).to include("navbar-menu")
      expect(menu.at_css(".nav-user-name")["href"]).to eq(account_path)
      expect(menu.at_css("form[action='#{destroy_user_session_path}']")).not_to be_nil
    end
  end
end
