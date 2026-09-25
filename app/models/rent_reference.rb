# Le loyer d'annonce au m² des cent plus grandes villes, lu dans le baromètre Pierria versionné
# à côté du code. Ce sont des loyers charges comprises : un repère de marché, pas un loyer.
class RentReference
  PATH = Rails.root.join("db/data/barometre_pierria.csv")

  SOURCE_URL = "https://pierria.fr/barometre/".freeze

  HEADERS = %w[ville departement code_insee loyer_m2_2025_eur loyer_m2_t1_t2_eur loyer_m2_t3_plus_eur
               loyer_m2_maison_eur annonces_observees evolution_loyer_2022_2025_pct prix_vente_m2_2025_eur
               ventes_2025 rendement_brut_pct].freeze

  SEPARATOR = ";".freeze

  BYTE_ORDER_MARK = "﻿".freeze

  # Au-delà, le baromètre range le logement avec les T3 et plus.
  SMALL_APARTMENT_SURFACE = 50

  COLUMNS = {
    "apartment" => { small: "loyer_m2_t1_t2_eur", large: "loyer_m2_t3_plus_eur" },
    "house" => { small: "loyer_m2_maison_eur", large: "loyer_m2_maison_eur" }
  }.freeze

  ANY_HOUSING_COLUMN = "loyer_m2_2025_eur".freeze

  class << self
    def for(city) = city.present? ? all[fold(city)] : nil

    def covers?(property_type) = COLUMNS.key?(property_type.to_s)

    def all = @all ||= parse(File.read(PATH))

    def parse(content)
      lines = rows(content)
      headers = lines.shift.split(SEPARATOR)

      lines.to_h do |line|
        row = headers.zip(line.split(SEPARATOR, -1)).to_h

        [fold(row["ville"]), new(row)]
      end
    end

    def rows(content) = content.delete_prefix(BYTE_ORDER_MARK).split("\n").map(&:strip).reject(&:empty?)

    def fold(name) = name.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase.strip
  end

  attr_reader :city, :department, :code_insee

  def initialize(row)
    @row = row
    @city = row["ville"]
    @department = row["departement"]
    @code_insee = row["code_insee"]
  end

  def listings = @row["annonces_observees"].to_i

  def rent_per_square_meter(property_type, surface)
    columns = COLUMNS[property_type.to_s]
    return nil if columns.nil? || surface.blank? || surface.to_d <= 0

    decimal(columns[surface.to_d <= SMALL_APARTMENT_SURFACE ? :small : :large]) || decimal(ANY_HOUSING_COLUMN)
  end

  def monthly_rent(property_type, surface)
    rate = rent_per_square_meter(property_type, surface)

    rate && (rate * surface.to_d).round
  end

  private

  def decimal(column)
    value = @row[column].to_s.tr(",", ".").strip

    value.present? ? BigDecimal(value, exception: false) : nil
  end
end
