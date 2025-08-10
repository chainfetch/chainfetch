Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resources :registrations, only: [:new, :create]
  resources :email_confirmations, only: [:new, :create]
  get "confirm_email/:token", to: "email_confirmations#show", as: :confirm_email
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
  
  namespace :app do
    resources :dashboard, only: [:index]
    post 'regenerate_api_key', to: 'dashboard#regenerate_api_key'
    resources :token_purchases, only: [:create]
    get 'sol_price', to: 'token_purchases#sol_price'
    post 'set_solana_key', to: 'token_purchases#set_solana_key'
    post 'buy_token', to: 'token_purchases#create'
    root 'dashboard#index'
  end

  namespace :public do
    get 'landing', to: 'landing#index'
    root 'landing#index'
  end

  namespace :api do
    namespace :v1 do
      get 'ethereum/addresses/semantic_search', to: 'ethereum/addresses#semantic_search'
      get 'ethereum/addresses/json_search', to: 'ethereum/addresses#json_search'
      get 'ethereum/addresses/llm_search', to: 'ethereum/addresses#llm_search'
      get 'ethereum/addresses/address_summary', to: 'ethereum/addresses#address_summary'
      get 'ethereum/addresses/:address', to: 'ethereum/addresses#show'
      get 'ethereum/transactions/semantic_search', to: 'ethereum/transactions#semantic_search'
      get 'ethereum/transactions/json_search', to: 'ethereum/transactions#json_search'
      get 'ethereum/transactions/llm_search', to: 'ethereum/transactions#llm_search'
      get 'ethereum/transactions/transaction_summary', to: 'ethereum/transactions#transaction_summary'
      get 'ethereum/transactions/:transaction', to: 'ethereum/transactions#show'
      get 'ethereum/blocks/semantic_search', to: 'ethereum/blocks#semantic_search'
      get 'ethereum/blocks/json_search', to: 'ethereum/blocks#json_search'
      get 'ethereum/blocks/llm_search', to: 'ethereum/blocks#llm_search'
      get 'ethereum/blocks/block_summary', to: 'ethereum/blocks#block_summary'
      get 'ethereum/blocks/:block', to: 'ethereum/blocks#show'
      get 'ethereum/tokens/:token', to: 'ethereum/tokens#show'
      get 'ethereum/token-instances/:token/:instance_id', to: 'ethereum/token_instances#show'
      get 'ethereum/smart-contracts/semantic_search', to: 'ethereum/smart_contracts#semantic_search'
      get 'ethereum/smart-contracts/json_search', to: 'ethereum/smart_contracts#json_search'
      get 'ethereum/smart-contracts/llm_search', to: 'ethereum/smart_contracts#llm_search'
      get 'ethereum/smart-contracts/smart_contract_summary', to: 'ethereum/smart_contracts#smart_contract_summary'
      get 'ethereum/smart-contracts/:address', to: 'ethereum/smart_contracts#show'
    end
  end
  
  root 'public/landing#index'
end
