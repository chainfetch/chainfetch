require 'net/http'
require 'uri'
require 'json'
require 'openssl'

class BlockDataSearchService
  class ApiError < StandardError; end
  class InvalidQueryError < StandardError; end

  def initialize(query)
    @query = query
    @api_url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
    @api_key = Rails.application.credentials.gemini_api_key
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
      Your task is to call the search_blocks tool with the appropriate parameters to fulfill the user's request.
      
      Analyze the user's query and call the search_blocks tool with the appropriate parameters to fulfill their request.
      
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
      - "by height", "highest blocks" → sort_by: "height", sort_order: "desc"
      - "by gas usage" → sort_by: "gas_used", sort_order: "desc"
      - "by transaction count" → sort_by: "transactions_count", sort_order: "desc"
      - "by fees" → sort_by: "transaction_fees", sort_order: "desc"
      - "by size" → sort_by: "size", sort_order: "desc"
      
      Parameter mapping guide:
      - Block heights → height_min/max
      - Gas usage → gas_used_min/max, gas_limit_min/max, etc.
      - Transaction counts → transaction_count_min/max, transactions_count_min/max
      - Fees → base_fee_per_gas_min/max, transaction_fees_min/max, burnt_fees_min/max
      - Block hashes → hash, parent_hash
      - Miner filters → miner_hash, miner_is_contract, miner_is_verified, etc.
      - Blob transactions → blob_transaction_count_min/max, blob_gas_used_min/max
      - Transaction filters → tx_* parameters for filtering by transaction properties
      - Withdrawal filters → withdrawal_* parameters
      - Time filters → timestamp_min/max
      - Result limits → limit (default: 10, max: 50)
      - Sorting → sort_by (field name), sort_order ("asc" or "desc", default: "desc")
      
      Examples of correct tool calls:
      - "blocks with more than 200 transactions" → search_blocks({"transaction_count_min": 200})
      - "blocks mined by verified addresses" → search_blocks({"miner_is_verified": true})
      - "high gas usage blocks" → search_blocks({"gas_used_min": 20000000})
      - "blocks with blob transactions" → search_blocks({"blob_transaction_count_min": 1})
      - "latest 50 blocks" → search_blocks({"limit": 50, "sort_by": "timestamp", "sort_order": "desc"})
      - "blocks by height descending" → search_blocks({"sort_by": "height", "sort_order": "desc"})
      - "blocks with high fees" → search_blocks({"transaction_fees_min": 1000000000000000000, "sort_by": "transaction_fees", "sort_order": "desc"})
      - "blocks containing withdrawals" → search_blocks({"withdrawals_count_min": 1})

      Set the limit to 10 if not specified.
      
      Always call the search_blocks tool with the parameters that best match the user's intent.
    PROMPT

    response = make_gemini_request(system_prompt, user_query)
    parse_tool_call_response(response)
  end

  def parse_tool_call_response(response)
    parsed_response = JSON.parse(response)
    
    # Gemini response structure: candidates[0].content.parts[0].functionCall
    function_call = parsed_response.dig("candidates", 0, "content", "parts", 0, "functionCall")
    
    if function_call&.dig("name") == "search_blocks"
      return function_call.dig("args") || {}
    else
      raise InvalidQueryError, "No valid tool call found in response"
    end
  rescue JSON::ParserError => e
    raise InvalidQueryError, "Invalid JSON response from AI: #{e.message}"
  end

  def execute_api_request(parameters)
    uri = URI("#{@base_url}/api/v1/ethereum/blocks/json_search")
    uri.query = URI.encode_www_form(parameters) if parameters&.any?
    
    retries = 0
    max_retries = 2
    
    begin
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 10
      http.read_timeout = 30
      http.write_timeout = 10
      
      if uri.scheme == 'https'
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      end
      
      request = Net::HTTP::Get.new(uri)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{Ethereum::BaseService::BEARER_TOKEN}"

      response = http.request(request)
      
      if response.code == '200'
        result = JSON.parse(response.body)
        {
          count: result.dig("results")&.length || 0,
          parameters_used: parameters,
          api_endpoint: uri.to_s,
          blocks: result.dig("results") || []
        }
      else
        {
          error: "API request failed with status: #{response.code}",
          response_body: response.body,
          parameters_used: parameters,
          count: 0,
          blocks: []
        }
      end
    rescue Net::ReadTimeout, Net::OpenTimeout, Net::WriteTimeout => e
      retries += 1
      if retries <= max_retries
        Rails.logger.warn "Timeout on attempt #{retries}/#{max_retries} for block search: #{e.message}"
        sleep(1 * retries)
        retry
      else
        {
          error: "Request timeout after #{max_retries} retries: #{e.message}",
          parameters_used: parameters,
          count: 0,
          blocks: []
        }
      end
    rescue JSON::ParserError => e
      {
        error: "Failed to parse API response: #{e.message}",
        parameters_used: parameters,
        count: 0,
        blocks: []
      }
    rescue => e
      {
        error: "Request failed: #{e.message}",
        parameters_used: parameters,
        count: 0,
        blocks: []
      }
    end
  end

  def make_gemini_request(system_prompt, user_prompt)
    uri = URI(@api_url)
    
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
      request['x-goog-api-key'] = @api_key
      request.body = {
        contents: [
          {
            role: "user",
            parts: [
              {
                text: "#{system_prompt}\n\nUser Query: #{user_prompt}"
              }
            ]
          }
        ],
        tools: [{
          functionDeclarations: [{
            name: "search_blocks",
            description: "Search for Ethereum blocks based on various criteria",
            parameters: {
              type: "object",
              properties: {
              # Block info fields - Numeric with min/max
              base_fee_per_gas_min: { type: "string", description: "Minimum base fee per gas" },
              base_fee_per_gas_max: { type: "string", description: "Maximum base fee per gas" },
              blob_gas_price_min: { type: "string", description: "Minimum blob gas price" },
              blob_gas_price_max: { type: "string", description: "Maximum blob gas price" },
              blob_gas_used_min: { type: "string", description: "Minimum blob gas used" },
              blob_gas_used_max: { type: "string", description: "Maximum blob gas used" },
              blob_transaction_count_min: { type: "integer", description: "Minimum blob transaction count" },
              blob_transaction_count_max: { type: "integer", description: "Maximum blob transaction count" },
              blob_transactions_count_min: { type: "integer", description: "Minimum blob transactions count" },
              blob_transactions_count_max: { type: "integer", description: "Maximum blob transactions count" },
              burnt_blob_fees_min: { type: "string", description: "Minimum burnt blob fees" },
              burnt_blob_fees_max: { type: "string", description: "Maximum burnt blob fees" },
              burnt_fees_min: { type: "string", description: "Minimum burnt fees" },
              burnt_fees_max: { type: "string", description: "Maximum burnt fees" },
              burnt_fees_percentage_min: { type: "number", description: "Minimum burnt fees percentage" },
              burnt_fees_percentage_max: { type: "number", description: "Maximum burnt fees percentage" },
              difficulty_min: { type: "string", description: "Minimum difficulty" },
              difficulty_max: { type: "string", description: "Maximum difficulty" },
              excess_blob_gas_min: { type: "string", description: "Minimum excess blob gas" },
              excess_blob_gas_max: { type: "string", description: "Maximum excess blob gas" },
              gas_limit_min: { type: "string", description: "Minimum gas limit" },
              gas_limit_max: { type: "string", description: "Maximum gas limit" },
              gas_target_percentage_min: { type: "number", description: "Minimum gas target percentage" },
              gas_target_percentage_max: { type: "number", description: "Maximum gas target percentage" },
              gas_used_min: { type: "string", description: "Minimum gas used" },
              gas_used_max: { type: "string", description: "Maximum gas used" },
              gas_used_percentage_min: { type: "number", description: "Minimum gas used percentage" },
              gas_used_percentage_max: { type: "number", description: "Maximum gas used percentage" },
              height_min: { type: "integer", description: "Minimum block height" },
              height_max: { type: "integer", description: "Maximum block height" },
              internal_transactions_count_min: { type: "integer", description: "Minimum internal transactions count" },
              internal_transactions_count_max: { type: "integer", description: "Maximum internal transactions count" },
              priority_fee_min: { type: "string", description: "Minimum priority fee" },
              priority_fee_max: { type: "string", description: "Maximum priority fee" },
              size_min: { type: "integer", description: "Minimum block size" },
              size_max: { type: "integer", description: "Maximum block size" },
              total_difficulty_min: { type: "string", description: "Minimum total difficulty" },
              total_difficulty_max: { type: "string", description: "Maximum total difficulty" },
              transaction_count_min: { type: "integer", description: "Minimum transaction count" },
              transaction_count_max: { type: "integer", description: "Maximum transaction count" },
              transaction_fees_min: { type: "string", description: "Minimum transaction fees" },
              transaction_fees_max: { type: "string", description: "Maximum transaction fees" },
              transactions_count_min: { type: "integer", description: "Minimum transactions count" },
              transactions_count_max: { type: "integer", description: "Maximum transactions count" },
              withdrawals_count_min: { type: "integer", description: "Minimum withdrawals count" },
              withdrawals_count_max: { type: "integer", description: "Maximum withdrawals count" },
              
              # Block info fields - String
              hash: { type: "string", description: "Block hash" },
              nonce: { type: "string", description: "Block nonce" },
              parent_hash: { type: "string", description: "Parent block hash" },
              block_type: { type: "string", description: "Block type" },
              timestamp_min: { type: "string", description: "Minimum timestamp (ISO format)" },
              timestamp_max: { type: "string", description: "Maximum timestamp (ISO format)" },
              
              # Miner fields
              miner_hash: { type: "string", description: "Miner address hash" },
              miner_ens_domain_name: { type: "string", description: "Miner ENS domain name" },
              miner_is_contract: { type: "boolean", description: "Whether miner is contract" },
              miner_is_scam: { type: "boolean", description: "Whether miner is scam" },
              miner_is_verified: { type: "boolean", description: "Whether miner is verified" },
              miner_name: { type: "string", description: "Miner name" },
              miner_proxy_type: { type: "string", description: "Miner proxy type" },
              
              # Reward fields
              reward_type: { type: "string", description: "Reward type" },
              reward_value_min: { type: "string", description: "Minimum reward value" },
              reward_value_max: { type: "string", description: "Maximum reward value" },
              
              # Transaction fields
              tx_hash: { type: "string", description: "Transaction hash" },
              tx_priority_fee_min: { type: "string", description: "Minimum transaction priority fee" },
              tx_priority_fee_max: { type: "string", description: "Maximum transaction priority fee" },
              tx_raw_input: { type: "string", description: "Transaction raw input" },
              tx_result: { type: "string", description: "Transaction result" },
              tx_max_fee_per_gas_min: { type: "string", description: "Minimum transaction max fee per gas" },
              tx_max_fee_per_gas_max: { type: "string", description: "Maximum transaction max fee per gas" },
              tx_revert_reason: { type: "string", description: "Transaction revert reason" },
              tx_confirmation_duration_min: { type: "integer", description: "Minimum confirmation duration" },
              tx_confirmation_duration_max: { type: "integer", description: "Maximum confirmation duration" },
              tx_transaction_burnt_fee_min: { type: "string", description: "Minimum transaction burnt fee" },
              tx_transaction_burnt_fee_max: { type: "string", description: "Maximum transaction burnt fee" },
              tx_type_min: { type: "integer", description: "Minimum transaction type" },
              tx_type_max: { type: "integer", description: "Maximum transaction type" },
              tx_token_transfers_overflow: { type: "boolean", description: "Transaction token transfers overflow" },
              tx_confirmations_min: { type: "integer", description: "Minimum transaction confirmations" },
              tx_confirmations_max: { type: "integer", description: "Maximum transaction confirmations" },
              tx_position_min: { type: "integer", description: "Minimum transaction position" },
              tx_position_max: { type: "integer", description: "Maximum transaction position" },
              tx_max_priority_fee_per_gas_min: { type: "string", description: "Minimum transaction max priority fee per gas" },
              tx_max_priority_fee_per_gas_max: { type: "string", description: "Maximum transaction max priority fee per gas" },
              tx_transaction_tag: { type: "string", description: "Transaction tag" },
              tx_created_contract: { type: "string", description: "Transaction created contract" },
              tx_value_min: { type: "string", description: "Minimum transaction value" },
              tx_value_max: { type: "string", description: "Maximum transaction value" },
              tx_from_hash: { type: "string", description: "Transaction from hash" },
              tx_from_ens_domain_name: { type: "string", description: "Transaction from ENS domain name" },
              tx_from_is_contract: { type: "boolean", description: "Transaction from is contract" },
              tx_from_is_scam: { type: "boolean", description: "Transaction from is scam" },
              tx_from_is_verified: { type: "boolean", description: "Transaction from is verified" },
              tx_from_name: { type: "string", description: "Transaction from name" },
              tx_from_proxy_type: { type: "string", description: "Transaction from proxy type" },
              tx_gas_used_min: { type: "string", description: "Minimum transaction gas used" },
              tx_gas_used_max: { type: "string", description: "Maximum transaction gas used" },
              tx_status: { type: "string", description: "Transaction status" },
              tx_to_hash: { type: "string", description: "Transaction to hash" },
              tx_to_ens_domain_name: { type: "string", description: "Transaction to ENS domain name" },
              tx_to_is_contract: { type: "boolean", description: "Transaction to is contract" },
              tx_to_is_scam: { type: "boolean", description: "Transaction to is scam" },
              tx_to_is_verified: { type: "boolean", description: "Transaction to is verified" },
              tx_to_name: { type: "string", description: "Transaction to name" },
              tx_to_proxy_type: { type: "string", description: "Transaction to proxy type" },
              tx_authorization_list: { type: "string", description: "Transaction authorization list" },
              tx_method: { type: "string", description: "Transaction method" },
              tx_fee_type: { type: "string", description: "Transaction fee type" },
              tx_fee_value_min: { type: "string", description: "Minimum transaction fee value" },
              tx_fee_value_max: { type: "string", description: "Maximum transaction fee value" },
              tx_gas_limit_min: { type: "string", description: "Minimum transaction gas limit" },
              tx_gas_limit_max: { type: "string", description: "Maximum transaction gas limit" },
              tx_gas_price_min: { type: "string", description: "Minimum transaction gas price" },
              tx_gas_price_max: { type: "string", description: "Maximum transaction gas price" },
              tx_decoded_input: { type: "string", description: "Transaction decoded input" },
              tx_token_transfers: { type: "string", description: "Transaction token transfers" },
              tx_base_fee_per_gas_min: { type: "string", description: "Minimum transaction base fee per gas" },
              tx_base_fee_per_gas_max: { type: "string", description: "Maximum transaction base fee per gas" },
              tx_timestamp_min: { type: "string", description: "Minimum transaction timestamp" },
              tx_timestamp_max: { type: "string", description: "Maximum transaction timestamp" },
              tx_nonce_min: { type: "integer", description: "Minimum transaction nonce" },
              tx_nonce_max: { type: "integer", description: "Maximum transaction nonce" },
              tx_historic_exchange_rate_min: { type: "string", description: "Minimum historic exchange rate" },
              tx_historic_exchange_rate_max: { type: "string", description: "Maximum historic exchange rate" },
              tx_transaction_types: { type: "string", description: "Transaction types" },
              tx_exchange_rate_min: { type: "string", description: "Minimum exchange rate" },
              tx_exchange_rate_max: { type: "string", description: "Maximum exchange rate" },
              tx_block_number_min: { type: "integer", description: "Minimum transaction block number" },
              tx_block_number_max: { type: "integer", description: "Maximum transaction block number" },
              tx_has_error_in_internal_transactions: { type: "boolean", description: "Transaction has error in internal transactions" },
              
              # Withdrawal fields
              withdrawal_amount_min: { type: "string", description: "Minimum withdrawal amount" },
              withdrawal_amount_max: { type: "string", description: "Maximum withdrawal amount" },
              withdrawal_index_min: { type: "integer", description: "Minimum withdrawal index" },
              withdrawal_index_max: { type: "integer", description: "Maximum withdrawal index" },
              withdrawal_receiver_hash: { type: "string", description: "Withdrawal receiver hash" },
              withdrawal_receiver_ens_domain_name: { type: "string", description: "Withdrawal receiver ENS domain name" },
              withdrawal_receiver_is_contract: { type: "boolean", description: "Withdrawal receiver is contract" },
              withdrawal_receiver_is_scam: { type: "boolean", description: "Withdrawal receiver is scam" },
              withdrawal_receiver_is_verified: { type: "boolean", description: "Withdrawal receiver is verified" },
              withdrawal_receiver_name: { type: "string", description: "Withdrawal receiver name" },
              withdrawal_receiver_proxy_type: { type: "string", description: "Withdrawal receiver proxy type" },
              withdrawal_validator_index_min: { type: "integer", description: "Minimum withdrawal validator index" },
              withdrawal_validator_index_max: { type: "integer", description: "Maximum withdrawal validator index" },
              withdrawal_metadata_tags_name: { type: "string", description: "Withdrawal metadata tags name" },
              withdrawal_metadata_tags_slug: { type: "string", description: "Withdrawal metadata tags slug" },
              withdrawal_metadata_tags_tag_type: { type: "string", description: "Withdrawal metadata tags tag type" },
              withdrawal_metadata_tags_ordinal_min: { type: "integer", description: "Minimum withdrawal metadata tags ordinal" },
              withdrawal_metadata_tags_ordinal_max: { type: "integer", description: "Maximum withdrawal metadata tags ordinal" },
              
              # Pagination and sorting
              limit: { type: "integer", description: "Number of results to return (default: 10, max: 50)" },
              offset: { type: "integer", description: "Number of results to skip for pagination (default: 0)" },
              page: { type: "integer", description: "Page number (alternative to offset, starts at 1)" },
              sort_by: { type: "string", description: "Field to sort by (e.g., height, gas_used, transaction_fees, timestamp, etc.)" },
              sort_order: { type: "string", description: "Sort order: 'asc' for ascending or 'desc' for descending (default: 'desc')" }
            },
            required: []
          }
        }]
      }]
    }.to_json

      http.request(request)
    end.value
    
    raise ApiError, "API error: #{response.code}" unless response.code == '200'
    
    response.body
  end
end