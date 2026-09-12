require "rails_helper"

# Les limites qui tiennent le bruit de fond du web à distance : un compteur par IP dans le cache.
RSpec.describe "Throttling", type: :request do
  let(:user) { create(:user) }

  describe "POST /users" do
    # Une inscription connecte : sans la déconnexion, Devise refuserait la suivante avant la limite.
    def sign_up(number)
      post user_registration_path,
           params: { user: { email: "robot#{number}@example.com", password: "password123",
                             password_confirmation: "password123" } }
      delete destroy_user_session_path
    end

    # Cinq inscriptions par heure et par IP : la sixième repart sans compte.
    it "refuses the sixth sign-up of the hour" do
      expect { 5.times { |number| sign_up(number) } }.to change(User, :count).by(5)

      expect { sign_up(6) }.not_to change(User, :count)
      expect(flash[:alert]).to eq(I18n.t("flash.errors.throttled"))
    end
  end

  describe "POST /users/sign_in" do
    def attempt(password)
      post user_session_path, params: { user: { email: user.email, password: password } }
    end

    # Dix essais par tranche de cinq minutes : de quoi se tromper, pas de quoi deviner.
    it "refuses the eleventh attempt, right password or not" do
      10.times { attempt("mauvais") }
      expect(response).to have_http_status(:unprocessable_entity)

      attempt("password123")

      expect(flash[:alert]).to eq(I18n.t("flash.errors.throttled"))
    end
  end

  describe "POST /users/password" do
    def ask_for_reset = post(user_password_path, params: { user: { email: user.email } })

    # Chaque demande part en courrier : cinq par heure, et la sixième n'en déclenche aucun.
    it "refuses the sixth reset request of the hour" do
      5.times { ask_for_reset }

      expect { ask_for_reset }.not_to change(ActionMailer::Base.deliveries, :size)
      expect(flash[:alert]).to eq(I18n.t("flash.errors.throttled"))
    end
  end

  describe "POST /simulations/rapide" do
    before { sign_in user }

    def create_simulation
      post express_simulations_path,
           params: { simulation: { property_type: "apartment", city: "Nantes", surface: "50",
                                   purchase_price: "200000", monthly_rent: "800" } }
    end

    # Vingt par minute : personne n'en remplit autant à la main, un robot n'attend pas.
    it "refuses the twenty-first creation of the minute" do
      expect { 20.times { create_simulation } }.to change(Simulation, :count).by(20)

      expect { create_simulation }.not_to change(Simulation, :count)
      expect(flash[:alert]).to eq(I18n.t("flash.errors.throttled"))
    end
  end
end
