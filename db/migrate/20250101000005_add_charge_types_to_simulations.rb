class AddChargeTypesToSimulations < ActiveRecord::Migration[8.0]
  # Les charges annuelles que la page 4 ne demandait pas encore. Toutes portent un défaut à
  # zéro : les simulations écrites avant cette migration n'ont jamais répondu à ces
  # questions, et zéro est la seule réponse qu'on puisse leur prêter sans mentir.
  #
  # Trois d'entre elles ne se demandent que sous condition — les charges de copropriété pour
  # un bien en copropriété, la CFE et le comptable pour un meublé. La condition vit dans le
  # modèle, pas ici : la colonne existe toujours, elle reste simplement à zéro quand la
  # question ne se pose pas.
  def change
    add_column :simulations, :condominium_fees, :decimal, precision: 12, scale: 2, null: false, default: 0
    add_column :simulations, :management_fees, :decimal, precision: 12, scale: 2, null: false, default: 0
    add_column :simulations, :rent_guarantee, :decimal, precision: 12, scale: 2, null: false, default: 0
    add_column :simulations, :business_tax, :decimal, precision: 12, scale: 2, null: false, default: 0
    add_column :simulations, :accounting_fees, :decimal, precision: 12, scale: 2, null: false, default: 0
  end
end
