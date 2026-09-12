module Users
  class PasswordsController < Devise::PasswordsController
    # Chaque demande part en courrier : cinq par heure et par IP.
    throttle name: "reset_password", to: 5, within: 1.hour, only: :create
  end
end
