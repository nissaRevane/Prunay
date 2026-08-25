require "rails_helper"

RSpec.describe "Authentication", type: :request do
  let(:user) { create(:user) }

  describe "POST /users/sign_in" do
    it "signs the user in and lands on their simulations" do
      post user_session_path, params: { user: { email: user.email, password: "password123" } }

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include(I18n.t("views.simulations.index.title"))
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

    it "creates an account with a firstname and a lastname" do
      expect {
        sign_up(firstname: "Jean", lastname: "Dupont", email: "jean@example.com",
                password: "password123", password_confirmation: "password123")
      }.to change(User, :count).by(1)

      expect(User.last).to have_attributes(firstname: "Jean", lastname: "Dupont")
      expect(response).to redirect_to(root_path)
    end

    # firstname/lastname are not Devise attributes: without the sanitizer of
    # ApplicationController they would be dropped silently and the account created nameless.
    it "rejects a sign-up without a name" do
      expect {
        sign_up(email: "sans-nom@example.com", password: "password123",
                password_confirmation: "password123")
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
    # authenticate_user! is a before_action of ApplicationController, and pages#home the
    # single place that opts out: a controller added later is protected unless it says so.
    it "protects every page but the public landing one" do
      get account_path

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
