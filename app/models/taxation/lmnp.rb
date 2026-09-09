module Taxation
  # Le LMNP au réel : les recettes du meublé, mais rien de forfaitaire — charges, CFE,
  # honoraires du comptable et intérêts d'emprunt déduits pour de vrai, et par-dessus
  # l'amortissement du plan (voir DepreciationPlan), une dépense que rien ne décaisse. Il ne
  # crée pas de déficit : ce que l'année ne peut déduire se reporte sans limite sur les suivantes.
  class Lmnp < Bic
    # Le plan de l'année et le report des précédentes, que ce régime seul lit.
    attr_reader :depreciation_lines, :deferred_depreciation

    # Le comptable, que seul ce régime paie : c'est l'amortissement qui le rend nécessaire.
    def own_charge_lines = super.merge(accounting_fees: accounting_fees)

    def result_before_depreciation = [receipts - charges - own_charges - loan_interest, 0].max

    # L'annuité de l'année et le report des précédentes, composant par composant.
    def available_depreciation
      depreciation_lines.merge(deferred_depreciation) { |_, annuity, deferred| annuity + deferred }
    end

    # Le bâti d'abord, seul à revenir dans la plus-value ; un choix de Prunay, la loi raisonnant en masse.
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

    # Ce que l'année suivante recevra en report.
    def carried_forward_depreciation
      available_depreciation.filter_map do |component, amount|
        remaining = amount - deducted_depreciation_lines.fetch(component, 0)
        [component, remaining] unless remaining.zero?
      end.to_h
    end

    def taxable_income = result_before_depreciation - depreciation
  end
end
