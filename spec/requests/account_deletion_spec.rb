require "rails_helper"

# Le droit à l'effacement : héberger les simulations de quelqu'un oblige à lui laisser le
# moyen de tout retirer lui-même, et à ne rien garder derrière.
RSpec.describe "Account deletion", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  it "offers the deletion from the account page" do
    get account_path

    expect(response.body).to include(I18n.t("views.account.show.delete"))
  end

  it "takes the account and everything it carried" do
    simulation = create(:simulation, user: user)
    assumptions = create(:assumptions, user: user)

    delete user_registration_path

    expect(User.exists?(user.id)).to be(false)
    expect(Simulation.exists?(simulation.id)).to be(false)
    expect(Assumptions.exists?(assumptions.id)).to be(false)
  end

  it "signs the user out and says so" do
    delete user_registration_path

    expect(response).to redirect_to(root_path)
    expect(flash[:notice]).to eq(I18n.t("devise.registrations.destroyed"))
  end
end
