require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user) }

  describe "GET /" do
    it "requires an authenticated user" do
      get root_path

      expect(response.body).not_to include(I18n.t("views.dashboard.title"))
    end

    context "when signed in" do
      before { sign_in user }

      it "renders the dashboard" do
        get root_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include(I18n.t("views.dashboard.title"))
      end

      # Le simulateur n'existe pas encore : la page le dit, plutôt que de montrer des
      # tuiles vides. Cette épreuve tombera le jour où il y aura des chiffres à afficher.
      it "says plainly that there is nothing to show yet" do
        get root_path

        doc = Nokogiri::HTML(response.body)
        expect(doc.at_css(".empty-state").text.strip).to eq(I18n.t("views.dashboard.empty"))
        expect(doc.at_css(".stat-grid")).to be_nil
      end

      it "is what the navbar brand and its single entry point at" do
        get root_path

        doc = Nokogiri::HTML(response.body)
        expect(doc.at_css(".navbar-logo")["href"]).to eq(root_path)
        expect(doc.css(".navbar-links .nav-link").map { |link| link["href"] }).to eq([root_path])
        expect(doc.at_css(".nav-user-name")["href"]).to eq(account_path)
        expect(doc.at_css(".nav-user-name").text).to eq(user.full_name)
      end
    end
  end
end
