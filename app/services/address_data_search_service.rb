class AddressDataSearchService
  class ApiError < StandardError; end
  class InvalidQueryError < StandardError; end

  def initialize(query)
    @query = query
    @api_url = "https://llama.chainfetch.app"
    @model = "llama3.1:8b"
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
      Your task is to convert natural language queries into the correct parameters for the "search_addresses" tool.
      
      Analyze the user's query and call the search_addresses tool with the appropriate parameters to fulfill their request.
      
      CRITICAL: Pay careful attention to comparison operators in natural language:
      - "more than", "greater than", "above", "at least" → use _min parameters
      - "less than", "below", "under", "at most" → use _max parameters  
      - "between X and Y" → use both _min and _max parameters
      - "exactly", "equal to" → use the exact value without min/max suffix
      
      Parameter mapping guide:
      - ETH amounts → eth_balance_min/max (in ETH units like "1.5")
      - WEI amounts → coin_balance_min/max (in WEI like "1500000000000000000")
      - Transaction counts → transactions_count_min/max
      - Gas usage → tx_gas_used_min/max, tx_gas_limit_min/max, etc.
      - Address types → is_contract, is_verified, is_scam
      - Token filters → token_symbol, token_name, token_address, token_type
      - NFT filters → nft_* parameters
      - Activity flags → has_logs, has_token_transfers, has_tokens, etc.
      - Result limits → limit (default: 100, max: 1000)
      
      Examples of correct tool calls:
      - "addresses with more than 1 ETH" → search_addresses({"eth_balance_min": "1"})
      - "verified contracts" → search_addresses({"is_contract": true, "is_verified": true})
      - "addresses holding USDC" → search_addresses({"token_symbol": "USDC"})
      - "100+ transaction addresses" → search_addresses({"transactions_count_min": 100})
      - "top 50 by balance" → search_addresses({"limit": 50})
      
      Always call the search_addresses tool with the parameters that best match the user's intent.
    PROMPT

    response = make_llama_request(system_prompt, user_query)
    parse_tool_call_response(response)
  end

  def parse_tool_call_response(response)
    tool_calls = JSON.parse(response)
    
    if tool_calls.is_a?(Array) && tool_calls.first&.dig("function", "name") == "search_addresses"
      arguments = JSON.parse(tool_calls.first.dig("function", "arguments"))
      return arguments
    elsif tool_calls.is_a?(Hash) && tool_calls.dig("function", "name") == "search_addresses"
      arguments = JSON.parse(tool_calls.dig("function", "arguments"))
      return arguments
    else
      raise InvalidQueryError, "No valid tool call found in response"
    end
  rescue JSON::ParserError => e
    raise InvalidQueryError, "Invalid JSON response from AI: #{e.message}"
  end

  def execute_api_request(parameters)
    uri = URI("#{@base_url}/api/v1/ethereum/addresses/json_search")
    uri.query = URI.encode_www_form(parameters) if parameters&.any?
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 30
    
    if uri.scheme == 'https'
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    end
    
    request = Net::HTTP::Get.new(uri)
    request['Content-Type'] = 'application/json'
    
    response = http.request(request)
    
    if response.code == '200'
      result = JSON.parse(response.body)
      {
        count: result.dig("results")&.length || 0,
        parameters_used: parameters,
        api_endpoint: uri.to_s,
        addresses: result.dig("results") || []
      }
    else
      {
        error: "API request failed with status: #{response.code}",
        response_body: response.body,
        parameters_used: parameters,
        count: 0,
        addresses: []
      }
    end
  rescue JSON::ParserError => e
    {
      error: "Failed to parse API response: #{e.message}",
      parameters_used: parameters,
      count: 0,
      addresses: []
    }
  rescue => e
    {
      error: "Request failed: #{e.message}",
      parameters_used: parameters,
      count: 0,
      addresses: []
    }
  end

  def make_llama_request(system_prompt, user_prompt)
    uri = URI("#{@api_url}/v1/chat/completions")
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
          name: "search_addresses",
          description: "Search for Ethereum addresses based on various criteria",
          parameters: {
            type: "object",
            properties: {
              eth_balance_min: { type: "string", description: "Minimum ETH balance in ETH units" },
              eth_balance_max: { type: "string", description: "Maximum ETH balance in ETH units" },
              coin_balance_min: { type: "string", description: "Minimum coin balance in WEI" },
              coin_balance_max: { type: "string", description: "Maximum coin balance in WEI" },
              exchange_rate_min: { type: "string", description: "Minimum exchange rate" },
              exchange_rate_max: { type: "string", description: "Maximum exchange rate" },
              has_logs: { type: "boolean", description: "Whether the address has logs" },
              is_contract: { type: "boolean", description: "Whether the address is a contract" },
              has_beacon_chain_withdrawals: { type: "boolean", description: "Whether the address has beacon chain withdrawals" },
              has_token_transfers: { type: "boolean", description: "Whether the address has token transfers" },
              has_tokens: { type: "boolean", description: "Whether the address has tokens" },
              has_validated_blocks: { type: "boolean", description: "Whether the address has validated blocks" },
              is_scam: { type: "boolean", description: "Whether the address is a scam" },
              is_verified: { type: "boolean", description: "Whether the address is verified" },
              ens_domain_name: { type: "string", description: "ENS domain name" },
              name: { type: "string", description: "Address name" },
              hash: { type: "string", description: "Address hash" },
              creation_transaction_hash: { type: "string", description: "Creation transaction hash" },
              creator_address_hash: { type: "string", description: "Creator address hash" },
              proxy_type: { type: "string", description: "Proxy type" },
              watchlist_address_id: { type: "string", description: "Watchlist address ID" },
              block_number_balance_updated_at_min: { type: "integer", description: "Minimum block number balance updated at" },
              block_number_balance_updated_at_max: { type: "integer", description: "Maximum block number balance updated at" },
              coin_balance_history_block_number_min: { type: "integer", description: "Minimum coin balance history block number" },
              coin_balance_history_block_number_max: { type: "integer", description: "Maximum coin balance history block number" },
              coin_balance_history_block_timestamp_min: { type: "string", description: "Minimum coin balance history block timestamp" },
              coin_balance_history_block_timestamp_max: { type: "string", description: "Maximum coin balance history block timestamp" },
              coin_balance_history_delta_min: { type: "string", description: "Minimum coin balance history delta" },
              coin_balance_history_delta_max: { type: "string", description: "Maximum coin balance history delta" },
              coin_balance_history_value_min: { type: "string", description: "Minimum coin balance history value" },
              coin_balance_history_value_max: { type: "string", description: "Maximum coin balance history value" },
              coin_balance_history_tx_hash: { type: "string", description: "Coin balance history transaction hash" },
              coin_balance_history_by_day_days_min: { type: "integer", description: "Minimum days in coin balance history by day" },
              coin_balance_history_by_day_days_max: { type: "integer", description: "Maximum days in coin balance history by day" },
              transactions_count_min: { type: "integer", description: "Minimum transaction count" },
              transactions_count_max: { type: "integer", description: "Maximum transaction count" },
              token_transfers_count_min: { type: "integer", description: "Minimum token transfer count" },
              token_transfers_count_max: { type: "integer", description: "Maximum token transfer count" },
              gas_usage_count_min: { type: "integer", description: "Minimum gas usage count" },
              gas_usage_count_max: { type: "integer", description: "Maximum gas usage count" },
              validations_count_min: { type: "integer", description: "Minimum validation count" },
              validations_count_max: { type: "integer", description: "Maximum validation count" },
              tx_hash: { type: "string", description: "Transaction hash" },
              tx_status: { type: "string", description: "Transaction status" },
              tx_result: { type: "string", description: "Transaction result" },
              tx_method: { type: "string", description: "Transaction method" },
              tx_type_min: { type: "integer", description: "Minimum transaction type" },
              tx_type_max: { type: "integer", description: "Maximum transaction type" },
              tx_value_min: { type: "string", description: "Minimum transaction value" },
              tx_value_max: { type: "string", description: "Maximum transaction value" },
              tx_gas_used_min: { type: "string", description: "Minimum gas used" },
              tx_gas_used_max: { type: "string", description: "Maximum gas used" },
              tx_gas_limit_min: { type: "string", description: "Minimum gas limit" },
              tx_gas_limit_max: { type: "string", description: "Maximum gas limit" },
              tx_gas_price_min: { type: "string", description: "Minimum gas price" },
              tx_gas_price_max: { type: "string", description: "Maximum gas price" },
              tx_from_hash: { type: "string", description: "Transaction from hash" },
              tx_to_hash: { type: "string", description: "Transaction to hash" },
              tx_block_number_min: { type: "integer", description: "Minimum transaction block number" },
              tx_block_number_max: { type: "integer", description: "Maximum transaction block number" },
              tx_block_hash: { type: "string", description: "Transaction block hash" },
              tx_priority_fee_min: { type: "string", description: "Minimum transaction priority fee" },
              tx_priority_fee_max: { type: "string", description: "Maximum transaction priority fee" },
              tx_raw_input: { type: "string", description: "Transaction raw input" },
              tx_max_fee_per_gas_min: { type: "string", description: "Minimum max fee per gas" },
              tx_max_fee_per_gas_max: { type: "string", description: "Maximum max fee per gas" },
              tx_revert_reason: { type: "string", description: "Transaction revert reason" },
              tx_transaction_burnt_fee_min: { type: "string", description: "Minimum transaction burnt fee" },
              tx_transaction_burnt_fee_max: { type: "string", description: "Maximum transaction burnt fee" },
              tx_token_transfers_overflow: { type: "boolean", description: "Transaction token transfers overflow" },
              tx_confirmations_min: { type: "integer", description: "Minimum transaction confirmations" },
              tx_confirmations_max: { type: "integer", description: "Maximum transaction confirmations" },
              tx_position_min: { type: "integer", description: "Minimum transaction position" },
              tx_position_max: { type: "integer", description: "Maximum transaction position" },
              tx_max_priority_fee_per_gas_min: { type: "string", description: "Minimum max priority fee per gas" },
              tx_max_priority_fee_per_gas_max: { type: "string", description: "Maximum max priority fee per gas" },
              tx_transaction_tag: { type: "string", description: "Transaction tag" },
              tx_created_contract: { type: "string", description: "Transaction created contract" },
              tx_base_fee_per_gas_min: { type: "string", description: "Minimum base fee per gas" },
              tx_base_fee_per_gas_max: { type: "string", description: "Maximum base fee per gas" },
              tx_timestamp_min: { type: "string", description: "Minimum transaction timestamp" },
              tx_timestamp_max: { type: "string", description: "Maximum transaction timestamp" },
              tx_nonce_min: { type: "integer", description: "Minimum transaction nonce" },
              tx_nonce_max: { type: "integer", description: "Maximum transaction nonce" },
              tx_historic_exchange_rate_min: { type: "string", description: "Minimum historic exchange rate" },
              tx_historic_exchange_rate_max: { type: "string", description: "Maximum historic exchange rate" },
              tx_exchange_rate_min: { type: "string", description: "Minimum transaction exchange rate" },
              tx_exchange_rate_max: { type: "string", description: "Maximum transaction exchange rate" },
              tx_has_error_in_internal_transactions: { type: "boolean", description: "Transaction has error in internal transactions" },
              tx_log_index_min: { type: "integer", description: "Minimum transaction log index" },
              tx_log_index_max: { type: "integer", description: "Maximum transaction log index" },
              tx_decoded_input: { type: "string", description: "Transaction decoded input" },
              tx_token_transfers: { type: "string", description: "Transaction token transfers" },
              tx_fee_type: { type: "string", description: "Transaction fee type" },
              tx_fee_value_min: { type: "string", description: "Minimum transaction fee value" },
              tx_fee_value_max: { type: "string", description: "Maximum transaction fee value" },
              tx_total_decimals_min: { type: "integer", description: "Minimum transaction total decimals" },
              tx_total_decimals_max: { type: "integer", description: "Maximum transaction total decimals" },
              tx_total_value_min: { type: "string", description: "Minimum transaction total value" },
              tx_total_value_max: { type: "string", description: "Maximum transaction total value" },
              tx_from_ens_domain_name: { type: "string", description: "Transaction from ENS domain name" },
              tx_from_is_contract: { type: "boolean", description: "Transaction from is contract" },
              tx_from_is_scam: { type: "boolean", description: "Transaction from is scam" },
              tx_from_is_verified: { type: "boolean", description: "Transaction from is verified" },
              tx_from_name: { type: "string", description: "Transaction from name" },
              tx_from_proxy_type: { type: "string", description: "Transaction from proxy type" },
              tx_to_ens_domain_name: { type: "string", description: "Transaction to ENS domain name" },
              tx_to_is_contract: { type: "boolean", description: "Transaction to is contract" },
              tx_to_is_scam: { type: "boolean", description: "Transaction to is scam" },
              tx_to_is_verified: { type: "boolean", description: "Transaction to is verified" },
              tx_to_name: { type: "string", description: "Transaction to name" },
              tx_to_proxy_type: { type: "string", description: "Transaction to proxy type" },
              token_address: { type: "string", description: "Token address" },
              token_name: { type: "string", description: "Token name" },
              token_symbol: { type: "string", description: "Token symbol" },
              token_type: { type: "string", description: "Token type (ERC-20, ERC-721, ERC-1155)" },
              token_decimals_min: { type: "integer", description: "Minimum token decimals" },
              token_decimals_max: { type: "integer", description: "Maximum token decimals" },
              token_holders_min: { type: "integer", description: "Minimum token holders" },
              token_holders_max: { type: "integer", description: "Maximum token holders" },
              token_total_supply_min: { type: "string", description: "Minimum token total supply" },
              token_total_supply_max: { type: "string", description: "Maximum token total supply" },
              token_balance_value_min: { type: "string", description: "Minimum token balance value" },
              token_balance_value_max: { type: "string", description: "Maximum token balance value" },
              token_id: { type: "string", description: "Token ID" },
              token_circulating_market_cap_min: { type: "string", description: "Minimum token circulating market cap" },
              token_circulating_market_cap_max: { type: "string", description: "Maximum token circulating market cap" },
              token_icon_url: { type: "string", description: "Token icon URL" },
              token_volume_24h_min: { type: "string", description: "Minimum token 24h volume" },
              token_volume_24h_max: { type: "string", description: "Maximum token 24h volume" },
              token_instance_animation_url: { type: "string", description: "Token instance animation URL" },
              token_instance_external_app_url: { type: "string", description: "Token instance external app URL" },
              token_instance_id: { type: "string", description: "Token instance ID" },
              token_instance_image_url: { type: "string", description: "Token instance image URL" },
              token_instance_is_unique: { type: "boolean", description: "Token instance is unique" },
              token_instance_media_type: { type: "string", description: "Token instance media type" },
              token_instance_media_url: { type: "string", description: "Token instance media URL" },
              token_instance_owner: { type: "string", description: "Token instance owner" },
              token_instance_thumbnails: { type: "string", description: "Token instance thumbnails" },
              token_instance_metadata_description: { type: "string", description: "Token instance metadata description" },
              token_instance_metadata_image: { type: "string", description: "Token instance metadata image" },
              token_instance_metadata_name: { type: "string", description: "Token instance metadata name" },
              nft_animation_url: { type: "string", description: "NFT animation URL" },
              nft_external_app_url: { type: "string", description: "NFT external app URL" },
              nft_image_url: { type: "string", description: "NFT image URL" },
              nft_media_url: { type: "string", description: "NFT media URL" },
              nft_media_type: { type: "string", description: "NFT media type" },
              nft_is_unique: { type: "boolean", description: "Whether NFT is unique" },
              nft_token_type: { type: "string", description: "NFT token type" },
              nft_metadata_description: { type: "string", description: "NFT metadata description" },
              nft_metadata_name: { type: "string", description: "NFT metadata name" },
              nft_collections_amount_min: { type: "integer", description: "Minimum NFT collections amount" },
              nft_collections_amount_max: { type: "integer", description: "Maximum NFT collections amount" },
              metadata_tags_name: { type: "string", description: "Metadata tags name" },
              metadata_tags_slug: { type: "string", description: "Metadata tags slug" },
              metadata_tags_tag_type: { type: "string", description: "Metadata tags tag type" },
              metadata_tags_ordinal_min: { type: "integer", description: "Minimum metadata tags ordinal" },
              metadata_tags_ordinal_max: { type: "integer", description: "Maximum metadata tags ordinal" },
              metadata_tags_meta_main_entity: { type: "string", description: "Metadata tags meta main entity" },
              metadata_tags_meta_tooltip_url: { type: "string", description: "Metadata tags meta tooltip URL" },
              limit: { type: "integer", description: "Number of results to return (default: 100, max: 1000)" }
            },
            required: [],
            additionalProperties: false
          },
          strict: true
        }
      }]
    }.to_json

    response = http.request(request)
    raise ApiError, "API error: #{response.code}" unless response.code == '200'
    
    parsed_response = JSON.parse(response.body)
    tool_calls = parsed_response.dig("choices", 0, "message", "tool_calls")
    
    if tool_calls.nil?
      raise InvalidQueryError, "No tool calls found in response"
    end
    
    tool_calls.to_json
  end
end