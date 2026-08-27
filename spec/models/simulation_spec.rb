require "rails_helper"

RSpec.describe Simulation, type: :model do
  # Chaque page de la création est un contexte de validation : elle ne juge que ses propres
  # champs, pour qu'une étape puisse être validée sans exiger les réponses des suivantes.
  describe "validations" do
    it { is_expected.to validate_presence_of(:city).on(:property) }
    it { is_expected.to validate_numericality_of(:surface).is_greater_than(0).on(:property) }
    it { is_expected.to validate_inclusion_of(:property_type).in_array(described_class::PROPERTY_TYPES).on(:property) }
    it { is_expected.to validate_inclusion_of(:energy_rating).in_array(described_class::ENERGY_RATINGS).allow_blank.on(:property) }

    it { is_expected.to validate_presence_of(:purchase_date).on(:purchase) }
    it { is_expected.to validate_numericality_of(:purchase_price).is_greater_than(0).on(:purchase) }
    it { is_expected.to validate_numericality_of(:initial_works).is_greater_than_or_equal_to(0).on(:purchase) }

    # Le crédit ne se juge qu'à qui en prend un : sans crédit, la page n'existe pas, et
    # l'apport comme le taux et la durée sont remis à zéro avant même d'être validés.
    context "of a purchase financed by a credit" do
      subject { build(:simulation, :with_credit) }

      it { is_expected.to validate_numericality_of(:down_payment).is_greater_than_or_equal_to(0).on(:purchase) }
      it { is_expected.to validate_numericality_of(:loan_rate).is_greater_than_or_equal_to(0).is_less_than(100).on(:credit) }
      it { is_expected.to validate_numericality_of(:loan_duration_years).only_integer.is_greater_than(0).on(:credit) }
      it { is_expected.to validate_numericality_of(:loan_insurance).is_greater_than_or_equal_to(0).on(:credit) }
      it { is_expected.to validate_numericality_of(:loan_guarantee_fees).is_greater_than_or_equal_to(0).on(:credit) }
      it { is_expected.to validate_numericality_of(:loan_application_fees).is_greater_than_or_equal_to(0).on(:credit) }

      # Un apport qui couvrirait tout le projet ne laisserait rien à emprunter.
      it "refuses a down payment that leaves nothing to borrow" do
        simulation = build(:simulation, :with_credit, purchase_price: 200_000, initial_works: 0,
                                                      down_payment: 216_612)

        expect(simulation).not_to be_valid(:purchase)
        expect(simulation.errors[:down_payment]).to be_present
      end
    end

    it "asks nothing of the credit of a purchase paid outright" do
      expect(build(:simulation, credit: false, loan_rate: 0, loan_duration_years: 0)).to be_valid(:credit)
    end

    it { is_expected.to validate_numericality_of(:monthly_rent).is_greater_than_or_equal_to(0).on(:rental) }
    it { is_expected.to validate_numericality_of(:monthly_charges).is_greater_than_or_equal_to(0).on(:rental) }
    it { is_expected.to validate_numericality_of(:occupancy_months).is_greater_than(0).is_less_than_or_equal_to(12).on(:rental) }

    it { is_expected.to validate_numericality_of(:property_tax).is_greater_than_or_equal_to(0).on(:charges) }

    # La tranche marginale se choisit dans le barème : un taux inventé n'y a pas de place.
    it { is_expected.to validate_inclusion_of(:marginal_tax_rate).in_array(Taxation::MARGINAL_TAX_RATES).on(:update) }

    it "leaves the pages that have not been reached alone" do
      draft = described_class.new(user: build(:user), property_type: "house", city: "Nantes", surface: 50)

      expect(draft).to be_valid(:property)
      expect(draft).not_to be_valid(:purchase)
    end

    # Une simulation enregistrée, elle, doit avoir traversé les quatre pages.
    it "demands every page at once when the record is saved" do
      draft = described_class.new(user: build(:user), property_type: "house", city: "Nantes", surface: 50)

      expect(draft).not_to be_valid
    end
  end

  # Le parcours n'est pas le même pour tout le monde : la page du crédit ne s'ouvre qu'à qui
  # en a coché un sur la page de l'achat.
  describe "#steps" do
    it "walks the credit page only when there is a credit" do
      expect(build(:simulation, :with_credit).steps).to eq(%w[property purchase credit rental charges])
      expect(build(:simulation, credit: false).steps).to eq(%w[property purchase rental charges])
    end
  end

  # Le nom peut se donner dès la première page, mais rien n'y oblige : à l'enregistrement,
  # une simulation sans nom prend celui de son bien.
  describe "the name" do
    it "keeps the one the first page was given" do
      expect(create(:simulation, name: "Le studio du port").name).to eq("Le studio du port")
    end

    it "reads the property itself when nobody named the simulation" do
      simulation = create(:simulation, name: "", property_type: "house", city: "Rennes", surface: 62.5)

      expect(simulation.name).to eq("Maison à Rennes, 62,5 m²")
    end

    it "names the simulation again when its name is emptied by hand" do
      simulation = create(:simulation, name: "Le studio du port")

      simulation.update(name: "  ")

      expect(simulation.reload.name).to eq(simulation.default_name)
    end

    # Valider une étape, ce n'est pas enregistrer : la page du bien ne doit pas remplir à
    # l'utilisateur un champ qu'il a laissé vide.
    it "leaves the field empty while a page is being validated" do
      draft = described_class.new(user: build(:user), property_type: "house", city: "Rennes", surface: 50)

      draft.valid?(:property)

      expect(draft.name).to be_blank
    end
  end

  describe "#annual_rent" do
    # Onze mois loués ne font pas douze loyers : la vacance locative se paie.
    it "counts only the months actually let" do
      expect(build(:simulation, monthly_rent: 800, occupancy_months: 11).annual_rent).to eq(8_800)
    end

    # Le locataire rembourse ses charges par-dessus le loyer : c'est encaissé, et cela compte
    # dans le cash-flow — 800 + 60, onze fois.
    it "collects the provision for charges next to the rent" do
      let_out = build(:simulation, monthly_rent: 800, monthly_charges: 60, occupancy_months: 11)

      expect(let_out.annual_rent).to eq(9_460)
    end
  end

  # L'assiette de l'impôt, et rien d'autre : la provision pour charges n'en fait pas partie.
  describe "#annual_rent_excluding_charges" do
    it "counts the rent alone, the provision for charges left out" do
      let_out = build(:simulation, monthly_rent: 800, monthly_charges: 60, occupancy_months: 11)

      expect(let_out.annual_rent_excluding_charges).to eq(8_800)
    end
  end

  # Les régimes sont dans Taxation : la simulation ne fait que leur passer son assiette, ses
  # charges, ses intérêts d'emprunt et la tranche de son foyer.
  describe "#annual_taxes" do
    it "taxes the rent excluding charges at the bracket of the household" do
      taxed = build(:simulation, monthly_rent: 1_000, monthly_charges: 100, occupancy_months: 12,
                                 marginal_tax_rate: 30)

      # 12 000 € de loyers hors charges, 8 400 € imposables après abattement, 47,2 % dessus.
      expect(taxed.taxation).to have_attributes(rent_excluding_charges: 12_000, taxable_income: 8_400)
      expect(taxed.annual_taxes).to eq(BigDecimal("3964.80"))
    end

    # Les prélèvements sociaux ne se choisissent pas : 12,04 % des loyers hors charges restent
    # dus même au foyer que le barème n'atteint pas.
    it "still owes the social charges when the bracket is nil" do
      expect(build(:simulation, monthly_rent: 1_000, occupancy_months: 12, marginal_tax_rate: 0).annual_taxes)
        .to eq(BigDecimal("1444.80"))
    end

    # Le forfait du micro-foncier ignore ce que l'année a réellement dépensé ; le foncier réel,
    # lui, le déduit — les charges et les intérêts de la première annuité.
    it "deducts the real charges and the loan interest where the forfait does not" do
      on_credit = build(:simulation, :with_credit, monthly_rent: 1_000, occupancy_months: 12,
                                                  property_tax: 700)

      expect(on_credit.taxation(:foncier_reel).taxable_income)
        .to eq(12_000 - 700 - on_credit.loan.annual_interest.fetch(1))
      expect(on_credit.annual_taxes(:foncier_reel)).to be < on_credit.annual_taxes
    end
  end

  describe "#annual_charges" do
    it "adds up the charges the property is asked for" do
      simulation = build(:simulation, condominium: true,
                                      property_tax: 700, insurance: 150, maintenance: 1_000,
                                      condominium_fees: 1_200, management_fees: 600, rent_guarantee: 300,
                                      other_charges: 100)

      expect(simulation.annual_charges).to eq(4_050)
    end

    # Une charge qu'aucune condition ne justifie ne pèse pas sur la projection : elle est
    # ramenée à zéro avant l'enregistrement, et le total ne la compte pas.
    it "ignores what the property is not asked for" do
      simulation = create(:simulation, condominium: false, property_tax: 700, condominium_fees: 1_200)

      expect(simulation.annual_charges).to eq(700)
      expect(simulation).to have_attributes(condominium_fees: 0)
    end
  end

  # Les charges de copropriété ne se demandent qu'à un bien en copropriété, et ne survivent
  # pas à sa disparition.
  describe "the charges a condition governs" do
    it "asks a condominium for its fees, and a property outside one for nothing of the sort" do
      expect(build(:simulation, condominium: true).applicable_charges).to include(:condominium_fees)
      expect(build(:simulation, condominium: false).applicable_charges).not_to include(:condominium_fees)
    end

    # Sortir de copropriété, c'est cesser d'en payer les charges : un montant que le
    # formulaire ne montre plus ne doit pas continuer de peser sur la projection.
    it "clears an amount its condition no longer justifies" do
      simulation = create(:simulation, condominium: true, condominium_fees: 1_200)

      simulation.update(condominium: false)

      expect(simulation.reload.condominium_fees).to eq(0)
    end
  end

  describe "#notary_fees" do
    # 7,42 % de 200 000 € font 14 840 €, que la part fixe porte à 16 612 €.
    it "is a share of the price raised by a fixed part" do
      expect(build(:simulation, purchase_price: 200_000).notary_fees).to eq(16_612)
    end

    it "follows the price and nothing else" do
      expect(build(:simulation, purchase_price: 100_000).notary_fees).to eq(9_192)
    end

    # La page de l'achat s'affiche avant qu'un prix n'y soit tapé : elle ne doit pas
    # annoncer la part fixe toute seule, comme si un bien à zéro euro coûtait 1 772 € de notaire.
    it "is nothing as long as no price has been named" do
      expect(build(:simulation, purchase_price: nil).notary_fees).to eq(0)
    end
  end

  describe "#total_investment" do
    it "adds the notary fees and the initial works to the price" do
      expect(build(:simulation, purchase_price: 200_000, initial_works: 15_000).total_investment).to eq(231_612)
    end
  end

  describe "the credit" do
    subject(:simulation) do
      build(:simulation, :with_credit, purchase_price: 200_000, initial_works: 0, down_payment: 23_388)
    end

    # Le coût du projet moins l'apport : 216 612 − 23 388.
    it "borrows what the down payment does not cover" do
      expect(simulation.borrowed_capital).to eq(193_224)
    end

    # La simulation ne fait que déduire le crédit de ses colonnes : c'est Loan qui sait
    # ensuite ce qu'il prélève et ce qu'il coûte.
    it "hands the loan what the columns answered" do
      expect(simulation.loan).to have_attributes(capital: 193_224, annual_rate: 3, duration_years: 20,
                                                 signed_on: simulation.purchase_date)
    end

    # Le cautionnement et les frais de dossier vont au crédit comme le reste : c'est lui qui
    # sait ensuite qu'ils se paient à la signature.
    it "hands the loan the fees the signature costs" do
      with_fees = build(:simulation, :with_credit, loan_guarantee_fees: 3_220, loan_application_fees: 1_932)

      expect(with_fees.loan).to have_attributes(guarantee_fees: 3_220, application_fees: 1_932)
    end

    it "borrows nothing when the purchase is paid outright" do
      paid_outright = build(:simulation, credit: false)

      expect(paid_outright.borrowed_capital).to eq(0)
      expect(paid_outright.loan.schedule).to be_nil
    end

    # Le capital emprunté n'est pas immobilisé : il se rembourse par les annuités, que la
    # projection retranche du cash-flow. Le compter deux fois ferait payer le bien deux fois.
    it "immobilizes the down payment alone, where a purchase paid outright immobilizes it all" do
      expect(simulation.initial_outlay).to eq(23_388)
      expect(build(:simulation, credit: false, purchase_price: 200_000, initial_works: 0).initial_outlay)
        .to eq(216_612)
    end

    # Cautionnement et frais de dossier se paient le même jour que l'apport, et sortent de la
    # même poche : 23 388 + 3 220 + 1 932.
    it "immobilizes the fees the signature costs next to the down payment" do
      with_fees = build(:simulation, :with_credit, purchase_price: 200_000, initial_works: 0,
                                                   down_payment: 23_388, loan_guarantee_fees: 3_220,
                                                   loan_application_fees: 1_932)

      expect(with_fees.initial_outlay).to eq(28_540)
    end

    # Renoncer au crédit, c'est cesser d'en porter les conditions — et le crédit déjà lu ne
    # doit pas survivre à la case qui le déclarait.
    it "clears what a purchase paid outright no longer answers" do
      saved = create(:simulation, :with_credit, loan_insurance: 19.32, loan_guarantee_fees: 3_220,
                                                loan_application_fees: 1_932)
      saved.loan

      saved.update(credit: false)

      expect(saved.reload).to have_attributes(down_payment: 0, loan_rate: 0, loan_duration_years: 0,
                                              loan_insurance: 0, loan_guarantee_fees: 0,
                                              loan_application_fees: 0)
      expect(saved.loan.schedule).to be_nil
    end
  end

  # Ce qui se déclare : la provision n'est pas un revenu, et la dépense qu'elle rembourse n'est
  # pas déductible. Les deux sortent ensemble, sous l'un comme sous l'autre régime.
  describe "#annual_charges_excluding_provision" do
    it "takes the provision the tenant reimburses out of the charges" do
      let_out = build(:simulation, monthly_charges: 100, occupancy_months: 12, condominium: true,
                                   property_tax: 700, condominium_fees: 1_500)

      expect(let_out.annual_provision_for_charges).to eq(1_200)
      expect(let_out.annual_charges_excluding_provision).to eq(1_000)
    end

    it "is what the foncier réel deducts from the rent excluding charges" do
      let_out = build(:simulation, monthly_rent: 1_000, monthly_charges: 100, occupancy_months: 12,
                                   condominium: true, condominium_fees: 1_500)

      expect(let_out.taxation(:foncier_reel).taxable_income).to eq(12_000 - 300)
    end
  end

  describe "#annual_cash_flow" do
    # Le cash-flow d'une année pleine, celui que la liste des simulations met en avant :
    # l'impôt y pèse comme les charges et l'annuité — 12,04 % de 9 600 € de loyers.
    it "takes the taxes and the annuity out of what the charges leave of the rent" do
      simulation = build(:simulation, :with_credit, purchase_price: 200_000, initial_works: 0,
                                                    down_payment: 23_388, monthly_rent: 800,
                                                    occupancy_months: 12, property_tax: 700)

      expect(simulation.annual_taxes).to eq(BigDecimal("1155.84"))
      expect(simulation.annual_cash_flow)
        .to eq(9_600 - 700 - BigDecimal("1155.84") - BigDecimal("1071.62") * 12)
    end
  end

  describe "#projection" do
    it "hands the projection this simulation" do
      expect(build(:simulation).projection(:micro_foncier)).to be_a(Projection)
    end
  end
end
