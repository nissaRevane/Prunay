module Taxation
  # Le LMNP au réel : les recettes du meublé, mais rien de forfaitaire — charges, CFE,
  # honoraires du comptable et intérêts d'emprunt déduits pour de vrai, et par-dessus
  # l'amortissement du bâti, une dépense que rien ne décaisse. L'excédent ne se reporte pas,
  # non plus que le déficit : une année sans bénéfice ne doit rien, et rien ne passe à la suivante.
  class Lmnp < Bic
    # Le terrain ne s'amortit pas : Prunay lui laisse forfaitairement un cinquième du prix payé.
    DEPRECIATED_SHARE = BigDecimal("0.80")

    # Une durée moyenne pour le bâti, là où le fisc attend un plan par composant.
    DEPRECIATION_YEARS = 25

    # Le comptable, que seul ce régime paie : c'est l'amortissement qui le rend nécessaire.
    def own_charge_lines = super.merge(accounting_fees: accounting_fees)

    # Le plan s'ouvre à la première année louée et s'éteint après la vingt-cinquième.
    def depreciation
      return 0 unless year.between?(1, DEPRECIATION_YEARS)

      (purchase_price * DEPRECIATED_SHARE / DEPRECIATION_YEARS).round(2)
    end

    def taxable_income = [receipts - charges - own_charges - loan_interest - depreciation, 0].max
  end
end
