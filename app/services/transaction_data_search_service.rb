require 'net/http'
require 'uri'
require 'json'
require 'openssl'

class TransactionDataSearchService
  class ApiError < StandardError; end
  class InvalidQueryError < StandardError; end

  def initialize(query)
    @query = query
    @api_url = "https://llama.chainfetch.app"
    @model = "llama3.2:3b"
    @api_key = Rails.application.credentials.auth_bearer_token
    @base_url = Rails.env.production? ? 'https://chainfetch.app' : 'http://localhost:3000'
  end

  def call
    tool_call_response = generate_tool_call(@query)
    execute_api_request(tool_call_response)
  rescue Net::HTTPError, SocketError, Errno::ECONNREFUSED => e
    raise ApiError, "AI service unavailable: #{e.message}"
  rescue => e
    Rails.logger.error "Unexpected error: #{e.message}"
    raise e
  end

  private

  def generate_tool_call(user_query)
    system_prompt = <<~PROMPT
      Your task is to call the search_transactions tool with the appropriate parameters to fulfill the user's request.
      
      Analyze the user's query and call the search_transactions tool with the appropriate parameters to fulfill their request.
      
      CRITICAL: Pay careful attention to comparison operators in natural language:
      - "more than", "greater than", "above", "at least" → use _min parameters
      - "less than", "below", "under", "at most" → use _max parameters  
      - "between X and Y" → use both _min and _max parameters
      - "exactly", "equal to" → use the exact value without min/max suffix
      
      SORTING: Recognize sorting intentions in natural language:
      - "top", "highest", "largest", "most" → sort_order: "desc"
      - "bottom", "lowest", "smallest", "least" → sort_order: "asc"
      - "newest", "latest", "recent" → sort_by: "timestamp", sort_order: "desc"
      - "oldest", "earliest" → sort_by: "timestamp", sort_order: "asc"
      - "by value", "highest value" → sort_by: "value", sort_order: "desc"
      - "by gas usage" → sort_by: "gas_used", sort_order: "desc"
      - "by fees" → sort_by: "priority_fee", sort_order: "desc"
      - "most expensive" → sort_by: "max_fee_per_gas", sort_order: "desc"
      - "by confirmations" → sort_by: "confirmations", sort_order: "desc"
      
      Parameter mapping guide:
      - Transaction values → value_min/max (in WEI like "2302322924045933")
      - Gas usage → gas_used_min/max, gas_limit_min/max, gas_price_min/max
      - Fees → priority_fee_min/max, max_fee_per_gas_min/max, transaction_burnt_fee_min/max
      - Transaction hashes → hash, block_hash, token_transfers_transaction_hash
      - Address filters → from_hash, to_hash, from_is_contract, to_is_verified, etc.
      - Token filters → token_transfers_token_symbol, token_transfers_token_name, token_transfers_token_address
      - Status filters → result, status, has_error_in_internal_transactions
      - Method filters → method, decoded_input_method_call, decoded_input_method_id
      - Transaction types → type_min/max, transaction_types, token_transfers_type
      - Block filters → block_number_min/max, block_hash
      - Time filters → timestamp_min/max, confirmation_duration_min/max
      - Metadata filters → transaction_tag, from_metadata_tags_name, to_metadata_tags_name
      - Token transfer filters → token_transfers_* parameters for filtering by token activity
      - Result limits → limit (default: 10, max: 50)
      - Sorting → sort_by (field name), sort_order ("asc" or "desc", default: "desc")
      
      Examples of correct tool calls:
      - "high value transactions" → search_transactions({"value_min": "1000000000000000000"})
      - "failed transactions" → search_transactions({"result": "failure"})
      - "transactions from verified contracts" → search_transactions({"from_is_contract": true, "from_is_verified": true})
      - "USDC transfers" → search_transactions({"token_transfers_token_symbol": "USDC"})
      - "expensive transactions" → search_transactions({"gas_price_min": 100000000000, "sort_by": "gas_price", "sort_order": "desc"})
      - "recent DeFi transactions" → search_transactions({"transaction_tag": "DeFi", "sort_by": "timestamp", "sort_order": "desc"})
      - "transactions to scam addresses" → search_transactions({"to_is_scam": true})
      - "token transfers with high fees" → search_transactions({"token_transfers_type": "token_transfer", "priority_fee_min": "1000000000000000"})

      Set the limit to 10 if not specified.
      
      Always call the search_transactions tool with the parameters that best match the user's intent.
    PROMPT

    response = make_llama_request(system_prompt, user_query)
    parse_tool_call_response(response)
  end

  def parse_tool_call_response(response)
    tool_calls = JSON.parse(response)
    
    if tool_calls.is_a?(Array) && tool_calls.first&.dig("function", "name") == "search_transactions"
      arguments = JSON.parse(tool_calls.first.dig("function", "arguments"))
      return arguments
    elsif tool_calls.is_a?(Hash) && tool_calls.dig("function", "name") == "search_transactions"
      arguments = JSON.parse(tool_calls.dig("function", "arguments"))
      return arguments
    else
      raise InvalidQueryError, "No valid tool call found in response"
    end
  rescue JSON::ParserError => e
    raise InvalidQueryError, "Invalid JSON response from AI: #{e.message}"
  end

  def execute_api_request(parameters)
    uri = URI("#{@base_url}/api/v1/ethereum/transactions/json_search")
    uri.query = URI.encode_www_form(parameters) if parameters&.any?
    
    # Use a thread to avoid deadlock when making internal requests
    response = Thread.new do
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 30
      
      if uri.scheme == 'https'
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      end
      
      request = Net::HTTP::Get.new(uri)
      request['Content-Type'] = 'application/json'
      
      http.request(request)
    end.value
    
    if response.code == '200'
      result = JSON.parse(response.body)
      {
        count: result.dig("results")&.length || 0,
        parameters_used: parameters,
        api_endpoint: uri.to_s,
        transactions: result.dig("results") || []
      }
    else
      {
        error: "API request failed with status: #{response.code}",
        response_body: response.body,
        parameters_used: parameters,
        count: 0,
        transactions: []
      }
    end
  rescue JSON::ParserError => e
    {
      error: "Failed to parse API response: #{e.message}",
      parameters_used: parameters,
      count: 0,
      transactions: []
    }
  rescue => e
    {
      error: "Request failed: #{e.message}",
      parameters_used: parameters,
      count: 0,
      transactions: []
    }
  end

  def make_llama_request(system_prompt, user_prompt)
    uri = URI("#{@api_url}/v1/chat/completions")
    
    # Use a thread to avoid deadlock when making external requests
    response = Thread.new do
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 30
      
      if uri.scheme == 'https'
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      end
      
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{@api_key}"
      request.body = {
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_prompt }
        ],
      model: @model,
      tools: [{
        type: "function",
        function: {
          name: "search_transactions",
          description: "Search for Ethereum transactions based on various criteria",
          parameters: {
            type: "object",
            properties: {
              # Core transaction fields
              priority_fee_min: { type: "string", description: "Minimum priority fee" },
              priority_fee_max: { type: "string", description: "Maximum priority fee" },
              raw_input: { type: "string", description: "Transaction raw input data" },
              result: { type: "string", description: "Transaction result (success, failure)" },
              hash: { type: "string", description: "Transaction hash" },
              max_fee_per_gas_min: { type: "string", description: "Minimum max fee per gas" },
              max_fee_per_gas_max: { type: "string", description: "Maximum max fee per gas" },
              revert_reason: { type: "string", description: "Transaction revert reason" },
              confirmation_duration_min: { type: "integer", description: "Minimum confirmation duration in milliseconds" },
              confirmation_duration_max: { type: "integer", description: "Maximum confirmation duration in milliseconds" },
              transaction_burnt_fee_min: { type: "string", description: "Minimum transaction burnt fee" },
              transaction_burnt_fee_max: { type: "string", description: "Maximum transaction burnt fee" },
              type_min: { type: "integer", description: "Minimum transaction type" },
              type_max: { type: "integer", description: "Maximum transaction type" },
              token_transfers_overflow: { type: "boolean", description: "Whether token transfers overflow" },
              confirmations_min: { type: "integer", description: "Minimum confirmations count" },
              confirmations_max: { type: "integer", description: "Maximum confirmations count" },
              position_min: { type: "integer", description: "Minimum position in block" },
              position_max: { type: "integer", description: "Maximum position in block" },
              max_priority_fee_per_gas_min: { type: "string", description: "Minimum max priority fee per gas" },
              max_priority_fee_per_gas_max: { type: "string", description: "Maximum max priority fee per gas" },
              transaction_tag: { type: "string", description: "Transaction tag (e.g., 'DeFi Interaction')" },
              created_contract: { type: "string", description: "Created contract address" },
              value_min: { type: "string", description: "Minimum transaction value in WEI" },
              value_max: { type: "string", description: "Maximum transaction value in WEI" },
              
              # From address fields
              from_ens_domain_name: { type: "string", description: "From address ENS domain name" },
              from_hash: { type: "string", description: "From address hash" },
              from_is_contract: { type: "boolean", description: "Whether from address is contract" },
              from_is_scam: { type: "boolean", description: "Whether from address is scam" },
              from_is_verified: { type: "boolean", description: "Whether from address is verified" },
              from_name: { type: "string", description: "From address name" },
              from_proxy_type: { type: "string", description: "From address proxy type" },
              from_private_tags: { type: "string", description: "From address private tags" },
              from_public_tags: { type: "string", description: "From address public tags" },
              from_watchlist_names: { type: "string", description: "From address watchlist names" },
              from_metadata_tags_name: { type: "string", description: "From address metadata tags name" },
              from_metadata_tags_slug: { type: "string", description: "From address metadata tags slug" },
              from_metadata_tags_tag_type: { type: "string", description: "From address metadata tags tag type" },
              from_metadata_tags_ordinal_min: { type: "integer", description: "Minimum from address metadata tags ordinal" },
              from_metadata_tags_ordinal_max: { type: "integer", description: "Maximum from address metadata tags ordinal" },
              
              # To address fields
              to_ens_domain_name: { type: "string", description: "To address ENS domain name" },
              to_hash: { type: "string", description: "To address hash" },
              to_is_contract: { type: "boolean", description: "Whether to address is contract" },
              to_is_scam: { type: "boolean", description: "Whether to address is scam" },
              to_is_verified: { type: "boolean", description: "Whether to address is verified" },
              to_name: { type: "string", description: "To address name" },
              to_proxy_type: { type: "string", description: "To address proxy type" },
              to_private_tags: { type: "string", description: "To address private tags" },
              to_public_tags: { type: "string", description: "To address public tags" },
              to_watchlist_names: { type: "string", description: "To address watchlist names" },
              to_metadata_tags_name: { type: "string", description: "To address metadata tags name" },
              to_metadata_tags_slug: { type: "string", description: "To address metadata tags slug" },
              to_metadata_tags_tag_type: { type: "string", description: "To address metadata tags tag type" },
              
              # Authorization list fields
              authorization_list_authority: { type: "string", description: "Authorization list authority" },
              authorization_list_delegated_address: { type: "string", description: "Authorization list delegated address" },
              authorization_list_nonce: { type: "string", description: "Authorization list nonce" },
              authorization_list_r: { type: "string", description: "Authorization list r value" },
              authorization_list_s: { type: "string", description: "Authorization list s value" },
              authorization_list_validity: { type: "string", description: "Authorization list validity" },
              authorization_list_y_parity: { type: "string", description: "Authorization list y parity" },
              
              # Gas and fee fields
              gas_used_min: { type: "string", description: "Minimum gas used" },
              gas_used_max: { type: "string", description: "Maximum gas used" },
              gas_limit_min: { type: "string", description: "Minimum gas limit" },
              gas_limit_max: { type: "string", description: "Maximum gas limit" },
              gas_price_min: { type: "string", description: "Minimum gas price" },
              gas_price_max: { type: "string", description: "Maximum gas price" },
              base_fee_per_gas_min: { type: "string", description: "Minimum base fee per gas" },
              base_fee_per_gas_max: { type: "string", description: "Maximum base fee per gas" },
              
              # Method and execution
              method: { type: "string", description: "Transaction method" },
              status: { type: "string", description: "Transaction status" },
              decoded_input_method_call: { type: "string", description: "Decoded input method call" },
              decoded_input_method_id: { type: "string", description: "Decoded input method ID" },
              decoded_input_parameters_name: { type: "string", description: "Decoded input parameter name" },
              decoded_input_parameters_type: { type: "string", description: "Decoded input parameter type" },
              decoded_input_parameters_value: { type: "string", description: "Decoded input parameter value" },
              
              # Fee structure
              fee_type: { type: "string", description: "Fee type" },
              fee_value_min: { type: "string", description: "Minimum fee value" },
              fee_value_max: { type: "string", description: "Maximum fee value" },
              
              # Actions
              actions_action_type: { type: "string", description: "Action type" },
              actions_data_from: { type: "string", description: "Action data from address" },
              actions_data_to: { type: "string", description: "Action data to address" },
              actions_data_amount: { type: "string", description: "Action data amount" },
              actions_data_token: { type: "string", description: "Action data token address" },
              
              # Token transfers
              token_transfers_block_hash: { type: "string", description: "Token transfer block hash" },
              token_transfers_block_number_min: { type: "integer", description: "Minimum token transfer block number" },
              token_transfers_block_number_max: { type: "integer", description: "Maximum token transfer block number" },
              token_transfers_from_hash: { type: "string", description: "Token transfer from hash" },
              token_transfers_from_ens_domain_name: { type: "string", description: "Token transfer from ENS domain" },
              token_transfers_from_is_contract: { type: "boolean", description: "Token transfer from is contract" },
              token_transfers_from_is_scam: { type: "boolean", description: "Token transfer from is scam" },
              token_transfers_from_is_verified: { type: "boolean", description: "Token transfer from is verified" },
              token_transfers_from_name: { type: "string", description: "Token transfer from name" },
              token_transfers_from_proxy_type: { type: "string", description: "Token transfer from proxy type" },
              token_transfers_log_index_min: { type: "integer", description: "Minimum token transfer log index" },
              token_transfers_log_index_max: { type: "integer", description: "Maximum token transfer log index" },
              token_transfers_method: { type: "string", description: "Token transfer method" },
              token_transfers_timestamp_min: { type: "string", description: "Minimum token transfer timestamp" },
              token_transfers_timestamp_max: { type: "string", description: "Maximum token transfer timestamp" },
              token_transfers_to_hash: { type: "string", description: "Token transfer to hash" },
              token_transfers_to_ens_domain_name: { type: "string", description: "Token transfer to ENS domain" },
              token_transfers_to_is_contract: { type: "boolean", description: "Token transfer to is contract" },
              token_transfers_to_is_scam: { type: "boolean", description: "Token transfer to is scam" },
              token_transfers_to_is_verified: { type: "boolean", description: "Token transfer to is verified" },
              token_transfers_to_name: { type: "string", description: "Token transfer to name" },
              token_transfers_to_proxy_type: { type: "string", description: "Token transfer to proxy type" },
              token_transfers_to_metadata_tags_name: { type: "string", description: "Token transfer to metadata tags name" },
              token_transfers_to_metadata_tags_slug: { type: "string", description: "Token transfer to metadata tags slug" },
              token_transfers_to_metadata_tags_tag_type: { type: "string", description: "Token transfer to metadata tags tag type" },
              token_transfers_token_address: { type: "string", description: "Token transfer token address" },
              token_transfers_token_address_hash: { type: "string", description: "Token transfer token address hash" },
              token_transfers_token_circulating_market_cap_min: { type: "string", description: "Minimum token transfer token circulating market cap" },
              token_transfers_token_circulating_market_cap_max: { type: "string", description: "Maximum token transfer token circulating market cap" },
              token_transfers_token_decimals_min: { type: "integer", description: "Minimum token transfer token decimals" },
              token_transfers_token_decimals_max: { type: "integer", description: "Maximum token transfer token decimals" },
              token_transfers_token_exchange_rate_min: { type: "string", description: "Minimum token transfer token exchange rate" },
              token_transfers_token_exchange_rate_max: { type: "string", description: "Maximum token transfer token exchange rate" },
              token_transfers_token_holders_min: { type: "integer", description: "Minimum token transfer token holders" },
              token_transfers_token_holders_max: { type: "integer", description: "Maximum token transfer token holders" },
              token_transfers_token_holders_count_min: { type: "integer", description: "Minimum token transfer token holders count" },
              token_transfers_token_holders_count_max: { type: "integer", description: "Maximum token transfer token holders count" },
              token_transfers_token_icon_url: { type: "string", description: "Token transfer token icon URL" },
              token_transfers_token_name: { type: "string", description: "Token transfer token name" },
              token_transfers_token_symbol: { type: "string", description: "Token transfer token symbol" },
              token_transfers_token_total_supply_min: { type: "string", description: "Minimum token transfer token total supply" },
              token_transfers_token_total_supply_max: { type: "string", description: "Maximum token transfer token total supply" },
              token_transfers_token_type: { type: "string", description: "Token transfer token type" },
              token_transfers_token_volume_24h_min: { type: "string", description: "Minimum token transfer token 24h volume" },
              token_transfers_token_volume_24h_max: { type: "string", description: "Maximum token transfer token 24h volume" },
              token_transfers_total_decimals_min: { type: "integer", description: "Minimum token transfer total decimals" },
              token_transfers_total_decimals_max: { type: "integer", description: "Maximum token transfer total decimals" },
              token_transfers_total_value_min: { type: "string", description: "Minimum token transfer total value" },
              token_transfers_total_value_max: { type: "string", description: "Maximum token transfer total value" },
              token_transfers_transaction_hash: { type: "string", description: "Token transfer transaction hash" },
              token_transfers_type: { type: "string", description: "Token transfer type" },
              
              # Block and timing
              timestamp_min: { type: "string", description: "Minimum timestamp" },
              timestamp_max: { type: "string", description: "Maximum timestamp" },
              nonce_min: { type: "integer", description: "Minimum nonce" },
              nonce_max: { type: "integer", description: "Maximum nonce" },
              historic_exchange_rate_min: { type: "string", description: "Minimum historic exchange rate" },
              historic_exchange_rate_max: { type: "string", description: "Maximum historic exchange rate" },
              transaction_types: { type: "string", description: "Transaction types" },
              exchange_rate_min: { type: "string", description: "Minimum exchange rate" },
              exchange_rate_max: { type: "string", description: "Maximum exchange rate" },
              block_number_min: { type: "integer", description: "Minimum block number" },
              block_number_max: { type: "integer", description: "Maximum block number" },
              has_error_in_internal_transactions: { type: "boolean", description: "Has error in internal transactions" },
              block_hash: { type: "string", description: "Block hash" },
              transaction_index_min: { type: "integer", description: "Minimum transaction index" },
              transaction_index_max: { type: "integer", description: "Maximum transaction index" },

              
              # # Internal transactions filters (comprehensive) - COMMENTED OUT FOR TESTING
              # # internal_transactions_block_index_min: { type: "integer", description: "Minimum internal transaction block index" },
              # internal_transactions_block_index_max: { type: "integer", description: "Maximum internal transaction block index" },
              # internal_transactions_block_number_min: { type: "integer", description: "Minimum internal transaction block number" },
              # internal_transactions_block_number_max: { type: "integer", description: "Maximum internal transaction block number" },
              # internal_transactions_created_contract_hash: { type: "string", description: "Internal transaction created contract hash" },
              # internal_transactions_created_contract_ens_domain_name: { type: "string", description: "Internal transaction created contract ENS domain name" },
              # internal_transactions_created_contract_is_contract: { type: "boolean", description: "Internal transaction created contract is contract" },
              # internal_transactions_created_contract_is_scam: { type: "boolean", description: "Internal transaction created contract is scam" },
              # internal_transactions_created_contract_is_verified: { type: "boolean", description: "Internal transaction created contract is verified" },
              # internal_transactions_created_contract_name: { type: "string", description: "Internal transaction created contract name" },
              # internal_transactions_created_contract_proxy_type: { type: "string", description: "Internal transaction created contract proxy type" },
              # internal_transactions_created_contract_metadata_tags_name: { type: "string", description: "Internal transaction created contract metadata tags name" },
              # internal_transactions_created_contract_metadata_tags_slug: { type: "string", description: "Internal transaction created contract metadata tags slug" },
              # internal_transactions_created_contract_metadata_tags_tag_type: { type: "string", description: "Internal transaction created contract metadata tags tag type" },
              # internal_transactions_created_contract_metadata_tags_ordinal_min: { type: "integer", description: "Minimum internal transaction created contract metadata tags ordinal" },
              # internal_transactions_created_contract_metadata_tags_ordinal_max: { type: "integer", description: "Maximum internal transaction created contract metadata tags ordinal" },
              # internal_transactions_error: { type: "string", description: "Internal transaction error" },
              # internal_transactions_from_hash: { type: "string", description: "Internal transaction from hash" },
              # internal_transactions_from_ens_domain_name: { type: "string", description: "Internal transaction from ENS domain name" },
              # internal_transactions_from_is_contract: { type: "boolean", description: "Internal transaction from is contract" },
              # internal_transactions_from_is_scam: { type: "boolean", description: "Internal transaction from is scam" },
              # internal_transactions_from_is_verified: { type: "boolean", description: "Internal transaction from is verified" },
              # internal_transactions_from_name: { type: "string", description: "Internal transaction from name" },
              # internal_transactions_from_proxy_type: { type: "string", description: "Internal transaction from proxy type" },
              # internal_transactions_from_metadata_tags_name: { type: "string", description: "Internal transaction from metadata tags name" },
              # internal_transactions_from_metadata_tags_slug: { type: "string", description: "Internal transaction from metadata tags slug" },
              # internal_transactions_from_metadata_tags_tag_type: { type: "string", description: "Internal transaction from metadata tags tag type" },
              # internal_transactions_from_metadata_tags_ordinal_min: { type: "integer", description: "Minimum internal transaction from metadata tags ordinal" },
              # internal_transactions_from_metadata_tags_ordinal_max: { type: "integer", description: "Maximum internal transaction from metadata tags ordinal" },
              # internal_transactions_gas_limit_min: { type: "string", description: "Minimum internal transaction gas limit" },
              # internal_transactions_gas_limit_max: { type: "string", description: "Maximum internal transaction gas limit" },
              # internal_transactions_index_min: { type: "integer", description: "Minimum internal transaction index" },
              # internal_transactions_index_max: { type: "integer", description: "Maximum internal transaction index" },
              # internal_transactions_success: { type: "boolean", description: "Internal transaction success" },
              # internal_transactions_timestamp_min: { type: "string", description: "Minimum internal transaction timestamp" },
              # internal_transactions_timestamp_max: { type: "string", description: "Maximum internal transaction timestamp" },
              # internal_transactions_to_hash: { type: "string", description: "Internal transaction to hash" },
              # internal_transactions_to_ens_domain_name: { type: "string", description: "Internal transaction to ENS domain name" },
              # internal_transactions_to_is_contract: { type: "boolean", description: "Internal transaction to is contract" },
              # internal_transactions_to_is_scam: { type: "boolean", description: "Internal transaction to is scam" },
              # internal_transactions_to_is_verified: { type: "boolean", description: "Internal transaction to is verified" },
              # internal_transactions_to_name: { type: "string", description: "Internal transaction to name" },
              # internal_transactions_to_proxy_type: { type: "string", description: "Internal transaction to proxy type" },
              # internal_transactions_to_metadata_tags_name: { type: "string", description: "Internal transaction to metadata tags name" },
              # internal_transactions_to_metadata_tags_slug: { type: "string", description: "Internal transaction to metadata tags slug" },
              # internal_transactions_to_metadata_tags_tag_type: { type: "string", description: "Internal transaction to metadata tags tag type" },
              # internal_transactions_to_metadata_tags_ordinal_min: { type: "integer", description: "Minimum internal transaction to metadata tags ordinal" },
              # internal_transactions_to_metadata_tags_ordinal_max: { type: "integer", description: "Maximum internal transaction to metadata tags ordinal" },
              # internal_transactions_transaction_hash: { type: "string", description: "Internal transaction transaction hash" },
              # internal_transactions_transaction_index_min: { type: "integer", description: "Minimum internal transaction transaction index" },
              # internal_transactions_transaction_index_max: { type: "integer", description: "Maximum internal transaction transaction index" },
              # internal_transactions_type: { type: "string", description: "Internal transaction type" },
              # internal_transactions_value_min: { type: "string", description: "Minimum internal transaction value" },
              # internal_transactions_value_max: { type: "string", description: "Maximum internal transaction value" },
              # internal_transactions_next_page_params_block_number_min: { type: "integer", description: "Minimum internal transactions next page params block number" },
              # internal_transactions_next_page_params_block_number_max: { type: "integer", description: "Maximum internal transactions next page params block number" },
              # internal_transactions_next_page_params_index_min: { type: "integer", description: "Minimum internal transactions next page params index" },
              # internal_transactions_next_page_params_index_max: { type: "integer", description: "Maximum internal transactions next page params index" },
              # internal_transactions_next_page_params_items_count_min: { type: "integer", description: "Minimum internal transactions next page params items count" },
              # internal_transactions_next_page_params_items_count_max: { type: "integer", description: "Maximum internal transactions next page params items count" },
              # 
              #                # # Logs filters (comprehensive) - COMMENTED OUT FOR TESTING
              #  # logs_address_hash: { type: "string", description: "Log address hash" },
              #  logs_address_ens_domain_name: { type: "string", description: "Log address ENS domain name" },
              #  logs_address_is_contract: { type: "boolean", description: "Log address is contract" },
              #  logs_address_is_scam: { type: "boolean", description: "Log address is scam" },
              #  logs_address_is_verified: { type: "boolean", description: "Log address is verified" },
              #  logs_address_name: { type: "string", description: "Log address name" },
              #  logs_address_proxy_type: { type: "string", description: "Log address proxy type" },
              #  logs_address_metadata_tags_name: { type: "string", description: "Log address metadata tags name" },
              #  logs_address_metadata_tags_slug: { type: "string", description: "Log address metadata tags slug" },
              #  logs_address_metadata_tags_tag_type: { type: "string", description: "Log address metadata tags tag type" },
              #  logs_address_metadata_tags_ordinal_min: { type: "integer", description: "Minimum log address metadata tags ordinal" },
              #  logs_address_metadata_tags_ordinal_max: { type: "integer", description: "Maximum log address metadata tags ordinal" },
              #  logs_block_hash: { type: "string", description: "Log block hash" },
              #  logs_block_number_min: { type: "integer", description: "Minimum log block number" },
              #  logs_block_number_max: { type: "integer", description: "Maximum log block number" },
              #  logs_data: { type: "string", description: "Log data" },
              #  logs_decoded_method_call: { type: "string", description: "Log decoded method call" },
              #  logs_decoded_method_id: { type: "string", description: "Log decoded method ID" },
              #  logs_decoded_parameters_indexed: { type: "boolean", description: "Log decoded parameters indexed" },
              #  logs_decoded_parameters_name: { type: "string", description: "Log decoded parameters name" },
              #  logs_decoded_parameters_type: { type: "string", description: "Log decoded parameters type" },
              #  logs_decoded_parameters_value: { type: "string", description: "Log decoded parameters value" },
              #  logs_index_min: { type: "integer", description: "Minimum log index" },
              #  logs_index_max: { type: "integer", description: "Maximum log index" },
              #  logs_smart_contract_hash: { type: "string", description: "Log smart contract hash" },
              #  logs_smart_contract_ens_domain_name: { type: "string", description: "Log smart contract ENS domain name" },
              #  logs_smart_contract_is_contract: { type: "boolean", description: "Log smart contract is contract" },
              #  logs_smart_contract_is_scam: { type: "boolean", description: "Log smart contract is scam" },
              #  logs_smart_contract_is_verified: { type: "boolean", description: "Log smart contract is verified" },
              #  logs_smart_contract_name: { type: "string", description: "Log smart contract name" },
              #  logs_smart_contract_proxy_type: { type: "string", description: "Log smart contract proxy type" },
              #  logs_smart_contract_metadata_tags_name: { type: "string", description: "Log smart contract metadata tags name" },
              #  logs_smart_contract_metadata_tags_slug: { type: "string", description: "Log smart contract metadata tags slug" },
              #  logs_smart_contract_metadata_tags_tag_type: { type: "string", description: "Log smart contract metadata tags tag type" },
              #  logs_smart_contract_metadata_tags_ordinal_min: { type: "integer", description: "Minimum log smart contract metadata tags ordinal" },
              #  logs_smart_contract_metadata_tags_ordinal_max: { type: "integer", description: "Maximum log smart contract metadata tags ordinal" },
              #  logs_topics: { type: "string", description: "Log topics" },
              #  logs_transaction_hash: { type: "string", description: "Log transaction hash" },
              #  logs_next_page_params_block_number_min: { type: "integer", description: "Minimum logs next page params block number" },
              #  logs_next_page_params_block_number_max: { type: "integer", description: "Maximum logs next page params block number" },
              #  logs_next_page_params_index_min: { type: "integer", description: "Minimum logs next page params index" },
              #  logs_next_page_params_index_max: { type: "integer", description: "Maximum logs next page params index" },
              #  logs_next_page_params_items_count_min: { type: "integer", description: "Minimum logs next page params items count" },
              #  logs_next_page_params_items_count_max: { type: "integer", description: "Maximum logs next page params items count" },
              # # 
              # Raw trace filters
              raw_trace_action_call_type: { type: "string", description: "Raw trace action call type" },
              raw_trace_action_from: { type: "string", description: "Raw trace action from" },
              raw_trace_action_gas: { type: "string", description: "Raw trace action gas" },
              raw_trace_action_input: { type: "string", description: "Raw trace action input" },
              raw_trace_action_to: { type: "string", description: "Raw trace action to" },
              raw_trace_action_value: { type: "string", description: "Raw trace action value" },
              raw_trace_result_gas_used: { type: "string", description: "Raw trace result gas used" },
              raw_trace_result_output: { type: "string", description: "Raw trace result output" },
              raw_trace_subtraces_min: { type: "integer", description: "Minimum raw trace subtraces" },
              raw_trace_subtraces_max: { type: "integer", description: "Maximum raw trace subtraces" },
              raw_trace_trace_address: { type: "string", description: "Raw trace trace address" },
              raw_trace_type: { type: "string", description: "Raw trace type" },
              # # 
              # # # State changes filters (comprehensive)
              # # state_changes_address_hash: { type: "string", description: "State change address hash" },
              # # state_changes_address_ens_domain_name: { type: "string", description: "State change address ENS domain name" },
              # # state_changes_address_is_contract: { type: "boolean", description: "State change address is contract" },
              # # state_changes_address_is_scam: { type: "boolean", description: "State change address is scam" },
              # # state_changes_address_is_verified: { type: "boolean", description: "State change address is verified" },
              # # state_changes_address_name: { type: "string", description: "State change address name" },
              # # state_changes_address_proxy_type: { type: "string", description: "State change address proxy type" },
              # # state_changes_balance_after_min: { type: "string", description: "Minimum state change balance after" },
              # # state_changes_balance_after_max: { type: "string", description: "Maximum state change balance after" },
              # # state_changes_balance_before_min: { type: "string", description: "Minimum state change balance before" },
              # # state_changes_balance_before_max: { type: "string", description: "Maximum state change balance before" },
              # # state_changes_change_min: { type: "string", description: "Minimum state change" },
              # # state_changes_change_max: { type: "string", description: "Maximum state change" },
              # # state_changes_is_miner: { type: "boolean", description: "State change is miner" },
              # # state_changes_token_address: { type: "string", description: "State change token address" },
              # # state_changes_token_address_hash: { type: "string", description: "State change token address hash" },
              # # state_changes_token_circulating_market_cap_min: { type: "string", description: "Minimum state change token circulating market cap" },
              # # state_changes_token_circulating_market_cap_max: { type: "string", description: "Maximum state change token circulating market cap" },
              # # state_changes_token_decimals_min: { type: "integer", description: "Minimum state change token decimals" },
              # # state_changes_token_decimals_max: { type: "integer", description: "Maximum state change token decimals" },
              # # state_changes_token_exchange_rate_min: { type: "string", description: "Minimum state change token exchange rate" },
              # # state_changes_token_exchange_rate_max: { type: "string", description: "Maximum state change token exchange rate" },
              # # state_changes_token_holders_min: { type: "integer", description: "Minimum state change token holders" },
              # # state_changes_token_holders_max: { type: "integer", description: "Maximum state change token holders" },
              # # state_changes_token_holders_count_min: { type: "integer", description: "Minimum state change token holders count" },
              # # state_changes_token_holders_count_max: { type: "integer", description: "Maximum state change token holders count" },
              # # state_changes_token_icon_url: { type: "string", description: "State change token icon URL" },
              # # state_changes_token_name: { type: "string", description: "State change token name" },
              # # state_changes_token_symbol: { type: "string", description: "State change token symbol" },
              # # state_changes_token_total_supply_min: { type: "string", description: "Minimum state change token total supply" },
              # # state_changes_token_total_supply_max: { type: "string", description: "Maximum state change token total supply" },
              # # state_changes_token_type: { type: "string", description: "State change token type" },
              # # state_changes_token_volume_24h_min: { type: "string", description: "Minimum state change token 24h volume" },
              # # state_changes_token_volume_24h_max: { type: "string", description: "Maximum state change token 24h volume" },
              # # state_changes_token_id: { type: "string", description: "State change token ID" },
              # # state_changes_type: { type: "string", description: "State change type" },
              # # state_changes_next_page_params_block_number_min: { type: "integer", description: "Minimum state changes next page params block number" },
              # # state_changes_next_page_params_block_number_max: { type: "integer", description: "Maximum state changes next page params block number" },
              # # state_changes_next_page_params_index_min: { type: "integer", description: "Minimum state changes next page params index" },
              # # state_changes_next_page_params_index_max: { type: "integer", description: "Maximum state changes next page params index" },
              # # state_changes_next_page_params_items_count_min: { type: "integer", description: "Minimum state changes next page params items count" },
              # # state_changes_next_page_params_items_count_max: { type: "integer", description: "Maximum state changes next page params items count" },
              # # 
              # # # Summary filters (comprehensive)
              # # summary_success: { type: "boolean", description: "Summary success" },
              # # summary_debug_data_is_prompt_truncated: { type: "boolean", description: "Summary debug data is prompt truncated" },
              # # summary_debug_data_model_classification_type: { type: "string", description: "Summary debug data model classification type" },
              # # summary_debug_data_post_llm_classification_type: { type: "string", description: "Summary debug data post LLM classification type" },
              # # summary_debug_data_summary_template_transfer_template_name: { type: "string", description: "Summary debug data summary template transfer template name" },
              # # summary_debug_data_summary_template_transfer_template_vars_decoded_input: { type: "string", description: "Summary debug data summary template transfer template vars decoded input" },
              # # summary_debug_data_summary_template_transfer_template_vars_erc20_amount: { type: "string", description: "Summary debug data summary template transfer template vars erc20 amount" },
              # # summary_debug_data_summary_template_transfer_template_vars_is_erc20_transfer: { type: "boolean", description: "Summary debug data summary template transfer template vars is erc20 transfer" },
              # # summary_debug_data_summary_template_transfer_template_vars_is_nft_transfer: { type: "boolean", description: "Summary debug data summary template transfer template vars is nft transfer" },
              # # summary_debug_data_summary_template_transfer_template_vars_is_user_ops_transfer: { type: "boolean", description: "Summary debug data summary template transfer template vars is user ops transfer" },
              # # summary_debug_data_summary_template_transfer_template_vars_nft_amount: { type: "string", description: "Summary debug data summary template transfer template vars nft amount" },
              # # summary_debug_data_summary_template_transfer_template_vars_stripped_input: { type: "string", description: "Summary debug data summary template transfer template vars stripped input" },
              # # summary_debug_data_summary_template_transfer_template_vars_to_address_hash: { type: "string", description: "Summary debug data summary template transfer template vars to address hash" },
              # # summary_debug_data_summary_template_transfer_template_vars_to_address_is_contract: { type: "boolean", description: "Summary debug data summary template transfer template vars to address is contract" },
              # # summary_debug_data_summary_template_transfer_template_vars_to_address_is_scam: { type: "boolean", description: "Summary debug data summary template transfer template vars to address is scam" },
              # # summary_debug_data_summary_template_transfer_template_vars_to_address_is_verified: { type: "boolean", description: "Summary debug data summary template transfer template vars to address is verified" },
              # # summary_debug_data_summary_template_transfer_template_vars_token_address: { type: "string", description: "Summary debug data summary template transfer template vars token address" },
              # # summary_debug_data_summary_template_transfer_template_vars_token_symbol: { type: "string", description: "Summary debug data summary template transfer template vars token symbol" },
              # # summary_debug_data_summary_template_transfer_template_vars_token_name: { type: "string", description: "Summary debug data summary template transfer template vars token name" },
              # # summary_debug_data_summary_template_transfer_template_vars_token_type: { type: "string", description: "Summary debug data summary template transfer template vars token type" },
              # # summary_debug_data_summary_template_basic_eth_transfer_template_name: { type: "string", description: "Summary debug data summary template basic eth transfer template name" },
              # # summary_debug_data_summary_template_basic_eth_transfer_template_vars_ether_value: { type: "string", description: "Summary debug data summary template basic eth transfer template vars ether value" },
              # # summary_debug_data_summary_template_basic_eth_transfer_template_vars_from_hash: { type: "string", description: "Summary debug data summary template basic eth transfer template vars from hash" },
              # # summary_debug_data_summary_template_basic_eth_transfer_template_vars_is_from_binance: { type: "boolean", description: "Summary debug data summary template basic eth transfer template vars is from binance" },
              # # summary_debug_data_summary_template_basic_eth_transfer_template_vars_is_to_binance: { type: "boolean", description: "Summary debug data summary template basic eth transfer template vars is to binance" },
              # # summary_debug_data_summary_template_basic_eth_transfer_template_vars_last_set: { type: "string", description: "Summary debug data summary template basic eth transfer template vars last set" },
              # # summary_debug_data_summary_template_basic_eth_transfer_template_vars_to_hash: { type: "string", description: "Summary debug data summary template basic eth transfer template vars to hash" },
              # # summary_debug_data_transaction_hash: { type: "string", description: "Summary debug data transaction hash" },
              # # summary_summaries_summary_template: { type: "string", description: "Summary summaries summary template" },
              # # summary_summaries_summary_template_variables_action_type_type: { type: "string", description: "Summary summaries summary template variables action type type" },
              # # summary_summaries_summary_template_variables_action_type_value: { type: "string", description: "Summary summaries summary template variables action type value" },
              # # summary_summaries_summary_template_variables_amount_type: { type: "string", description: "Summary summaries summary template variables amount type" },
              # # summary_summaries_summary_template_variables_amount_value: { type: "string", description: "Summary summaries summary template variables amount value" },
              # # summary_summaries_summary_template_variables_native_type: { type: "string", description: "Summary summaries summary template variables native type" },
              # # summary_summaries_summary_template_variables_native_value: { type: "string", description: "Summary summaries summary template variables native value" },
              # # summary_summaries_summary_template_variables_to_address_type: { type: "string", description: "Summary summaries summary template variables to address type" },
              # # summary_summaries_summary_template_variables_to_address_value_hash: { type: "string", description: "Summary summaries summary template variables to address value hash" },
              # # summary_summaries_summary_template_variables_to_address_value_is_contract: { type: "boolean", description: "Summary summaries summary template variables to address value is contract" },
              # # summary_summaries_summary_template_variables_to_address_value_is_scam: { type: "boolean", description: "Summary summaries summary template variables to address value is scam" },
              # # summary_summaries_summary_template_variables_to_address_value_is_verified: { type: "boolean", description: "Summary summaries summary template variables to address value is verified" },
              # # 
              # Token transfers next page params
              token_transfers_next_page_params_block_number_min: { type: "integer", description: "Minimum token transfers next page params block number" },
              token_transfers_next_page_params_block_number_max: { type: "integer", description: "Maximum token transfers next page params block number" },
              token_transfers_next_page_params_index_min: { type: "integer", description: "Minimum token transfers next page params index" },
              token_transfers_next_page_params_index_max: { type: "integer", description: "Maximum token transfers next page params index" },
              token_transfers_next_page_params_items_count_min: { type: "integer", description: "Minimum token transfers next page params items count" },
              token_transfers_next_page_params_items_count_max: { type: "integer", description: "Maximum token transfers next page params items count" },
              # # 
              # Pagination and sorting
              limit: { type: "integer", description: "Number of results to return (default: 10, max: 50)" },
              offset: { type: "integer", description: "Number of results to skip for pagination (default: 0)" },
              page: { type: "integer", description: "Page number (alternative to offset, starts at 1)" },
              sort_by: { type: "string", description: "Field to sort by (e.g., value, gas_used, timestamp, priority_fee, etc.)" },
              sort_order: { type: "string", description: "Sort order: 'asc' for ascending or 'desc' for descending (default: 'desc')" }
            },
            required: [],
            additionalProperties: false
          },
          strict: true
        }
      }]
    }.to_json

      http.request(request)
    end.value
    
    raise ApiError, "API error: #{response.code}" unless response.code == '200'
    
    parsed_response = JSON.parse(response.body)
    Rails.logger.debug "LLM Response: #{parsed_response}"
    tool_calls = parsed_response.dig("choices", 0, "message", "tool_calls")
    
    if tool_calls.nil?
      message_content = parsed_response.dig("choices", 0, "message", "content")
      Rails.logger.error "No tool calls found. Message content: #{message_content}"
      raise InvalidQueryError, "No tool calls found in response: #{message_content}"
    end
    
    tool_calls.to_json
  end
end