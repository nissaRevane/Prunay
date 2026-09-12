module Users
  # Devise handles the password change itself; only the landing spot changes, so the
  # confirmation flash shows up on the account page the form was submitted from
  # rather than on the application root.
  class RegistrationsController < Devise::RegistrationsController
    # Un compte gratuit est un compte que les robots créent en série : cinq par heure et par IP.
    throttle name: "sign_up", to: 5, within: 1.hour, only: :create

    protected

    def after_update_path_for(_resource)
      account_path
    end
  end
end
