class AddMonthlyChargesToSimulations < ActiveRecord::Migration[8.0]
  # Le loyer se détaille : hors charges d'un côté, provision pour charges de l'autre. Seul le
  # loyer hors charges est imposable, d'où le besoin de les séparer. Zéro par défaut : le
  # montant déjà saisi était un loyer hors charges, et rien ne s'y ajoutait.
  def change
    add_column :simulations, :monthly_charges, :decimal, precision: 12, scale: 2, null: false, default: 0
  end
end
