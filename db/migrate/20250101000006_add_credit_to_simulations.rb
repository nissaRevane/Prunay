class AddCreditToSimulations < ActiveRecord::Migration[8.0]
  # Le financement du projet. `credit` est la réponse qui gouverne les trois autres colonnes :
  # sans crédit, l'achat se paie comptant et l'apport, le taux et la durée n'ont rien à dire —
  # d'où leur défaut à zéro, qui est aussi la seule réponse qu'on puisse prêter aux
  # simulations écrites avant cette migration.
  #
  # Le capital emprunté, la mensualité et le tableau d'amortissement ne sont pas stockés : ils
  # se déduisent de ces quatre réponses et du coût du projet, et les stocker reviendrait à
  # risquer qu'ils démentent un jour les chiffres affichés à côté d'eux (voir les frais de
  # notaire, déjà calculés de la même façon).
  def change
    add_column :simulations, :credit, :boolean, null: false, default: false
    add_column :simulations, :down_payment, :decimal, precision: 12, scale: 2, null: false, default: 0
    add_column :simulations, :loan_rate, :decimal, precision: 6, scale: 3, null: false, default: 0
    add_column :simulations, :loan_duration_years, :integer, null: false, default: 0
  end
end
