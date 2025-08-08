Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  mount OasRails::Engine => '/docs'
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
  
  # Mount Action Cable
  mount ActionCable.server => '/cable'
  
  # Ethereum live data routes
  resources :ethereum, only: [:index]
  
  # =============================================================================
  # ETHEREUM API PROXY ROUTES
  # =============================================================================
  
  namespace :api do
    namespace :v1 do
      get 'ethereum/addresses/semantic_search', to: 'ethereum/addresses#semantic_search'
      get 'ethereum/addresses/json_search', to: 'ethereum/addresses#json_search'
      get 'ethereum/addresses/llm_search', to: 'ethereum/addresses#llm_search'
      get 'ethereum/addresses/:address', to: 'ethereum/addresses#show'
      get 'ethereum/transactions/semantic_search', to: 'ethereum/transactions#semantic_search'
      get 'ethereum/transactions/json_search', to: 'ethereum/transactions#json_search'
      get 'ethereum/transactions/llm_search', to: 'ethereum/transactions#llm_search'
      get 'ethereum/transactions/:transaction', to: 'ethereum/transactions#show'
      get 'ethereum/blocks/semantic_search', to: 'ethereum/blocks#semantic_search'
      get 'ethereum/blocks/json_search', to: 'ethereum/blocks#json_search'
      get 'ethereum/blocks/llm_search', to: 'ethereum/blocks#llm_search'
      get 'ethereum/blocks/:block', to: 'ethereum/blocks#show'
      get 'ethereum/tokens/:token', to: 'ethereum/tokens#show'
      get 'ethereum/token-instances/:token/:instance_id', to: 'ethereum/token_instances#show'
      get 'ethereum/smart-contracts/:address', to: 'ethereum/smart_contracts#show'
    end
  end
  
  # Root endpoint - redirect to live Ethereum dashboard
  root 'ethereum#index'
end
