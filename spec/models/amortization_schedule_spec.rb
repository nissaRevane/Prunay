require "rails_helper"

RSpec.describe AmortizationSchedule do
  # 200 000 € de prix et 16 612 € de frais de notaire font 216 612 € de projet ; l'apport de
  # 23 388 € en laisse 193 224 € à emprunter, sur vingt ans à 3 %.
  let(:simulation) { build(:simulation, :with_credit, purchase_date: Date.new(2025, 1, 15)) }
  let(:schedule) { described_class.new(simulation) }

  describe "#monthly_payment" do
    # M = C × i / (1 − (1 + i)^−n), arrondie au centime comme une banque l'énonce.
    it "is what it takes to clear the capital over the whole duration" do
      expect(schedule.monthly_payment).to eq(BigDecimal("1071.62"))
    end

    # Un prêt à taux zéro n'a pas d'intérêts à étaler : il se rend en parts égales.
    it "shares the capital out in equal parts when nothing is charged for it" do
      free = build(:simulation, :with_credit, purchase_price: 100_000, down_payment: 92_808,
                                              loan_rate: 0, loan_duration_years: 1)

      expect(described_class.new(free).monthly_payment).to eq(BigDecimal("1365.33"))
    end
  end

  describe "#rows" do
    it "runs one line per month of the duration" do
      expect(schedule.rows.size).to eq(240)
      expect(schedule.rows.map(&:number)).to eq((1..240).to_a)
    end

    # Le prélèvement tombe le 5 : celui du mois qui suit la signature, quel que soit le jour
    # de l'acte, puis un mois après l'autre.
    it "falls on the fifth of the month after the purchase, then month by month" do
      expect(schedule.rows.first.due_on).to eq(Date.new(2025, 2, 5))
      expect(schedule.rows.second.due_on).to eq(Date.new(2025, 3, 5))

      month_end = build(:simulation, :with_credit, purchase_date: Date.new(2025, 1, 31))
      expect(described_class.new(month_end).rows.first.due_on).to eq(Date.new(2025, 2, 5))
    end

    # Un acte signé du 1er au 5 n'attend pas un mois de plus : le 5 de son propre mois n'est
    # pas encore passé, et c'est celui-là qui ouvre le remboursement.
    it "starts in the month of the purchase itself when the fifth is still ahead" do
      early = build(:simulation, :with_credit, purchase_date: Date.new(2025, 1, 3))
      on_the_day = build(:simulation, :with_credit, purchase_date: Date.new(2025, 1, 5))

      expect(described_class.new(early).rows.first.due_on).to eq(Date.new(2025, 1, 5))
      expect(described_class.new(on_the_day).rows.first.due_on).to eq(Date.new(2025, 1, 5))
    end

    # Intérêts = CRD × taux mensuel, capital = mensualité − intérêts : le capital remboursé
    # grossit d'échéance en échéance, à mensualité constante.
    it "splits each payment between the interest the capital owes and the capital itself" do
      first = schedule.rows.first

      # 193 224 × 3 % / 12 = 483,06
      expect(first).to have_attributes(interest: BigDecimal("483.06"), principal: BigDecimal("588.56"),
                                       payment: BigDecimal("1071.62"), remaining_capital: BigDecimal("192635.44"))
      expect(schedule.rows.second.interest).to be < first.interest
      expect(schedule.rows.second.principal).to be > first.principal
    end

    # La mensualité arrondie au centime laisse un résidu au bout de vingt ans : la dernière
    # échéance le solde, plutôt que de le laisser traîner sous une ligne à zéro.
    it "settles the rounding residue on the last payment and ends at nothing" do
      last = schedule.rows.last

      expect(last.principal).to eq(schedule.rows[-2].remaining_capital)
      expect(last.remaining_capital).to eq(0)
    end
  end

  describe "#annual_payments" do
    # Douze échéances par année de la projection : la première année porte les échéances 1 à
    # 12, et rien ne dépasse la durée du prêt.
    it "gathers the payments twelve by twelve" do
      expect(schedule.annual_payments[1]).to eq(BigDecimal("1071.62") * 12)
      expect(schedule.annual_payments.keys).to eq((1..20).to_a)
    end

    # La dernière année ne porte que ce qui reste à payer : l'échéance soldée est plus légère.
    it "gives the last year only what is left to pay" do
      expect(schedule.annual_payments[20]).to eq(BigDecimal("12857.95"))
      expect(schedule.annual_payments[21]).to be_nil
    end
  end

  describe "#total_interest" do
    it "is what the credit costs on top of the capital" do
      expect(schedule.total_interest).to eq(BigDecimal("63963.31"))
      expect(schedule.total_payments - schedule.total_interest).to eq(simulation.borrowed_capital)
    end
  end
end
