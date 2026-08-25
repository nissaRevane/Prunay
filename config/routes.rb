Prunay::Application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }

  # Devise's account page, under a name of its own: /mon-compte gathers the identity
  # and the password change instead of leaving them scattered in the navbar.
  devise_scope :user do
    get "mon-compte", to: "users/registrations#edit", as: :account
  end

  # L'accueil d'un utilisateur connecté est son tableau de bord ; la page publique reste
  # la vitrine, pour les visiteurs.
  authenticated :user do
    root "dashboard#show", as: :authenticated_root
  end

  root "pages#home"
end
