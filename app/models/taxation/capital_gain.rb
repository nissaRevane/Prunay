module Taxation
  # L'impôt d'une revente : la plus-value se compte sur la valeur fiscale du bien, moins les
  # amortissements déjà déduits, puis s'efface avec la durée de détention.
  class CapitalGain
    INCOME_TAX_RATE = BigDecimal("19")

    # Forfait travaux sans justificatif, dès la sixième année de détention.
    ASSUMED_WORKS_RATE = BigDecimal("15")

    ASSUMED_WORKS_AFTER_YEARS = 5

    # Exonéré de barème à vingt-deux ans, de sociaux à trente.
    INCOME_TAX_ALLOWANCE = { (6..21) => BigDecimal("6"), (22..22) => BigDecimal("4") }.freeze

    SOCIAL_CHARGES_ALLOWANCE = { (6..21) => BigDecimal("1.65"), (22..22) => BigDecimal("1.60"),
                                 (23..30) => BigDecimal("9") }.freeze

    attr_reader :sale_price, :purchase_price, :acquisition_fees, :held_years, :depreciation

    def initialize(sale_price:, purchase_price:, acquisition_fees:, held_years:, depreciation: 0)
      @sale_price = sale_price.to_d
      @purchase_price = purchase_price.to_d
      @acquisition_fees = acquisition_fees.to_d
      @held_years = held_years.to_i
      @depreciation = depreciation.to_d
    end

    def acquisition_value = purchase_price + acquisition_fees + assumed_works

    def fiscal_value = acquisition_value - depreciation

    def assumed_works
      return 0 if held_years <= ASSUMED_WORKS_AFTER_YEARS

      share(purchase_price, ASSUMED_WORKS_RATE)
    end

    def amount = [sale_price - fiscal_value, 0].max

    def income_tax_allowance_rate = allowance_rate(INCOME_TAX_ALLOWANCE)

    def social_charges_allowance_rate = allowance_rate(SOCIAL_CHARGES_ALLOWANCE)

    def income_tax = share(taxable_amount(income_tax_allowance_rate), INCOME_TAX_RATE)

    def social_charges = share(taxable_amount(social_charges_allowance_rate), SOCIAL_CHARGES_RATE)

    def total = income_tax + social_charges

    private

    def allowance_rate(schedule) = schedule.sum { |years, rate| rate * years.count { |year| year <= held_years } }

    def taxable_amount(allowance_rate) = amount * (100 - allowance_rate) / 100

    def share(amount, rate) = (amount * rate / 100).round(2)
  end
end
