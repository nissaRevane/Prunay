require "json"
require "net/http"

# Rafraîchit le baromètre Pierria versionné dans db/data : une édition par trimestre, relancée à la
# main. Le fichier en place n'est remplacé que par un téléchargement complet et relu.
module RentReferenceUpdate
  DATASET_URL = "https://www.data.gouv.fr/api/1/datasets/6aa7112323a7e8d96bdb24c5/".freeze

  MINIMUM_CITIES = 50

  REDIRECT_LIMIT = 3

  INSEE_CODE = /\A\w{5}\z/

  module_function

  def resource
    found = JSON.parse(fetch(DATASET_URL))["resources"].find { |candidate| candidate["format"] == "csv" }

    raise "Aucune ressource CSV dans le jeu de données." if found.nil?

    found
  end

  def fetch(url, redirects = REDIRECT_LIMIT)
    response = Net::HTTP.get_response(URI(url))

    case response
    when Net::HTTPSuccess then response.body.force_encoding(Encoding::UTF_8)
    when Net::HTTPRedirection then follow(response, redirects)
    else raise "#{url} répond #{response.code}."
    end
  end

  def follow(response, redirects)
    raise "Trop de redirections." unless redirects.positive?

    fetch(response["location"], redirects - 1)
  end

  def validate(content)
    headers = RentReference.rows(content).first.to_s.split(RentReference::SEPARATOR)
    raise "Colonnes inattendues : #{headers.join(', ')}." unless headers == RentReference::HEADERS

    references = RentReference.parse(content).values
    raise "Seulement #{references.size} villes téléchargées." if references.size < MINIMUM_CITIES

    references.each { |reference| validate_city(reference) }
  end

  def validate_city(reference)
    raise "Code INSEE illisible : #{reference.code_insee.inspect}." unless reference.code_insee.to_s.match?(INSEE_CODE)
    raise "Loyer illisible à #{reference.city}." if reference.rent_per_square_meter("apartment", 100).nil?
  end
end

namespace :rent_reference do
  desc "Télécharge la dernière édition du baromètre Pierria dans db/data"
  task update: :environment do
    resource = RentReferenceUpdate.resource
    content = RentReferenceUpdate.fetch(resource["url"])
    cities = RentReferenceUpdate.validate(content)

    File.write(RentReference::PATH, content)

    puts "#{cities.size} villes écrites dans #{RentReference::PATH} — #{resource['title']}."
  end
end
