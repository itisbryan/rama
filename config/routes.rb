# frozen_string_literal: true

FlexAdmin::Engine.routes.draw do
  root "dashboard#index"
  
  # Dashboard
  get "dashboard", to: "dashboard#index"
  get "dashboard/stats", to: "dashboard#stats"
  
  # Resources (dynamic routes)
  resources :resources, only: [:index, :show] do
    member do
      get :export
      post :import
    end
  end
  
  # Visual Builder
  namespace :builder do
    resources :forms do
      member do
        get :preview
        post :duplicate
      end
      resources :fields, except: [:show] do
        member do
          patch :move
        end
      end
    end
    
    resources :queries do
      member do
        get :preview
        post :execute
      end
    end
    
    resources :dashboards do
      resources :widgets, except: [:show] do
        member do
          patch :move
          patch :resize
        end
      end
    end
  end
  
  # Search and Filtering
  namespace :search do
    get :global
    get :suggestions
    post :save_filter
    delete :filters, to: "filters#destroy"
  end
  
  # Performance Monitoring
  namespace :performance do
    get :dashboard
    get :queries
    get :cache
    get :jobs
  end
  
  # SolidQueue Job Management
  namespace :jobs do
    get :index
    get :show
    post :retry
    delete :destroy
    get :stats
  end
  
  # API endpoints
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resources :resources, only: [:index, :show, :create, :update, :destroy]
      resources :search, only: [:index]
      resources :filters, only: [:index, :create, :destroy]
    end
  end
  
  # WebSocket endpoints for collaboration
  mount ActionCable.server => "/cable"
end
