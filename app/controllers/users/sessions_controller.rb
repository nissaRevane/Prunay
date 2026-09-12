module Users
  # Devise fait tout le travail : seule s'ajoute la limite qui décourage l'essai de mots de passe.
  class SessionsController < Devise::SessionsController
    throttle name: "sign_in", to: 10, within: 5.minutes, only: :create
  end
end
