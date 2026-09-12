module Taxation
  # Le LMNP au réel : charges, CFE, comptable et intérêts déduits pour de vrai, plus
  # l'amortissement du plan. Pas de déficit : l'excédent se reporte sans limite.
  class Lmnp < Bic
    attr_reader :depreciation_lines, :deferred_depreciation, :capitalized_lines

    def own_charge_lines = super.merge(accounting_fees: accounting_fees)

    def capitalized = capitalized_lines.values.sum

    def result_before_depreciation = [receipts - charges - own_charges + capitalized - loan_interest, 0].max

    def available_depreciation
      depreciation_lines.merge(deferred_depreciation) { |_, annuity, deferred| annuity + deferred }
    end

    def deducted_depreciation_lines
      @deducted_depreciation_lines ||= begin
        room = result_before_depreciation

        DepreciationPlan::COMPONENTS.keys.filter_map do |component|
          amount = [available_depreciation.fetch(component, 0), room].min
          room -= amount
          [component, amount] unless amount.zero?
        end.to_h
      end
    end

    def depreciation = deducted_depreciation_lines.values.sum

    def carried_forward_depreciation
      available_depreciation.filter_map do |component, amount|
        remaining = amount - deducted_depreciation_lines.fetch(component, 0)
        [component, remaining] unless remaining.zero?
      end.to_h
    end

    def taxable_income = result_before_depreciation - depreciation
  end
end
