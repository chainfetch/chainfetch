require 'net/http'
require 'uri'
require 'json'
require 'openssl'

class TransactionDataSearchServiceCurated
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
      
      The search_transactions tool can search through Ethereum transaction data with the following parameter types:
      
      **Core Transaction Parameters:**
      - Basic fields: hash, value, gas_used, gas_limit, gas_price, priority_fee, result
      - Status filters: result (success/failure), transaction_tag
      - Range filters: All numeric fields support _min/_max ranges
      
      **Address Parameters:**
      - from_hash, to_hash: Specific addresses
      - from_*, to_*: Address properties (is_contract, is_verified, is_scam, name, etc.)
      
      **Token Transfer Parameters:**
      - token_transfers_*: Token-related filters
      - Token properties: symbol, name, type, decimals, etc.
      
      **Block and Timing:**
      - block_hash, block_number, timestamp, confirmation_duration
      
      **Advanced Filters:**
      - method_*: Smart contract method calls
      - decoded_input_*: Decoded transaction input
      - logs_*: Transaction logs and events
      
      **Pagination and Sorting:**
      - limit, offset, page, sort_by, sort_order
      
      **Examples:**
      - "failed transactions" → {"result": "failure"}
      - "USDC transfers" → {"token_transfers_token_symbol": "USDC"}  
      - "high value transactions" → {"value_min": "1000000000000000000"}
      - "transactions to Uniswap" → {"to_name": "Uniswap"}
      
      Only include parameters that are directly relevant to the user's query. Be precise and use appropriate parameter names.
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
      request['Authorization'] = "Bearer #{Ethereum::BaseService::BEARER_TOKEN}"

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
              # Core transaction fields (most important)
              hash: { type: "string", description: "Transaction hash" },
              result: { type: "string", description: "Transaction result (success, failure)" },
              value_min: { type: "string", description: "Minimum transaction value in WEI" },
              value_max: { type: "string", description: "Maximum transaction value in WEI" },
              gas_used_min: { type: "string", description: "Minimum gas used" },
              gas_used_max: { type: "string", description: "Maximum gas used" },
              gas_limit_min: { type: "string", description: "Minimum gas limit" },
              gas_limit_max: { type: "string", description: "Maximum gas limit" },
              gas_price_min: { type: "string", description: "Minimum gas price" },
              gas_price_max: { type: "string", description: "Maximum gas price" },
              priority_fee_min: { type: "string", description: "Minimum priority fee" },
              priority_fee_max: { type: "string", description: "Maximum priority fee" },
              max_fee_per_gas_min: { type: "string", description: "Minimum max fee per gas" },
              max_fee_per_gas_max: { type: "string", description: "Maximum max fee per gas" },
              max_priority_fee_per_gas_min: { type: "string", description: "Minimum max priority fee per gas" },
              max_priority_fee_per_gas_max: { type: "string", description: "Maximum max priority fee per gas" },
              
              # Address fields (essential)
              from_hash: { type: "string", description: "From address hash" },
              to_hash: { type: "string", description: "To address hash" },
              from_name: { type: "string", description: "From address name" },
              to_name: { type: "string", description: "To address name" },
              from_is_contract: { type: "boolean", description: "Whether from address is contract" },
              to_is_contract: { type: "boolean", description: "Whether to address is contract" },
              from_is_verified: { type: "boolean", description: "Whether from address is verified" },
              to_is_verified: { type: "boolean", description: "Whether to address is verified" },
              from_is_scam: { type: "boolean", description: "Whether from address is scam" },
              to_is_scam: { type: "boolean", description: "Whether to address is scam" },
              
              # Block and timing
              block_hash: { type: "string", description: "Block hash" },
              block_number_min: { type: "integer", description: "Minimum block number" },
              block_number_max: { type: "integer", description: "Maximum block number" },
              timestamp_min: { type: "string", description: "Minimum timestamp" },
              timestamp_max: { type: "string", description: "Maximum timestamp" },
              transaction_index_min: { type: "integer", description: "Minimum transaction index" },
              transaction_index_max: { type: "integer", description: "Maximum transaction index" },
              
              # Transaction metadata
              transaction_tag: { type: "string", description: "Transaction tag (e.g., 'DeFi Interaction')" },
              type_min: { type: "integer", description: "Minimum transaction type" },
              type_max: { type: "integer", description: "Maximum transaction type" },
              position_min: { type: "integer", description: "Minimum position in block" },
              position_max: { type: "integer", description: "Maximum position in block" },
              revert_reason: { type: "string", description: "Transaction revert reason" },
              raw_input: { type: "string", description: "Transaction raw input data" },
              created_contract: { type: "string", description: "Created contract address" },
              
              # Token transfers (very important for DeFi)
              token_transfers_token_hash: { type: "string", description: "Token contract address" },
              token_transfers_token_symbol: { type: "string", description: "Token symbol (e.g., USDC, ETH)" },
              token_transfers_token_name: { type: "string", description: "Token name" },
              token_transfers_token_type: { type: "string", description: "Token type (ERC-20, ERC-721, etc.)" },
              token_transfers_token_decimals_min: { type: "integer", description: "Minimum token decimals" },
              token_transfers_token_decimals_max: { type: "integer", description: "Maximum token decimals" },
              token_transfers_from_hash: { type: "string", description: "Token transfer from address" },
              token_transfers_to_hash: { type: "string", description: "Token transfer to address" },
              token_transfers_amount_min: { type: "string", description: "Minimum token transfer amount" },
              token_transfers_amount_max: { type: "string", description: "Maximum token transfer amount" },
              token_transfers_log_index_min: { type: "integer", description: "Minimum token transfer log index" },
              token_transfers_log_index_max: { type: "integer", description: "Maximum token transfer log index" },
              token_transfers_token_id: { type: "string", description: "Token ID for NFTs" },
              token_transfers_overflow: { type: "boolean", description: "Whether token transfers overflow" },
              
              # Method calls (smart contract interactions)
              method_method_id: { type: "string", description: "Smart contract method ID" },
              method_call_type: { type: "string", description: "Method call type" },
              
              # Decoded input (for understanding transaction purpose)
              decoded_input_method_call: { type: "string", description: "Decoded method call" },
              decoded_input_method_id: { type: "string", description: "Decoded method ID" },
              decoded_input_parameters_name: { type: "string", description: "Decoded parameter name" },
              decoded_input_parameters_type: { type: "string", description: "Decoded parameter type" },
              decoded_input_parameters_value: { type: "string", description: "Decoded parameter value" },
              
              # Actions (high-level transaction categorization)
              actions_data_from: { type: "string", description: "Action from address" },
              actions_data_to: { type: "string", description: "Action to address" },
              actions_data_token: { type: "string", description: "Action token symbol" },
              actions_data_amount: { type: "string", description: "Action amount" },
              actions_protocol: { type: "string", description: "Protocol involved in action" },
              actions_type: { type: "string", description: "Action type (transfer, swap, etc.)" },
              
              # Fee analysis
              fee_min: { type: "string", description: "Minimum transaction fee" },
              fee_max: { type: "string", description: "Maximum transaction fee" },
              transaction_burnt_fee_min: { type: "string", description: "Minimum burnt fee" },
              transaction_burnt_fee_max: { type: "string", description: "Maximum burnt fee" },
              
              # Exchange rates (for value conversion)
              exchange_rate_min: { type: "string", description: "Minimum exchange rate" },
              exchange_rate_max: { type: "string", description: "Maximum exchange rate" },
              
              # Confirmations and reliability
              confirmations_min: { type: "integer", description: "Minimum confirmations count" },
              confirmations_max: { type: "integer", description: "Maximum confirmations count" },
              confirmation_duration_min: { type: "integer", description: "Minimum confirmation duration in milliseconds" },
              confirmation_duration_max: { type: "integer", description: "Maximum confirmation duration in milliseconds" },
              
              # Error tracking
              has_error_in_internal_transactions: { type: "boolean", description: "Has error in internal transactions" },
              
              # Logs (events emitted)
              logs_address_hash: { type: "string", description: "Log address hash" },
              logs_data: { type: "string", description: "Log data" },
              logs_topics: { type: "string", description: "Log topics" },
              logs_decoded_method_call: { type: "string", description: "Log decoded method call" },
              logs_decoded_method_id: { type: "string", description: "Log decoded method ID" },
              logs_decoded_parameters_name: { type: "string", description: "Log decoded parameters name" },
              logs_decoded_parameters_type: { type: "string", description: "Log decoded parameters type" },
              logs_decoded_parameters_value: { type: "string", description: "Log decoded parameters value" },
              logs_index_min: { type: "integer", description: "Minimum log index" },
              logs_index_max: { type: "integer", description: "Maximum log index" },
              
              # Internal transactions
              internal_transactions_from_hash: { type: "string", description: "Internal transaction from hash" },
              internal_transactions_to_hash: { type: "string", description: "Internal transaction to hash" },
              internal_transactions_value_min: { type: "string", description: "Minimum internal transaction value" },
              internal_transactions_value_max: { type: "string", description: "Maximum internal transaction value" },
              internal_transactions_gas_limit_min: { type: "string", description: "Minimum internal transaction gas limit" },
              internal_transactions_gas_limit_max: { type: "string", description: "Maximum internal transaction gas limit" },
              internal_transactions_success: { type: "boolean", description: "Internal transaction success" },
              internal_transactions_error: { type: "string", description: "Internal transaction error" },
              internal_transactions_type: { type: "string", description: "Internal transaction type" },
              
              # Address metadata (for known entities)
              from_ens_domain_name: { type: "string", description: "From address ENS domain name" },
              to_ens_domain_name: { type: "string", description: "To address ENS domain name" },
              from_proxy_type: { type: "string", description: "From address proxy type" },
              to_proxy_type: { type: "string", description: "To address proxy type" },
              from_private_tags: { type: "string", description: "From address private tags" },
              to_private_tags: { type: "string", description: "To address private tags" },
              from_public_tags: { type: "string", description: "From address public tags" },
              to_public_tags: { type: "string", description: "To address public tags" },
              from_watchlist_names: { type: "string", description: "From address watchlist names" },
              to_watchlist_names: { type: "string", description: "To address watchlist names" },
              
              # Token metadata (for token analysis)
              token_transfers_token_icon_url: { type: "string", description: "Token icon URL" },
              token_transfers_token_total_supply_min: { type: "string", description: "Minimum token total supply" },
              token_transfers_token_total_supply_max: { type: "string", description: "Maximum token total supply" },
              token_transfers_token_exchange_rate_min: { type: "string", description: "Minimum token exchange rate" },
              token_transfers_token_exchange_rate_max: { type: "string", description: "Maximum token exchange rate" },
              token_transfers_token_volume_24h_min: { type: "string", description: "Minimum token 24h volume" },
              token_transfers_token_volume_24h_max: { type: "string", description: "Maximum token 24h volume" },
              token_transfers_token_circulating_market_cap_min: { type: "string", description: "Minimum token circulating market cap" },
              token_transfers_token_circulating_market_cap_max: { type: "string", description: "Maximum token circulating market cap" },
              token_transfers_token_holders_min: { type: "integer", description: "Minimum token holders" },
              token_transfers_token_holders_max: { type: "integer", description: "Maximum token holders" },
              
              # Authorization (EIP-7702)
              authorization_list_authority: { type: "string", description: "Authorization list authority" },
              authorization_list_delegated_address: { type: "string", description: "Authorization list delegated address" },
              authorization_list_nonce: { type: "string", description: "Authorization list nonce" },
              authorization_list_validity: { type: "string", description: "Authorization list validity" },
              
              # Raw trace data
              raw_trace_action_call_type: { type: "string", description: "Raw trace action call type" },
              raw_trace_action_from: { type: "string", description: "Raw trace action from" },
              raw_trace_action_to: { type: "string", description: "Raw trace action to" },
              raw_trace_action_value: { type: "string", description: "Raw trace action value" },
              raw_trace_action_gas: { type: "string", description: "Raw trace action gas" },
              raw_trace_action_input: { type: "string", description: "Raw trace action input" },
              raw_trace_result_gas_used: { type: "string", description: "Raw trace result gas used" },
              raw_trace_result_output: { type: "string", description: "Raw trace result output" },
              raw_trace_type: { type: "string", description: "Raw trace type" },
              
              # State changes
              state_changes_address_hash: { type: "string", description: "State change address hash" },
              state_changes_balance_before_min: { type: "string", description: "Minimum state change balance before" },
              state_changes_balance_before_max: { type: "string", description: "Maximum state change balance before" },
              state_changes_balance_after_min: { type: "string", description: "Minimum state change balance after" },
              state_changes_balance_after_max: { type: "string", description: "Maximum state change balance after" },
              state_changes_change_min: { type: "string", description: "Minimum state change" },
              state_changes_change_max: { type: "string", description: "Maximum state change" },
              state_changes_is_miner: { type: "boolean", description: "State change is miner" },
              state_changes_type: { type: "string", description: "State change type" },
              
              # Summary and classification
              summary_success: { type: "boolean", description: "Summary success" },
              
              # Additional commonly used filters
              nonce_min: { type: "integer", description: "Minimum nonce" },
              nonce_max: { type: "integer", description: "Maximum nonce" },
              cumulative_gas_used_min: { type: "string", description: "Minimum cumulative gas used" },
              cumulative_gas_used_max: { type: "string", description: "Maximum cumulative gas used" },
              error: { type: "string", description: "Transaction error message" },
              status: { type: "string", description: "Transaction status" },
              
              # Token transfer additional filters
              token_transfers_block_number_min: { type: "integer", description: "Minimum token transfer block number" },
              token_transfers_block_number_max: { type: "integer", description: "Maximum token transfer block number" },
              token_transfers_block_hash: { type: "string", description: "Token transfer block hash" },
              token_transfers_transaction_hash: { type: "string", description: "Token transfer transaction hash" },
              
              # Address metadata tags
              from_metadata_tags_name: { type: "string", description: "From address metadata tags name" },
              to_metadata_tags_name: { type: "string", description: "To address metadata tags name" },
              from_metadata_tags_slug: { type: "string", description: "From address metadata tags slug" },
              to_metadata_tags_slug: { type: "string", description: "To address metadata tags slug" },
              from_metadata_tags_tag_type: { type: "string", description: "From address metadata tags tag type" },
              to_metadata_tags_tag_type: { type: "string", description: "To address metadata tags tag type" },
              
              # Logs additional filters
              logs_block_hash: { type: "string", description: "Log block hash" },
              logs_block_number_min: { type: "integer", description: "Minimum log block number" },
              logs_block_number_max: { type: "integer", description: "Maximum log block number" },
              logs_transaction_hash: { type: "string", description: "Log transaction hash" },
              logs_smart_contract_hash: { type: "string", description: "Log smart contract hash" },
              
              # Internal transactions additional
              internal_transactions_block_number_min: { type: "integer", description: "Minimum internal transaction block number" },
              internal_transactions_block_number_max: { type: "integer", description: "Maximum internal transaction block number" },
              internal_transactions_transaction_hash: { type: "string", description: "Internal transaction transaction hash" },
              internal_transactions_index_min: { type: "integer", description: "Minimum internal transaction index" },
              internal_transactions_index_max: { type: "integer", description: "Maximum internal transaction index" },
              
              # Token transfer address details (very important for DeFi)
              token_transfers_from_ens_domain_name: { type: "string", description: "Token transfer from ENS domain name" },
              token_transfers_from_is_contract: { type: "boolean", description: "Token transfer from is contract" },
              token_transfers_from_is_verified: { type: "boolean", description: "Token transfer from is verified" },
              token_transfers_from_is_scam: { type: "boolean", description: "Token transfer from is scam" },
              token_transfers_from_name: { type: "string", description: "Token transfer from name" },
              token_transfers_from_proxy_type: { type: "string", description: "Token transfer from proxy type" },
              token_transfers_to_ens_domain_name: { type: "string", description: "Token transfer to ENS domain name" },
              token_transfers_to_is_contract: { type: "boolean", description: "Token transfer to is contract" },
              token_transfers_to_is_verified: { type: "boolean", description: "Token transfer to is verified" },
              token_transfers_to_is_scam: { type: "boolean", description: "Token transfer to is scam" },
              token_transfers_to_name: { type: "string", description: "Token transfer to name" },
              token_transfers_to_proxy_type: { type: "string", description: "Token transfer to proxy type" },
              token_transfers_token_address: { type: "string", description: "Token transfer token address" },
              token_transfers_token_address_hash: { type: "string", description: "Token transfer token address hash" },
              
              # Token transfer metadata and method details
              token_transfers_to_metadata_tags_name: { type: "string", description: "Token transfer to metadata tags name" },
              token_transfers_to_metadata_tags_slug: { type: "string", description: "Token transfer to metadata tags slug" },
              token_transfers_to_metadata_tags_tag_type: { type: "string", description: "Token transfer to metadata tags tag type" },
              token_transfers_method: { type: "string", description: "Token transfer method" },
              token_transfers_type: { type: "string", description: "Token transfer type" },
              token_transfers_timestamp_min: { type: "string", description: "Minimum token transfer timestamp" },
              token_transfers_timestamp_max: { type: "string", description: "Maximum token transfer timestamp" },
              
              # Token economics and market data
              token_transfers_token_holders_count_min: { type: "integer", description: "Minimum token holders count" },
              token_transfers_token_holders_count_max: { type: "integer", description: "Maximum token holders count" },
              token_transfers_total_value_min: { type: "string", description: "Minimum total token transfer value" },
              token_transfers_total_value_max: { type: "string", description: "Maximum total token transfer value" },
              token_transfers_total_decimals_min: { type: "integer", description: "Minimum total decimals" },
              token_transfers_total_decimals_max: { type: "integer", description: "Maximum total decimals" },
              
              # Fee analysis (important for gas optimization)
              base_fee_per_gas_min: { type: "string", description: "Minimum base fee per gas" },
              base_fee_per_gas_max: { type: "string", description: "Maximum base fee per gas" },
              fee_value_min: { type: "string", description: "Minimum fee value" },
              fee_value_max: { type: "string", description: "Maximum fee value" },
              fee_type: { type: "string", description: "Fee type" },
              
              # Exchange rates for value analysis
              historic_exchange_rate_min: { type: "string", description: "Minimum historic exchange rate" },
              historic_exchange_rate_max: { type: "string", description: "Maximum historic exchange rate" },
              
              # Method and action details for smart contract analysis
              method: { type: "string", description: "Transaction method" },
              actions_action_type: { type: "string", description: "Action type" },
              transaction_types: { type: "string", description: "Transaction types" },
              
              # Address metadata ordinals
              from_metadata_tags_ordinal_min: { type: "integer", description: "Minimum from address metadata tags ordinal" },
              from_metadata_tags_ordinal_max: { type: "integer", description: "Maximum from address metadata tags ordinal" },
              
              # Raw trace details for complex analysis
              raw_trace_subtraces_min: { type: "integer", description: "Minimum raw trace subtraces" },
              raw_trace_subtraces_max: { type: "integer", description: "Maximum raw trace subtraces" },
              raw_trace_trace_address: { type: "string", description: "Raw trace trace address" },
              
              # Authorization list EIP-7702 support
              authorization_list_r: { type: "string", description: "Authorization list r value" },
              authorization_list_s: { type: "string", description: "Authorization list s value" },
              authorization_list_y_parity: { type: "string", description: "Authorization list y parity" },
              
              # Token transfer pagination for large result sets
              token_transfers_next_page_params_block_number_min: { type: "integer", description: "Minimum token transfers next page params block number" },
              token_transfers_next_page_params_block_number_max: { type: "integer", description: "Maximum token transfers next page params block number" },
              token_transfers_next_page_params_index_min: { type: "integer", description: "Minimum token transfers next page params index" },
              token_transfers_next_page_params_index_max: { type: "integer", description: "Maximum token transfers next page params index" },
              token_transfers_next_page_params_items_count_min: { type: "integer", description: "Minimum token transfers next page params items count" },
              token_transfers_next_page_params_items_count_max: { type: "integer", description: "Maximum token transfers next page params items count" },
              
              # Pagination and sorting (essential for usability)
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