class AddLoanFeesToSimulations < ActiveRecord::Migration[8.0]
  # Ce que le crédit coûte à la signature, une fois pour toutes : le cautionnement — la
  # caution bancaire ou l'hypothèque qui garantit le prêt — et les frais de dossier. Deux
  # montants et non deux taux : c'est ainsi que l'offre de prêt les énonce.
  #
  # Zéro par défaut, comme les autres colonnes du crédit : c'est la seule réponse qu'on
  # puisse prêter à un achat comptant, et aux simulations écrites avant cette migration.
  def change
    add_column :simulations, :loan_guarantee_fees, :decimal, precision: 12, scale: 2, null: false, default: 0
    add_column :simulations, :loan_application_fees, :decimal, precision: 12, scale: 2, null: false, default: 0
  end
end
