Rails.application.routes.draw do
  devise_for :users, controllers: { sessions: "users/sessions" }

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "entries#new"
  resources :entries, only: [:index, :new, :create, :show] do
    resources :shares, only: [:create]
  end
  get "/shares/:token", to: "shares#show", as: :share

  get "/received", to: "received#index"
  get "/received/:id", to: "received#show", as: :received_entry
  resource :profile, only: [:show, :update]
end
