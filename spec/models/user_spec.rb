require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:firstname) }
    it { is_expected.to validate_presence_of(:lastname) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:password) }

    it "refuses an email already taken, whatever its case" do
      create(:user, email: "jean@example.com")

      expect(build(:user, email: "JEAN@example.com")).not_to be_valid
    end

    it "refuses a password shorter than six characters" do
      expect(build(:user, password: "court", password_confirmation: "court")).not_to be_valid
    end
  end

  describe "#full_name" do
    it "returns firstname and lastname" do
      user = build(:user, firstname: "Jean", lastname: "Dupont")
      expect(user.full_name).to eq("Jean Dupont")
    end
  end
end
