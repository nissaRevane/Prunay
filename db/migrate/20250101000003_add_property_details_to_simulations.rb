class AddPropertyDetailsToSimulations < ActiveRecord::Migration[8.0]
  # Tout ce que le formulaire en quatre pages demande, en une seule migration : le bien,
  # les travaux initiaux, l'exploitation et les charges annuelles. Chaque colonne porte un
  # défaut pour que les simulations écrites avant ces pages restent lisibles.
  def change
    # Page 1 — le bien.
    add_column :simulations, :property_type, :string, null: false, default: "apartment"
    add_column :simulations, :address, :string
    add_column :simulations, :city, :string, null: false, default: ""
    add_column :simulations, :energy_rating, :string
    add_column :simulations, :surface, :decimal, precision: 8, scale: 2, null: false, default: 0
    add_column :simulations, :condominium, :boolean, null: false, default: false

    # La surface est la seule colonne à perdre son défaut aussitôt posée : c'est la première
    # question du formulaire, et un « 0 » pré-rempli dans un champ obligatoire se lirait
    # comme une réponse. Le zéro n'a servi qu'à remplir les lignes écrites avant cette
    # migration.
    change_column_default :simulations, :surface, from: 0, to: nil

    # Page 2 — l'achat. Le prix et la date existaient déjà.
    add_column :simulations, :initial_works, :decimal, precision: 12, scale: 2, null: false, default: 0

    # Page 3 — la location. Le loyer mensuel existait déjà.
    add_column :simulations, :occupancy_months, :decimal, precision: 4, scale: 1, null: false, default: 11
    add_column :simulations, :rental_type, :string, null: false, default: "furnished"

    # Page 4 — les charges annuelles.
    add_column :simulations, :property_tax, :decimal, precision: 12, scale: 2, null: false, default: 0
    add_column :simulations, :maintenance, :decimal, precision: 12, scale: 2, null: false, default: 0
    add_column :simulations, :insurance, :decimal, precision: 12, scale: 2, null: false, default: 0
    add_column :simulations, :other_charges, :decimal, precision: 12, scale: 2, null: false, default: 0
  end
end
