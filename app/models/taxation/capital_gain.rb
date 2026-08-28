module Taxation
  # L'impôt qu'une revente coûte au particulier : la plus-value se compte sur la valeur fiscale
  # du bien — le prix payé, ses frais d'acquisition et, passé cinq ans, les travaux que le fisc
  # suppose — puis s'efface avec la durée de détention (voir #income_tax et #social_charges).
  class CapitalGain
    # Le taux propre à la plus-value immobilière : le barème du foyer n'y est pour rien.
    INCOME_TAX_RATE = BigDecimal("19")

    # Le forfait travaux : 15 % du prix d'achat, sans justificatif, dès la sixième année de
    # détention. Les travaux réellement payés en tiennent lieu au choix du vendeur — Prunay ne
    # simule que le forfait.
    ASSUMED_WORKS_RATE = BigDecimal("15")

    ASSUMED_WORKS_AFTER_YEARS = 5

    # L'abattement pour durée de détention, par tranche d'années et en points par année : la
    # plus-value échappe au barème au bout de vingt-deux ans, aux prélèvements sociaux au bout
    # de trente. Les deux rythmes cumulent à 100 exactement.
    INCOME_TAX_ALLOWANCE = { (6..21) => BigDecimal("6"), (22..22) => BigDecimal("4") }.freeze

    SOCIAL_CHARGES_ALLOWANCE = { (6..21) => BigDecimal("1.65"), (22..22) => BigDecimal("1.60"),
                                 (23..30) => BigDecimal("9") }.freeze

    attr_reader :sale_price, :purchase_price, :acquisition_fees, :held_years

    def initialize(sale_price:, purchase_price:, acquisition_fees:, held_years:)
      # Décimaux d'office, comme partout ailleurs : un taux entier ferait une division entière.
      @sale_price = sale_price.to_d
      @purchase_price = purchase_price.to_d
      @acquisition_fees = acquisition_fees.to_d
      @held_years = held_years.to_i
    end

    # Ce que le bien vaut aux yeux du fisc : le prix d'achat n'est jamais seul.
    def fiscal_value
      purchase_price + acquisition_fees + assumed_works
    end

    def assumed_works
      return 0 if held_years <= ASSUMED_WORKS_AFTER_YEARS

      share(purchase_price, ASSUMED_WORKS_RATE)
    end

    # Une moins-value ne se déduit de rien : elle ne doit simplement rien.
    def amount
      [sale_price - fiscal_value, 0].max
    end

    def income_tax_allowance_rate
      allowance_rate(INCOME_TAX_ALLOWANCE)
    end

    def social_charges_allowance_rate
      allowance_rate(SOCIAL_CHARGES_ALLOWANCE)
    end

    def income_tax
      share(taxable_amount(income_tax_allowance_rate), INCOME_TAX_RATE)
    end

    def social_charges
      share(taxable_amount(social_charges_allowance_rate), SOCIAL_CHARGES_RATE)
    end

    # Ce que la revente coûte en tout : la fiche de l'année le retranche du produit.
    def total
      income_tax + social_charges
    end

    private

    def allowance_rate(schedule)
      schedule.sum { |years, rate| rate * years.count { |year| year <= held_years } }
    end

    def taxable_amount(allowance_rate)
      amount * (100 - allowance_rate) / 100
    end

    def share(amount, rate)
      (amount * rate / 100).round(2)
    end
  end
end
