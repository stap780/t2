Rails.application.routes.draw do
  resources :detals do
    member do
      get :get_oszz
    end
    collection do
      post :download
      post :bulk_delete
    end
    resources :features do
      member do
        get :update_characteristics
      end
    end
  end
  resources :varbinds
  resources :variants
  resources :images do
    collection do
      post :upload
      post :delete
    end
  end
  
  resources :properties do
    collection do
      get :characteristics
      post :search
    end
    resources :characteristics, only: [:new, :create, :edit, :update, :destroy]
  end
  
  resources :characteristics, only: [:new, :destroy] do
    collection do
      post :search
    end
  end

  resources :products do
    collection do
      get :search
      post :price_edit
      post :price_update
      post :download
      post :bulk_delete
      get :filter
    end
    member do
      get :refill
      post :copy
      patch :sort_image
      post :sync_with_moysklad
    end
    resources :variants do
      member do
        get :print_etiketka
        get :edit_price_inline
        patch :update_price_inline
      end
    end
    resources :varbinds, only: [:new, :create, :edit, :update, :destroy]
    resources :images, only: [:create]
    resources :features do
      member do
        get :update_characteristics
      end
    end
  end

  resources :features, only: [:new, :destroy] # for new nested features without product

  resources :variants do
    resources :varbinds, only: [:new, :create, :edit, :update, :destroy]
  end
  # Pretty, stable file URL: /exports/export-:id(.:ext)
  get "exports/export-:id(.:ext)", to: "exports#file", as: :export_file_stable

  # Mission Control Jobs UI for monitoring background jobs
  # For now, mount without constraints - we'll handle auth in the controller
  mount MissionControl::Jobs::Engine, at: "/jobs"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  resource :session
  resources :passwords, param: :token
  get "dashboard", to: "dashboard#index"
  post "dashboard/fullsearch", to: "dashboard#fullsearch", as: :fullsearch_dashboard_index
  
  # Routes with modern RESTful patterns
  resources :imports, only: [:index, :show, :create, :destroy] do
    collection do
      get :recent
    end
    member do
      get :download
    end
  end

  resources :exports, only: [:index, :new, :create, :edit, :update, :destroy] do
    member do
      get :download
      get :file
      post :run
      post :cancel
    end
  end

  resources :email_deliveries, only: [:index, :show] do
    member do
      post :retry
    end
  end

  resources :import_schedules do
    member do
      post :run
    end
  end

  # Settings section
  resources :insales do
    member do
      get :check
      post :add_order_webhook
    end
  end

  resources :moysklads do
    member do
      get :check
    end
  end

  resources :users

  resources :companies do
    collection do
      post :download
      post :bulk_delete
    end
    resources :client_companies, only: [:new, :create, :destroy]
    resources :company_plan_dates, only: [:new, :create, :destroy]
  end

  resources :client_companies, only: [:new, :create, :destroy]
  resources :company_plan_dates, only: [:new, :create, :destroy]

  resources :clients do
    collection do
      get :search
      post :download
      post :bulk_delete
    end
  end

  # Incase routes
  resources :incase_statuses do
    member do
      patch :sort
    end
  end

  resources :incase_tips do
    member do
      patch :sort
    end
  end

  resources :item_statuses

  resources :okrugs do
    member do
      patch :sort
    end
  end

  resources :acts do
    member do
      get :print, format: :pdf
    end
    collection do
      post :create_multi
      put :update_multi
    end
  end

  resources :incases do
    member do
      get :act
      post :send_email
    end
    collection do
      post :bulk_print
      post :bulk_status
      post :download
      post :bulk_delete
      post :send_emails
      get :filter
    end
    resources :items do
      member do
        get :update_variant_fields
        post :update_status
        post :update_condition
      end
    end
    resources :comments, module: :incases, only: [:new, :create, :destroy]
  end
  
  resources :incase_imports, only: [:index, :show, :new, :create, :destroy]
  
  resources :incase_dubls, only: [:index, :show, :destroy] do
    member do
      post :merge
    end
  end

  resources :items, only: [:new, :destroy] do
    collection do
      post :search
    end
    member do
      get :update_variant_fields
    end
  end

  # API webhooks
  namespace :api do
    namespace :webhooks do
      post 'insales/order', to: 'insales#order'
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