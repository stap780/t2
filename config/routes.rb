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
      post :bulk_features_edit
      post :bulk_features_update
      post :download
      post :bulk_delete
      post :bulk_print_etiketkas, format: :pdf
      get :open_filter
      get :filter_history
      get :filter_price, action: :filter_history
    end
    member do
      get :refill
      post :copy
      patch :sort_image
      post :sync_with_moysklad
      get :edit_status_inline
      patch :update_status_inline
      get :download_images
    end
    resources :variants do
      member do
        get :print_etiketka
        get :edit_price_inline
        patch :update_price_inline
        get :edit_sprice_inline
        patch :update_sprice_inline
        get :generate_barcode
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
  resources :staff_schedules, only: [:index] do
    collection do
      get :export
    end
  end
  resources :employees, except: [:show] do
    member do
      get :schedule
      patch :sort
    end
    resources :schedule_days, only: [] do
      collection do
        post :batch
      end
    end
  end
  resources :departments, except: [:show]
  resources :shift_codes, except: [:show]

  get "documentation", to: "documentation#index", as: :documentation
  get "documentation/avito", to: "documentation#avito", as: :documentation_avito
  get "documentation/insales", to: "documentation#insales", as: :documentation_insales
  get "documentation/moysklad", to: "documentation#moysklad", as: :documentation_moysklad

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
    collection do
      get :xml_avito_example
    end
    resources :export_filter_rules do
      member do
        get :characteristics
      end
    end
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
      get :fetch_orders
      post :add_order_webhook
      post :add_order_update_webhook
    end
    resources :insales_order_status_mappings, except: [:show]
    resources :insales_order_field_mappings, except: %i[show index]
  end

  resources :moysklads do
    member do
      get :check
      post :add_order_webhook
      patch :order_settings
    end
    resources :moysklad_order_field_mappings, except: %i[show index]
  end

  resources :avitos do
    member do
      get :fetch_orders
      get :sync_catalog
    end
    resources :avito_order_status_mappings, except: [:show]
  end

  resources :users

  resources :companies do
    collection do
      post :download
      post :bulk_delete
      post :search
    end
    member do
      get :edit_info_inline
      patch :update_info_inline
    end
    resources :client_companies, only: [:new, :create, :destroy]
    resources :company_plan_dates, only: [:new, :create, :destroy]
  end

  resources :client_companies, only: [:new, :create, :destroy]
  resources :company_plan_dates, only: [:new, :create, :destroy]

  resources :clients do
    collection do
      post :search
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
  resources :orders, only: %i[index show] do
    member do
      post :export_to_moysklad
      post :sync_from_moysklad
      post :push_to_insales
      post :download_avito_label
    end
  end
  resources :order_statuses do
    member do
      patch :sort
    end
  end
  resources :moysklad_order_status_mappings, except: [:show]

  resources :okrugs do
    member do
      patch :sort
    end
  end

  resources :acts do
    member do
      get :print, format: :pdf
      get :print_etiketkas, format: :pdf
      post :print_selected_etiketkas, format: :pdf
      post :send_to_driver
      post :bulk_update_item_status
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
      get :print_etiketkas, format: :pdf
      get :calc
    end
    collection do
      post :bulk_print
      post :bulk_status
      post :download
      post :bulk_delete
      post :send_emails
      get :filter
      get :reports
    end
    resources :items do
      collection do
        post :bulk_update_status
      end
      member do
        get :update_variant_fields
        get :apply_free_text
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
      post :merge_to_existing
      post :merge_to_new
      post :update_totalsum
    end
  end

  resources :items, only: [:new, :destroy] do
    collection do
      post :search
      get :suggest_variants
    end
    member do
      get :update_variant_fields
      get :apply_free_text
    end
  end

  # API webhooks and external endpoints (bypass allow_browser)
  namespace :api do
    post "insales/:id/order", to: "insales#order", as: :insale_order
    post "moysklads/order", to: "moysklads#order"
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