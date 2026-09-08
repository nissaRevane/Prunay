class AddAccountingFeesToSimulations < ActiveRecord::Migration[8.0]
  # Les honoraires du comptable, que l'amortissement du LMNP rend presque obligatoires. La
  # colonne revient — elle avait disparu avec le type d'exploitation — parce que le régime,
  # lui, est revenu : c'est la seule charge qu'un seul régime paie et que l'utilisateur saisit.
  # Zéro par défaut comme les autres charges : les simulations écrites avant n'ont rien répondu.
  def change
    add_column :simulations, :accounting_fees, :decimal, precision: 12, scale: 2, null: false, default: 0
  end
end
