class Api::V1::Ethereum::AddressesController < Api::V1::Ethereum::BaseController
  # @summary Get address info
  # @parameter address(path) [!String] The address hash to get info for
  # @response success(200) [Hash{info: Hash, counters: Hash, transactions: Hash, token_transfers: Hash, internal_transactions: Hash, logs: Hash, blocks_validated: Hash, token_balances: Hash, tokens: Hash, coin_balance_history: Hash, coin_balance_history_by_day: Hash, withdrawals: Hash, nft: Hash, nft_collections: Hash}]
  def show
    address = params[:address]
    
    Sync do
      tasks = {
        info: Async { get_address_info(address) },
        counters: Async { get_address_counters(address) },
        transactions: Async { get_address_transactions(address) },
        token_transfers: Async { get_address_token_transfers(address) },
        internal_transactions: Async { get_address_internal_transactions(address) },
        logs: Async { get_address_logs(address) },
        blocks_validated: Async { get_address_blocks_validated(address) },
        token_balances: Async { get_address_token_balances(address) },
        tokens: Async { get_address_tokens(address) },
        coin_balance_history: Async { get_address_coin_balance_history(address) },
        coin_balance_history_by_day: Async { get_address_coin_balance_history_by_day(address) },
        withdrawals: Async { get_address_withdrawals(address) },
        nft: Async { get_address_nft(address) },
        nft_collections: Async { get_address_nft_collections(address) }
      }
      
      render json: tasks.transform_values(&:wait)
    end
  end

  # @summary Hybrid Search for addresses
  # @parameter query(query) [!String] The query to search for
  # @response success(200) [Hash{response: String}]
  def search
    query = params[:query]
    response = Address.search(query)
    render json: { response: response }
  end

  # @summary Semantic Search for addresses
  # @parameter query(query) [!String] The query to search for
  # @response success(200) [Hash{response: String}]
  def semantic_search
    query = params[:query]
    response = Address.semantic_search(query)
    render json: { response: response }
  end

  # @summary JSON Search for addresses
  # @parameter query(query) [!String] The query to search for
  # @response success(200) [Hash{response: String}]
  def json_search
    query = params[:query]
    response = Address.json_search(query)
    render json: { response: response }
  end

  private

  def get_address_info(address)
    blockscout_api_get("/addresses/#{address}")
  end

  def get_address_counters(address)
    blockscout_api_get("/addresses/#{address}/counters")
  end

  def get_address_transactions(address)
    blockscout_api_get("/addresses/#{address}/transactions")
  end

  def get_address_token_transfers(address)
    blockscout_api_get("/addresses/#{address}/token-transfers")
  end

  def get_address_internal_transactions(address)
    blockscout_api_get("/addresses/#{address}/internal-transactions")
  end

  def get_address_logs(address)
    blockscout_api_get("/addresses/#{address}/logs")
  end

  def get_address_blocks_validated(address)
    blockscout_api_get("/addresses/#{address}/blocks-validated")
  end

  def get_address_token_balances(address)
    blockscout_api_get("/addresses/#{address}/token-balances")
  end

  def get_address_tokens(address)
    blockscout_api_get("/addresses/#{address}/tokens")
  end

  def get_address_coin_balance_history(address)
    blockscout_api_get("/addresses/#{address}/coin-balance-history")
  end

  def get_address_coin_balance_history_by_day(address)
    blockscout_api_get("/addresses/#{address}/coin-balance-history-by-day")
  end

  def get_address_withdrawals(address)
    blockscout_api_get("/addresses/#{address}/withdrawals")
  end

  def get_address_nft(address)
    blockscout_api_get("/addresses/#{address}/nft")
  end

  def get_address_nft_collections(address)
    blockscout_api_get("/addresses/#{address}/nft/collections")
  end
end



