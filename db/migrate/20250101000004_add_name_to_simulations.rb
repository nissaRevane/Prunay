class AddNameToSimulations < ActiveRecord::Migration[8.0]
  # Le nom d'une simulation, jusqu'ici déduit du bien à chaque affichage, devient une
  # colonne : il peut se saisir dès la première page de la création, et à défaut le modèle
  # l'écrit au dernier écran. Une chaîne vide comme défaut, jamais NULL — un nom absent est
  # un nom vide, pas un nom inconnu.
  def up
    add_column :simulations, :name, :string, null: false, default: ""

    # Les lignes écrites avant cette colonne prennent le nom qu'elles affichaient déjà.
    # Le modèle est appelé ici parce que le libellé du type de bien vient des traductions :
    # aucune requête SQL ne saurait le reconstituer.
    Simulation.reset_column_information
    Simulation.find_each { |simulation| simulation.update_column(:name, simulation.default_name) }
  end

  def down
    remove_column :simulations, :name
  end
end
