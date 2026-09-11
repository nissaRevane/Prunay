require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
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
end
