require "rails_helper"

RSpec.describe Simulation::Step do
  def draft(**answers)
    Simulation.new(user: build(:user), **answers)
  end

  # Le parcours n'est pas le même pour tout le monde : la page du crédit ne s'ouvre qu'à qui
  # en a coché un sur la page de l'achat.
  describe ".all_for" do
    it "walks the credit page only when there is a credit" do
      expect(described_class.all_for(build(:simulation, :with_credit)))
        .to eq(%w[property purchase credit rental charges])
      expect(described_class.all_for(build(:simulation, credit: false)))
        .to eq(%w[property purchase rental charges])
    end
  end

  describe ".defaults" do
    it "proposes nothing on the first page: the surface is what it asks for" do
      expect(described_class.defaults("property", draft(surface: 50))).to eq({})
    end

    it "dates the purchase three months out and assumes no works" do
      defaults = described_class.defaults("purchase", draft)

      expect(defaults["purchase_date"]).to eq(Date.current >> 3)
      expect(defaults["initial_works"]).to eq(0)
    end

    # La page de l'achat s'ouvre avant que le prix n'y soit tapé : elle ne peut alors rien
    # proposer comme apport.
    it "proposes a tenth of the project cost as a down payment" do
      priced = draft(purchase_price: 200_000, initial_works: 0)

      expect(described_class.defaults("purchase", priced)["down_payment"]).to eq(21_660)
      expect(described_class.defaults("purchase", draft)["down_payment"]).to eq(0)
    end

    # Vingt ans à 3,5 %, et la prime d'assurance à la référence : un dix-millième des
    # 193 224 € empruntés fait 19,32 € par mois. Un brouillon qui n'emprunte encore rien n'a
    # rien à assurer.
    it "proposes twenty years at 3.5 % and a premium read on the capital borrowed" do
      expect(described_class.defaults("credit", draft))
        .to eq("loan_rate" => BigDecimal("3.5"), "loan_duration_years" => 20, "loan_insurance" => 0)

      on_credit = draft(credit: true, purchase_price: 200_000, initial_works: 0, down_payment: 23_388)

      expect(described_class.defaults("credit", on_credit)["loan_insurance"]).to eq(BigDecimal("19.32"))
    end

    it "leaves a month of vacancy a year" do
      expect(described_class.defaults("rental", draft(surface: 50))["occupancy_months"]).to eq(11)
    end

    # Un bien meublé hors copropriété : pas de charges de copro, un entretien doublé, et les
    # deux charges que le meublé impose.
    it "estimates every charge the property is asked for" do
      furnished = draft(surface: 50, condominium: false, rental_type: "furnished")

      expect(described_class.defaults("charges", furnished)).to eq(
        "property_tax" => 700, "insurance" => 150, "maintenance" => 2_000,
        "management_fees" => 0, "rent_guarantee" => 0,
        "business_tax" => 200, "accounting_fees" => 500,
        "other_charges" => 100
      )
    end

    it "asks a condominium for its fees, and halves the maintenance it no longer carries alone" do
      defaults = described_class.defaults("charges", draft(surface: 50, condominium: true,
                                                           rental_type: "unfurnished"))

      expect(defaults).to include("condominium_fees" => 1_000, "maintenance" => 1_000)
      expect(defaults.keys).not_to include("business_tax", "accounting_fees")
    end
  end
end
