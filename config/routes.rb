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
      # Universal chain address endpoint
      get ':chain_id/address/:address_hash', to: 'address#show'
      
      # Universal RPC proxy endpoint - forwards all Ethereum RPC calls
      post 'ethereum/rpc', to: 'ethereum#rpc_proxy'
      
      # API information and management endpoints
      # get 'ethereum/methods', to: 'ethereum#supported_methods'
      # get 'ethereum/stats', to: 'ethereum#api_stats'
      
      # # Block analysis endpoints
      # get 'ethereum/block/:number/summary', to: 'ethereum#block_summary'
      # get 'ethereum/block/:number/transactions', to: 'ethereum#block_transactions'
      # get 'ethereum/block/:number/whale', to: 'ethereum#block_whale'
      # get 'ethereum/block/:number/fees', to: 'ethereum#block_fees'
      # get 'ethereum/block/:number/health', to: 'ethereum#block_health'
      
      # # Phase 2: Smart Contract Intelligence
      # get 'ethereum/block/:number/defi', to: 'ethereum#block_defi'
      # get 'ethereum/block/:number/nft', to: 'ethereum#block_nft'
      # get 'ethereum/block/:number/events', to: 'ethereum#block_events'
      # post 'ethereum/address/:address/behavior', to: 'ethereum#address_behavior'
      
      # # Convenience aliases for common methods (optional)
      # post 'eth/rpc', to: 'ethereum#rpc_proxy'
      # get 'eth/stats', to: 'ethereum#api_stats'
      # get 'chains', to: 'supported_chains#index'

      get 'ethereum/addresses/:address', to: 'ethereum/addresses#show'
      get 'ethereum/transactions/:transaction', to: 'ethereum/transactions#show'
      get 'ethereum/blocks/:block', to: 'ethereum/blocks#show'
      get 'ethereum/tokens/:token', to: 'ethereum/tokens#show'
      get 'ethereum/token-instances/:token/:instance_id', to: 'ethereum/token_instances#show'
      get 'ethereum/smart-contracts/:address', to: 'ethereum/smart_contracts#show'
    end
  end
  
  # Root endpoint - redirect to live Ethereum dashboard
  root 'ethereum#index'
end
