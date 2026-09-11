require "rails_helper"

RSpec.describe "Authentication", type: :request do
  let(:user) { create(:user) }

  describe "POST /users/sign_in" do
    it "signs the user in and lands on the quick creation form" do
      post user_session_path, params: { user: { email: user.email, password: "password123" } }

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include(I18n.t("views.simulations.express.create"))
    end

    it "rejects a wrong password without saying which field is wrong" do
      post user_session_path, params: { user: { email: user.email, password: "mauvais" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t("devise.failure.invalid", authentication_keys: "Email"))
    end
  end

  describe "POST /users" do
    def sign_up(attributes)
      post user_registration_path, params: { user: attributes }
    end

    it "creates an account from an email and a password" do
      expect {
        sign_up(email: "jean@example.com", password: "password123", password_confirmation: "password123")
      }.to change(User, :count).by(1)

      expect(User.last.email).to eq("jean@example.com")
      expect(response).to redirect_to(root_path)
    end

    it "rejects a sign-up without an email" do
      expect {
        sign_up(password: "password123", password_confirmation: "password123")
      }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /users/sign_out" do
    it "signs the user out and gives the public landing page back" do
      sign_in user

      delete destroy_user_session_path

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include(I18n.t("views.pages.home.title"))
    end
  end

  describe "GET /users/password/new" do
    it "offers the forgotten-password form to a visitor" do
      get new_user_password_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Mot de passe oublié")
    end
  end

  describe "the default guard" do
    # authenticate_user! is a before_action of ApplicationController, and pages#home the single opt-out.
    it "protects every page but the public landing one" do
      get account_path

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
