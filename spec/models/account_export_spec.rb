require "rails_helper"

RSpec.describe AccountExport do
  let(:user) { create(:user, email: "quentin@example.com", firstname: "Quentin", lastname: "GIRARD") }

  describe "#to_h" do
    it "exports the account identity without the real password" do
      data = described_class.new(user).to_h

      expect(data["user"]).to include(
        "email" => "quentin@example.com",
        "firstname" => "Quentin",
        "lastname" => "GIRARD"
      )
      expect(data["user"]["password"]).to be_present
      expect(user.valid_password?(data["user"]["password"])).to be false
    end

    it "generates a different password on every export" do
      passwords = 2.times.map { described_class.new(user).to_h.dig("user", "password") }

      expect(passwords.uniq.size).to eq(2)
    end

    it "exports the economic conditions of the account" do
      create(:economic_conditions, user: user, rent_growth_rate: 1.5, property_growth_rate: 2,
             inflation_rate: 3, marginal_tax_rate: 41)

      expect(described_class.new(user).to_h["economic_conditions"]).to eq(
        "rent_growth_rate" => 1.5, "property_growth_rate" => 2,
        "inflation_rate" => 3, "marginal_tax_rate" => 41
      )
    end

    # Les conditions sont absentes tant que l'utilisateur n'y a pas touché : l'export porte
    # alors ce dont Prunay habille une simulation, pas un trou.
    it "falls back to the default conditions when the account has none" do
      expect(described_class.new(user).to_h["economic_conditions"]).to eq(
        "rent_growth_rate" => 1, "property_growth_rate" => 1,
        "inflation_rate" => 2, "marginal_tax_rate" => 30
      )
    end

    it "exports every simulation field, in creation order" do
      create(:simulation, user: user, city: "Nantes")
      create(:simulation, user: user, city: "Angers")

      simulations = described_class.new(user).to_h["simulations"]

      expect(simulations.map { |data| data["city"] }).to eq(%w[Nantes Angers])
      expect(simulations.first.keys).to eq(described_class::SIMULATION_FIELDS)
    end

    it "exports amounts as numbers and dates as ISO strings" do
      create(:simulation, :with_credit, user: user, purchase_date: Date.new(2025, 1, 15),
             purchase_price: 200_000, surface: 62.5, occupancy_months: 11.5)

      expect(described_class.new(user).to_h["simulations"].sole).to include(
        "purchase_date" => "2025-01-15",
        "purchase_price" => 200_000,
        "surface" => 62.5,
        "occupancy_months" => 11.5,
        "loan_rate" => 3,
        "loan_duration_years" => 20,
        "credit" => true
      )
    end

    it "leaves out other accounts" do
      create(:simulation, user: create(:user))

      expect(described_class.new(user).to_h["simulations"]).to be_empty
    end
  end

  describe "#to_json" do
    it "serializes amounts as JSON numbers, not strings" do
      create(:simulation, user: user, purchase_price: 199_500.5)

      json = described_class.new(user).to_json

      expect(json).to include('"purchase_price": 199500.5')
      expect(JSON.parse(json).dig("simulations", 0, "purchase_price")).to eq(199_500.5)
    end

    # db/seed_data.json est ce que db/seeds.rb relit : un export qui n'écrit pas exactement ses
    # clés, dans le même ordre, ne peut plus lui être redonné.
    it "matches the structure db/seeds.rb reads" do
      seed_data = JSON.parse(File.read(Rails.root.join("db", "seed_data.json")))
      create(:simulation, user: user)
      data = described_class.new(user).to_h

      expect(data.keys).to eq(seed_data.keys)
      expect(data["user"].keys).to match_array(seed_data["user"].keys)
      expect(data["economic_conditions"].keys).to eq(seed_data["economic_conditions"].keys)
      expect(data["simulations"].first.keys).to eq(seed_data["simulations"].first.keys)
    end
  end

  describe "#filename" do
    it "names the file after the account and the day" do
      expect(described_class.new(user).filename)
        .to eq("prunay-export-quentin-example-com-#{Date.current.iso8601}.json")
    end
  end
end
