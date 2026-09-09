Prunay::Application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }

  # /mon-compte gathers the identity and the password change instead of scattering them in the navbar.
  devise_scope :user do
    get "mon-compte", to: "users/registrations#edit", as: :account
  end

  # Pas de tableau de bord : tant que la seule chose à voir est la liste, une page au-dessus n'a rien à dire.
  authenticated :user do
    root "simulations#index", as: :authenticated_root
  end

  root "pages#home"

  # Rien n'est écrit en base avant la dernière page : les routes du formulaire vivent à côté de la ressource.
  get   "simulations/new/:step", to: "simulations/steps#show",   as: :new_simulation_step
  patch "simulations/new/:step", to: "simulations/steps#update"

  # Tout le compte dans un fichier JSON, que db/seeds.rb sait relire.
  resource :export, only: [:show]

  # Le seul réglage général, et la seule page qui justifie une entrée de menu.
  resource :economic_conditions, only: [:edit, :update], path: "conditions-economiques"

  # Celles d'une simulation vivent dans un onglet : elles ne se demandent pas pendant la création.
  resources :simulations, except: [:create] do
    # Changer l'année de revente ne redessine qu'un graphique : le reste de la fiche ne bouge pas.
    get :tax_burden, on: :member, path: "impot"

    resource :economic_conditions, only: [:update], module: :simulations, path: "conditions-economiques"
  end
end
