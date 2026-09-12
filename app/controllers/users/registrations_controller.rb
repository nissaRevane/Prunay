module Users
  class RegistrationsController < Devise::RegistrationsController
    # Un compte gratuit, les robots en créent en série : cinq par heure et par IP.
    throttle name: "sign_up", to: 5, within: 1.hour, only: :create

    protected

    def after_update_path_for(_resource)
      account_path
    end
  end
end
