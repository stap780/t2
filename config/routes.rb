Rails.application.routes.draw do
  # Mission Control Jobs UI for monitoring background jobs
  # For now, mount without constraints - we'll handle auth in the controller
  mount MissionControl::Jobs::Engine, at: "/jobs"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  resource :session
  resources :passwords, param: :token
  get "dashboard", to: "dashboard#index"
  
  # Routes with modern RESTful patterns
  resources :imports, only: [:index, :show, :create, :destroy] do
    collection do
      get :recent
    end
    member do
      get :download
    end
  end
  
  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check


  # Defines the root path route ("/")
  # root "posts#index"
  root "sessions#new"

end