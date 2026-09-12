module Users
  class SessionsController < Devise::SessionsController
    # Dix essais par cinq minutes : de quoi se tromper, pas d'en essayer mille.
    throttle name: "sign_in", to: 10, within: 5.minutes, only: :create
  end
end
