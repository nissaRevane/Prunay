Prunay::Application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }

  # Devise's account page, under a name of its own: /mon-compte gathers the identity
  # and the password change instead of leaving them scattered in the navbar.
  devise_scope :user do
    get "mon-compte", to: "users/registrations#edit", as: :account
  end

  # L'accueil d'un utilisateur connecté est la liste de ses simulations ; la page publique
  # reste la vitrine, pour les visiteurs. Il n'y a pas de tableau de bord : tant que la seule
  # chose à voir est la liste, une page de plus au-dessus d'elle n'aurait rien à dire.
  authenticated :user do
    root "simulations#index", as: :authenticated_root
  end

  root "pages#home"

  resources :simulations
end
