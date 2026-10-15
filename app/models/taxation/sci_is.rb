module Taxation
  # La SCI à l'IS, en location nue : la société déduit tout, l'amortissement sans plafond, et
  # son déficit se reporte. Ce qui remonte à l'associé relève de Distribution et Liquidation.
  class SciIs < Regime
    REDUCED_RATE = BigDecimal("15")

    # Le taux réduit des PME s'arrête là (art. 219 CGI).
    REDUCED_RATE_CEILING = 42_500

    STANDARD_RATE = BigDecimal("25")

    # Statuts, annonce légale, immatriculation : un ordre de grandeur, pas un devis.
    FORMATION_COSTS = 1_000

    LIQUIDATION_COSTS = 1_000

    def self.company? = true

    def self.formation_costs = FORMATION_COSTS

    def self.corporate_tax_on(profit)
      profit = [profit, 0].max
      reduced = [profit, REDUCED_RATE_CEILING].min

      ((reduced * REDUCED_RATE + (profit - reduced) * STANDARD_RATE) / 100).round(2)
    end

    def depreciation_lines = @depreciation_lines.except(:furniture)

    def capitalized_lines = @capitalized_lines.except(:furniture)

    def capitalized = capitalized_lines.values.sum

    def deducted_depreciation_lines = depreciation_lines

    def depreciation = depreciation_lines.values.sum

    def own_charge_lines = { accounting_fees: accounting_fees }

    def result = receipts - charges - own_charges + capitalized - loan_interest - depreciation - formation_costs

    def taxable_result = result - deferred_deficit

    def taxable_income = [taxable_result, 0].max

    def carried_forward_deficit = [-taxable_result, 0].max

    def income_tax = 0

    def social_charges = 0

    def corporate_tax = self.class.corporate_tax_on(taxable_income)

    def total = corporate_tax

    def net_income = result - corporate_tax
  end
end
