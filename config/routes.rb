Rails.application.routes.draw do
  devise_for :users, controllers: { sessions: "devise/passwordless/sessions" }

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "entries#new"
  get "/entries", to: "entries#index"
  get "/received", to: "received#index"
end
