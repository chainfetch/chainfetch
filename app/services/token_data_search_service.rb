require 'net/http'
require 'uri'
require 'json'
require 'openssl'

class TokenDataSearchService
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
      Your task is to call the search_tokens tool with the appropriate parameters to fulfill the user's request.
      
      Analyze the user's query and call the search_tokens tool with the appropriate parameters to fulfill their request.
      
      CRITICAL: Pay careful attention to comparison operators in natural language:
      - "more than", "greater than", "above", "at least" → use _min parameters
      - "less than", "below", "under", "at most" → use _max parameters  
      - "between X and Y" → use both _min and _max parameters
      - "exactly", "equal to" → use the exact value without min/max suffix
      
      SORTING: Recognize sorting intentions in natural language:
      - "top", "highest", "largest", "most" → sort_order: "desc"
      - "bottom", "lowest", "smallest", "least" → sort_order: "asc"
      - "newest", "latest", "recent" → sort_by: "created_at", sort_order: "desc"
      - "oldest", "earliest" → sort_by: "created_at", sort_order: "asc"
      - "by holders", "most holders" → sort_by: "holders_count", sort_order: "desc"
      - "by volume", "highest volume" → sort_by: "volume_24h", sort_order: "desc"
      - "by market cap" → sort_by: "circulating_market_cap", sort_order: "desc"
      - "by transfers" → sort_by: "transfers_count", sort_order: "desc"
      
      Parameter mapping guide:
      - Token basics → name, symbol, address, type
      - Market data → exchange_rate_min/max, volume_24h_min/max, circulating_market_cap_min/max
      - Supply metrics → total_supply_min/max, decimals_min/max
      - Holder metrics → holders_count_min/max
      - Activity metrics → transfers_count_min/max
      - Transfer patterns → from_address, to_address, value_min/max
      - Token type filtering → type (ERC-20, ERC-721, ERC-1155)
      - Result limits → limit (default: 10, max: 50)
      - Sorting → sort_by (field name), sort_order ("asc" or "desc", default: "desc")
      
      Examples of correct tool calls:
      - "tokens with more than 1000 holders" → search_tokens({"holders_count_min": 1000})
      - "ERC-20 tokens by volume" → search_tokens({"type": "ERC-20", "sort_by": "volume_24h", "sort_order": "desc"})
      - "tokens named like USDC" → search_tokens({"name": "USDC"})
      - "highest market cap tokens" → search_tokens({"sort_by": "circulating_market_cap", "sort_order": "desc"})
      - "tokens with symbol ETH" → search_tokens({"symbol": "ETH"})
      - "most active tokens by transfers" → search_tokens({"sort_by": "transfers_count", "sort_order": "desc"})

      Set the limit to 10 if not specified.
      
      Always call the search_tokens tool with the parameters that best match the user's intent.
    PROMPT

    response = make_llama_request(system_prompt, user_query)
    parse_tool_call_response(response)
  end

  def parse_tool_call_response(response)
    tool_calls = JSON.parse(response)
    
    if tool_calls.is_a?(Array) && tool_calls.first&.dig("function", "name") == "search_tokens"
      arguments = JSON.parse(tool_calls.first.dig("function", "arguments"))
      return arguments
    elsif tool_calls.is_a?(Hash) && tool_calls.dig("function", "name") == "search_tokens"
      arguments = JSON.parse(tool_calls.dig("function", "arguments"))
      return arguments
    else
      raise InvalidQueryError, "No valid tool call found in response"
    end
  rescue JSON::ParserError => e
    raise InvalidQueryError, "Invalid JSON response from AI: #{e.message}"
  end

  def execute_api_request(parameters)
    uri = URI("#{@base_url}/api/v1/ethereum/tokens/json_search")
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
          tokens: result.dig("results") || []
        }
      else
        {
          error: "API request failed with status: #{response.code}",
          response_body: response.body,
          parameters_used: parameters,
          count: 0,
          tokens: []
        }
      end
    rescue Net::ReadTimeout, Net::OpenTimeout, Net::WriteTimeout => e
      retries += 1
      if retries <= max_retries
        Rails.logger.warn "Timeout on attempt #{retries}/#{max_retries} for token search: #{e.message}"
        sleep(1 * retries)
        retry
      else
        {
          error: "Request timeout after #{max_retries} retries: #{e.message}",
          parameters_used: parameters,
          count: 0,
          tokens: []
        }
      end
    rescue JSON::ParserError => e
      {
        error: "Failed to parse API response: #{e.message}",
        parameters_used: parameters,
        count: 0,
        tokens: []
      }
    rescue => e
      {
        error: "Request failed: #{e.message}",
        parameters_used: parameters,
        count: 0,
        tokens: []
      }
    end
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
          name: "search_tokens",
          description: "Search for Ethereum tokens based on various criteria",
          parameters: {
            type: "object",
            properties: {
              name: { type: "string", description: "Token name" },
              symbol: { type: "string", description: "Token symbol" },
              address: { type: "string", description: "Token contract address" },
              type: { type: "string", description: "Token type (ERC-20, ERC-721, ERC-1155)" },
              decimals_min: { type: "integer", description: "Minimum decimals" },
              decimals_max: { type: "integer", description: "Maximum decimals" },
              holders_count_min: { type: "integer", description: "Minimum holder count" },
              holders_count_max: { type: "integer", description: "Maximum holder count" },
              total_supply_min: { type: "string", description: "Minimum total supply" },
              total_supply_max: { type: "string", description: "Maximum total supply" },
              exchange_rate_min: { type: "string", description: "Minimum exchange rate (USD)" },
              exchange_rate_max: { type: "string", description: "Maximum exchange rate (USD)" },
              volume_24h_min: { type: "string", description: "Minimum 24h volume" },
              volume_24h_max: { type: "string", description: "Maximum 24h volume" },
              circulating_market_cap_min: { type: "string", description: "Minimum circulating market cap" },
              circulating_market_cap_max: { type: "string", description: "Maximum circulating market cap" },
              transfers_count_min: { type: "integer", description: "Minimum transfer count" },
              transfers_count_max: { type: "integer", description: "Maximum transfer count" },
              icon_url: { type: "string", description: "Token icon URL" },
              from_address: { type: "string", description: "Transfer from address" },
              to_address: { type: "string", description: "Transfer to address" },
              from_name: { type: "string", description: "Transfer from address name" },
              to_name: { type: "string", description: "Transfer to address name" },
              from_is_contract: { type: "boolean", description: "Transfer from address is contract" },
              to_is_contract: { type: "boolean", description: "Transfer to address is contract" },
              from_is_verified: { type: "boolean", description: "Transfer from address is verified" },
              to_is_verified: { type: "boolean", description: "Transfer to address is verified" },
              from_is_scam: { type: "boolean", description: "Transfer from address is scam" },
              to_is_scam: { type: "boolean", description: "Transfer to address is scam" },
              transfer_value_min: { type: "string", description: "Minimum transfer value" },
              transfer_value_max: { type: "string", description: "Maximum transfer value" },
              transfer_block_number_min: { type: "integer", description: "Minimum transfer block number" },
              transfer_block_number_max: { type: "integer", description: "Maximum transfer block number" },
              transfer_timestamp_min: { type: "string", description: "Minimum transfer timestamp" },
              transfer_timestamp_max: { type: "string", description: "Maximum transfer timestamp" },
              transfer_method: { type: "string", description: "Transfer method" },
              transfer_log_index_min: { type: "integer", description: "Minimum transfer log index" },
              transfer_log_index_max: { type: "integer", description: "Maximum transfer log index" },
              limit: { type: "integer", description: "Number of results to return (default: 10, max: 50)" },
              sort_by: { type: "string", description: "Field to sort by (e.g., holders_count, volume_24h, circulating_market_cap, transfers_count, etc.)" },
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
    tool_calls = parsed_response.dig("choices", 0, "message", "tool_calls")
    
    if tool_calls.nil?
      raise InvalidQueryError, "No tool calls found in response"
    end
    
    tool_calls.to_json
  end
end