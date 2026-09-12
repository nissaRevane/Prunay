module Users
  # Chaque demande part en courrier : mieux vaut qu'un robot n'en déclenche pas mille.
  class PasswordsController < Devise::PasswordsController
    throttle name: "reset_password", to: 5, within: 1.hour, only: :create
  end
end
