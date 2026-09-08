require "rails_helper"

RSpec.describe "Exports", type: :request do
  let(:user) { create(:user) }

  describe "GET /export" do
    it "requires an authenticated user" do
      get export_path

      expect(response).to redirect_to(new_user_session_path)
    end

    context "when signed in" do
      before { sign_in user }

      it "sends the account as a JSON download" do
        get export_path

        expect(response).to have_http_status(:success)
        expect(response.media_type).to eq("application/json")
        expect(response.headers["Content-Disposition"]).to include("attachment")
        expect(response.headers["Content-Disposition"]).to include("prunay-export-")
      end

      it "returns the account data with a substitute password" do
        create(:simulation, user: user, city: "Nantes")

        get export_path

        data = JSON.parse(response.body)
        expect(data["user"]["email"]).to eq(user.email)
        expect(data["user"]["password"]).not_to eq("password123")
        expect(data["simulations"].sole["city"]).to eq("Nantes")
      end

      it "never exposes the encrypted password" do
        get export_path

        expect(response.body).not_to include(user.encrypted_password)
        expect(response.body).not_to include("encrypted_password")
      end

      it "leaves out the simulations of other accounts" do
        create(:simulation, user: create(:user), city: "Angers")

        get export_path

        expect(JSON.parse(response.body)["simulations"]).to be_empty
      end
    end
  end

  describe "the account page" do
    it "offers the export link to signed-in users" do
      sign_in user

      get account_path

      expect(response.body).to include(export_path)
      expect(response.body).to include("Exporter mes données")
    end
  end
end
