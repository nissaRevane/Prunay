# Les montants proposés au premier affichage, mis à l'échelle de la surface du bien. Ce sont
# des ordres de grandeur, pas des vérités : le formulaire les affiche pré-remplis pour que
# l'utilisateur les corrige, pas pour qu'il les subisse.
module Simulation::Estimate
  # Les références sont énoncées pour une surface de 50 m².
  REFERENCE_SURFACE = 50

  AMOUNTS = {
    monthly_rent: 650,
    property_tax: 700,
    insurance: 150,
    condominium_fees: 1_000,
    business_tax: 200,
    other_charges: 100
  }.freeze

  # En copropriété les charges de copro portent déjà façade, toiture et communs — d'où le double.
  MAINTENANCE_AMOUNTS = { condominium: 1_000, sole_owner: 2_000 }.freeze

  # Ce qui ne suit pas la surface : un forfait, ou un montant que l'on ne suppose pas.
  FIXED_AMOUNTS = { management_fees: 0, rent_guarantee: 0, accounting_fees: 500 }.freeze

  # L'apport qu'une banque attend pour couvrir les frais de notaire sans les financer.
  DOWN_PAYMENT_SHARE = BigDecimal("0.10")

  # Une estimation au centime se lirait comme un calcul, alors que ce n'en est pas un.
  ROUNDING = 10

  module_function

  # La racine carrée, et non la proportion : un logement double ne se loue pas au double du prix.
  def for(field, surface, condominium: false)
    return FIXED_AMOUNTS.fetch(field) if FIXED_AMOUNTS.key?(field)

    surface = surface.to_f
    return 0 unless surface.positive?

    round(reference(field, condominium: condominium) * Math.sqrt(surface / REFERENCE_SURFACE))
  end

  def down_payment(total_investment)
    round(total_investment * DOWN_PAYMENT_SHARE)
  end

  def round(amount)
    (amount / ROUNDING).round * ROUNDING
  end

  def reference(field, condominium: false)
    return MAINTENANCE_AMOUNTS.fetch(condominium ? :condominium : :sole_owner) if field == :maintenance

    AMOUNTS.fetch(field)
  end
end
