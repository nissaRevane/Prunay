require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    it "welcomes a visitor without asking them to sign in" do
      get root_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("views.pages.home.title"))
      expect(response.body).to include(I18n.t("views.pages.home.subtitle"))
    end

    it "offers the sign-up as the call to action" do
      get root_path

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css(".hero .btn-lg")["href"]).to eq(new_user_registration_path)
      expect(doc.at_css(".navbar-links a[href='#{new_user_session_path}']")).not_to be_nil
    end

    # La racine sert deux pages selon qui la demande : la vitrine au visiteur, le tableau
    # de bord à l'utilisateur connecté (voir la contrainte `authenticated :user` des routes).
    it "is the dashboard for a signed-in user" do
      sign_in create(:user)

      get root_path

      expect(response.body).to include(I18n.t("views.dashboard.title"))
      expect(response.body).not_to include(I18n.t("views.pages.home.subtitle"))
    end
  end
end
