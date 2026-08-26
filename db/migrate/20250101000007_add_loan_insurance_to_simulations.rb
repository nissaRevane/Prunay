class AddLoanInsuranceToSimulations < ActiveRecord::Migration[8.0]
  # L'assurance emprunteur : la banque ne prête pas sans elle, et sa prime se prélève avec
  # l'échéance. On stocke la mensualité — le montant que l'assureur prélève chaque mois —
  # et non un taux : c'est ce que l'emprunteur lit sur son offre, et le taux qui la
  # proposerait au premier affichage vit dans le modèle (Simulation::DEFAULT_LOAN_INSURANCE_RATE).
  #
  # Zéro par défaut, comme les trois autres colonnes du crédit : c'est la seule réponse
  # qu'on puisse prêter à un achat comptant, et aux simulations écrites avant cette migration.
  def change
    add_column :simulations, :loan_insurance, :decimal, precision: 12, scale: 2, null: false, default: 0
  end
end
