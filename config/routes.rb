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

  # La création se fait en quatre pages, et rien n'est écrit en base avant la dernière :
  # les routes du formulaire vivent donc à côté de la ressource, pas dedans. `/simulations/new`
  # reste l'entrée — il ouvre la première page.
  get   "simulations/new/:step", to: "simulations/steps#show",   as: :new_simulation_step
  patch "simulations/new/:step", to: "simulations/steps#update"

  # Les conditions économiques par défaut : le seul réglage général, et la seule page qui
  # justifie une entrée de menu à côté de la liste.
  resource :economic_conditions, only: [:edit, :update], path: "conditions-economiques"

  # Celles d'une simulation vivent dans un onglet à elles : elles ne se demandent pas pendant
  # la création, seulement une fois la simulation écrite.
  resources :simulations, except: [:create] do
    resource :economic_conditions, only: [:update], module: :simulations, path: "conditions-economiques"
  end
end
