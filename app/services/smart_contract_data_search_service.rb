require 'net/http'
require 'uri'
require 'json'
require 'openssl'
require 'cgi'

class SmartContractDataSearchService < BaseService
  class ApiError < StandardError; end
  class InvalidQueryError < StandardError; end

  def initialize(query, full_json: false)
    @query = query
    @api_url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
    @api_key = Rails.application.credentials.gemini_api_key
    @base_url = Rails.env.production? ? 'https://chainfetch.app' : 'http://localhost:3000'
    @full_json = full_json
  end

  def call
    tool_call_response = generate_tool_call(@query)
    execute_smart_contract_search_with_params(tool_call_response)
  rescue Net::HTTPError, SocketError, Errno::ECONNREFUSED => e
    raise ApiError, "AI service unavailable: #{e.message}"
  rescue => e
    Rails.logger.error "Unexpected error: #{e.message}"
    raise e
  end

  private

  def execute_smart_contract_search_with_params(parameters)
    # Execute the smart contract search with extracted parameters
    if @full_json
      results = execute_api_request(parameters)
    else
      results = execute_smart_contract_search(parameters)
      
      # Build the full API endpoint with parameters
      base_endpoint = "#{@base_url}/api/v1/ethereum/smart-contracts/json_search"
      api_endpoint = if parameters&.any?
        query_string = parameters.map { |k, v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}" }.join("&")
        "#{base_endpoint}?#{query_string}"
      else
        base_endpoint
      end
      
      results = {
        count: results.length,
        parameters_used: parameters,
        api_endpoint: api_endpoint,
        addresses: results
      }
    end
    
    results
  end

  def generate_tool_call(user_query)
    system_prompt = <<~PROMPT
      Your task is to call the search_smart_contracts tool with the appropriate parameters to fulfill the user's request.
      
      Analyze the user's query and call the search_smart_contracts tool with the appropriate parameters to fulfill their request.
      
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
      - "by verification date" → sort_by: "verification_date", sort_order: "desc"
      - "by balance", "richest contracts" → sort_by: "eth_balance", sort_order: "desc"
      - "by transaction count" → sort_by: "transaction_count", sort_order: "desc"
      - "by bytecode size" → sort_by: "deployed_bytecode_size", sort_order: "desc"
      - "by source code size" → sort_by: "source_code_size", sort_order: "desc"
      - "by optimization runs" → sort_by: "optimization_runs", sort_order: "desc"
      
      Parameter mapping guide for smart contracts:
      - Contract verification → is_verified, is_fully_verified, verified_at_min/max
      - Contract types → proxy_type (e.g., "eip1967"), language (e.g., "solidity")
      - Compiler info → compiler_version, optimization_enabled, optimization_runs_min/max
      - Verification sources → is_verified_via_sourcify, is_verified_via_eth_bytecode_db
      - Code analysis → source_code_size_min/max, source_code_lines_min/max
      - Bytecode → creation_bytecode_size_min/max, deployed_bytecode_size_min/max
      - ABI functions → abi_function_count_min/max, abi_event_count_min/max
      - Proxy contracts → has_implementations, implementation_address, implementation_name
      - Libraries → has_external_libraries, library_count_min/max
      - Constructor → has_constructor_args, has_decoded_constructor_args
      - Contract status → status ("success"), is_self_destructed, is_blueprint
      - License → license_type (e.g., "MIT", "GPL", "none")
      - Security → is_scam, certified
      - ETH amounts → eth_balance_min/max (in ETH units like "1.5")
      - WEI amounts → coin_balance_min/max (in WEI like "1500000000000000000")
      - Activity → transactions_count_min/max, token_transfers_count_min/max
      - Features → has_logs, has_token_transfers, has_tokens
      - Names → name (contract name), ens_domain_name
      - Result limits → limit (default: 10, max: 50)
      - Sorting → sort_by (field name), sort_order ("asc" or "desc", default: "desc")
      
      Examples of correct tool calls:
      - "verified smart contracts" → search_smart_contracts({"is_verified": true})
      - "proxy contracts using EIP1967" → search_smart_contracts({"proxy_type": "eip1967"})
      - "Solidity contracts with more than 1000 optimization runs" → search_smart_contracts({"language": "solidity", "optimization_runs_min": 1000})
      - "contracts verified via Sourcify" → search_smart_contracts({"is_verified_via_sourcify": true})
      - "large smart contracts with more than 10000 bytes of source code" → search_smart_contracts({"source_code_size_min": 10000})
      - "contracts with more than 50 ABI functions" → search_smart_contracts({"abi_function_count_min": 50})
      - "self-destructed contracts" → search_smart_contracts({"is_self_destructed": true})
      - "contracts with external libraries" → search_smart_contracts({"has_external_libraries": true})
      - "newest verified contracts" → search_smart_contracts({"is_verified": true, "sort_by": "verification_date", "sort_order": "desc"})
      - "richest smart contracts" → search_smart_contracts({"sort_by": "eth_balance", "sort_order": "desc"})

      Set the limit to 10 if not specified.
      
      Always call the search_smart_contracts tool with the parameters that best match the user's intent.
    PROMPT

    user_prompt = "Find smart contracts that match this query: #{user_query}"

    response = make_gemini_request(system_prompt, user_prompt)
    parse_tool_call_response(response)
  end

  def parse_tool_call_response(response)
    parsed_response = JSON.parse(response)
    
    # Gemini response structure: candidates[0].content.parts[0].functionCall
    function_call = parsed_response.dig("candidates", 0, "content", "parts", 0, "functionCall")
    
    if function_call&.dig("name") == "search_smart_contracts"
      return function_call.dig("args") || {}
    else
      raise InvalidQueryError, "No valid tool call found in response"
    end
  rescue JSON::ParserError => e
    raise InvalidQueryError, "Invalid JSON response from AI: #{e.message}"
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
            name: "search_smart_contracts",
            description: "Search for smart contracts using various parameters",
            parameters: {
              type: "object",
              properties: {
                is_verified: { type: "boolean", description: "Whether the contract is verified" },
                is_self_destructed: { type: "boolean", description: "Whether the contract is self-destructed" },
                optimization_enabled: { type: "boolean", description: "Whether optimization is enabled" },
                is_fully_verified: { type: "boolean", description: "Whether the contract is fully verified" },
                is_verified_via_sourcify: { type: "boolean", description: "Whether verified via sourcify" },
                certified: { type: "boolean", description: "Whether the contract is certified" },
                has_external_libraries: { type: "boolean", description: "Whether has external libraries" },
                has_implementations: { type: "boolean", description: "Whether has implementations" },
                proxy_type: { type: "string", description: "Proxy type (e.g., 'eip1967')" },
                language: { type: "string", description: "Programming language (e.g., 'solidity')" },
                compiler_version: { type: "string", description: "Compiler version" },
                license_type: { type: "string", description: "License type" },
                name: { type: "string", description: "Contract name" },
                optimization_runs_min: { type: "integer", description: "Minimum optimization runs" },
                optimization_runs_max: { type: "integer", description: "Maximum optimization runs" },
                abi_function_count_min: { type: "integer", description: "Minimum ABI function count" },
                abi_function_count_max: { type: "integer", description: "Maximum ABI function count" },
                source_code_size_min: { type: "integer", description: "Minimum source code size" },
                source_code_size_max: { type: "integer", description: "Maximum source code size" },
                deployed_bytecode_size_min: { type: "integer", description: "Minimum deployed bytecode size" },
                deployed_bytecode_size_max: { type: "integer", description: "Maximum deployed bytecode size" },
                eth_balance_min: { type: "string", description: "Minimum ETH balance (in ETH units like '1.5')" },
                eth_balance_max: { type: "string", description: "Maximum ETH balance (in ETH units like '1.5')" },
                transactions_count_min: { type: "integer", description: "Minimum transaction count" },
                transactions_count_max: { type: "integer", description: "Maximum transaction count" },
                has_logs: { type: "boolean", description: "Whether has logs" },
                has_token_transfers: { type: "boolean", description: "Whether has token transfers" },
                has_tokens: { type: "boolean", description: "Whether has tokens" },
                is_scam: { type: "boolean", description: "Whether flagged as scam" },
                limit: { type: "integer", description: "Number of results to return (default: 10, max: 50)" },
                offset: { type: "integer", description: "Number of results to skip for pagination (default: 0)" },
                page: { type: "integer", description: "Page number (alternative to offset, starts at 1)" },
                sort_by: { type: "string", description: "Field to sort by (default: 'id')" },
                sort_order: { type: "string", description: "Sort direction: 'asc' or 'desc' (default: 'desc')" }
              },
              required: [],
                          }
          }]
        }]
      }.to_json

      http.request(request)
    end.value
    
    raise ApiError, "API error: #{response.code}" unless response.code == '200'
    
    response.body
  end

  def extract_search_params(tool_call_args)
    # Parse the JSON string if it's a string, otherwise use as-is
    params = tool_call_args.is_a?(String) ? JSON.parse(tool_call_args) : tool_call_args
    
    # Convert string values to appropriate types
    params.each do |key, value|
      case key
      when /_(min|max)$/
        # Convert numeric range parameters
        if key.match?(/(count|runs|size|lines)_(min|max)$/)
          params[key] = value.to_i if value.present?
        elsif key.match?(/(balance|rate)_(min|max)$/)
          params[key] = value.to_s if value.present?
        end
      when 'limit', 'offset', 'page'
        params[key] = value.to_i if value.present?
      when /^(is_|has_|certified|optimization_enabled)/
        params[key] = value.to_s.downcase == 'true' if value.present?
      end
    end
    
    params
  end

  def execute_smart_contract_search(params)
    # Start with contracts only
    contracts = EthereumAddress.where("data->'info'->>'is_contract' = 'true'")
    
    # Apply all the filters based on params
    params.each do |key, value|
      next if value.blank?
      
      case key.to_s
      # Contract-specific boolean fields
      when 'is_self_destructed'
        contracts = contracts.where("data->'smart_contract'->>'is_self_destructed' = ?", value.to_s)
      when 'is_verified'
        contracts = contracts.where("data->'smart_contract'->>'is_verified' = ?", value.to_s)
      when 'optimization_enabled'
        contracts = contracts.where("data->'smart_contract'->>'optimization_enabled' = ?", value.to_s)
      when 'is_verified_via_verifier_alliance'
        contracts = contracts.where("data->'smart_contract'->>'is_verified_via_verifier_alliance' = ?", value.to_s)
      when 'is_blueprint'
        contracts = contracts.where("data->'smart_contract'->>'is_blueprint' = ?", value.to_s)
      when 'is_fully_verified'
        contracts = contracts.where("data->'smart_contract'->>'is_fully_verified' = ?", value.to_s)
      when 'is_verified_via_eth_bytecode_db'
        contracts = contracts.where("data->'smart_contract'->>'is_verified_via_eth_bytecode_db' = ?", value.to_s)
      when 'can_be_visualized_via_sol2uml'
        contracts = contracts.where("data->'smart_contract'->>'can_be_visualized_via_sol2uml' = ?", value.to_s)
      when 'is_verified_via_sourcify'
        contracts = contracts.where("data->'smart_contract'->>'is_verified_via_sourcify' = ?", value.to_s)
      when 'certified'
        contracts = contracts.where("data->'smart_contract'->>'certified' = ?", value.to_s)
      when 'is_changed_bytecode'
        contracts = contracts.where("data->'smart_contract'->>'is_changed_bytecode' = ?", value.to_s)
      when 'is_partially_verified'
        contracts = contracts.where("data->'smart_contract'->>'is_partially_verified' = ?", value.to_s)
        
      # Contract-specific string fields
      when 'file_path'
        contracts = contracts.where("data->'smart_contract'->>'file_path' = ?", value)
      when 'verified_twin_address_hash'
        contracts = contracts.where("data->'smart_contract'->>'verified_twin_address_hash' = ?", value)
      when 'proxy_type'
        contracts = contracts.where("data->'smart_contract'->>'proxy_type' = ?", value)
      when 'status'
        contracts = contracts.where("data->'smart_contract'->>'status' = ?", value)
      when 'name'
        contracts = contracts.where("data->'smart_contract'->>'name' = ?", value)
      when 'license_type'
        contracts = contracts.where("data->'smart_contract'->>'license_type' = ?", value)
      when 'language'
        contracts = contracts.where("data->'smart_contract'->>'language' = ?", value)
      when 'evm_version'
        contracts = contracts.where("data->'smart_contract'->>'evm_version' = ?", value)
      when 'compiler_version'
        contracts = contracts.where("data->'smart_contract'->>'compiler_version' = ?", value)
        
      # Date range filters
      when 'verified_at_min'
        contracts = contracts.where("data->'smart_contract'->>'verified_at' >= ?", value)
      when 'verified_at_max'
        contracts = contracts.where("data->'smart_contract'->>'verified_at' <= ?", value)
        
      # Numeric range filters
      when 'optimization_runs_min'
        contracts = contracts.where("CAST(data->'smart_contract'->>'optimization_runs' AS INTEGER) >= ?", value.to_i)
      when 'optimization_runs_max'
        contracts = contracts.where("CAST(data->'smart_contract'->>'optimization_runs' AS INTEGER) <= ?", value.to_i)
      when 'abi_function_count_min'
        contracts = contracts.where("jsonb_array_length(COALESCE(data->'smart_contract'->'abi', '[]'::jsonb)) >= ?", value.to_i)
      when 'abi_function_count_max'
        contracts = contracts.where("jsonb_array_length(COALESCE(data->'smart_contract'->'abi', '[]'::jsonb)) <= ?", value.to_i)
      when 'source_code_size_min'
        contracts = contracts.where("LENGTH(COALESCE(data->'smart_contract'->>'source_code', '')) >= ?", value.to_i)
      when 'source_code_size_max'
        contracts = contracts.where("LENGTH(COALESCE(data->'smart_contract'->>'source_code', '')) <= ?", value.to_i)
      when 'deployed_bytecode_size_min'
        contracts = contracts.where("LENGTH(COALESCE(data->'smart_contract'->>'deployed_bytecode', '')) >= ?", value.to_i * 2) # Each byte = 2 hex chars
      when 'deployed_bytecode_size_max'
        contracts = contracts.where("LENGTH(COALESCE(data->'smart_contract'->>'deployed_bytecode', '')) <= ?", value.to_i * 2)
      when 'creation_bytecode_size_min'
        contracts = contracts.where("LENGTH(COALESCE(data->'smart_contract'->>'creation_bytecode', '')) >= ?", value.to_i * 2)
      when 'creation_bytecode_size_max'
        contracts = contracts.where("LENGTH(COALESCE(data->'smart_contract'->>'creation_bytecode', '')) <= ?", value.to_i * 2)
        
      # Balance filters
      when 'eth_balance_min'
        eth_min_wei = (value.to_f * 1e18).to_s
        contracts = contracts.where("CAST(data->'info'->>'coin_balance' AS NUMERIC) >= ?", eth_min_wei)
      when 'eth_balance_max'
        eth_max_wei = (value.to_f * 1e18).to_s
        contracts = contracts.where("CAST(data->'info'->>'coin_balance' AS NUMERIC) <= ?", eth_max_wei)
      when 'coin_balance_min'
        contracts = contracts.where("CAST(data->'info'->>'coin_balance' AS NUMERIC) >= ?", value)
      when 'coin_balance_max'
        contracts = contracts.where("CAST(data->'info'->>'coin_balance' AS NUMERIC) <= ?", value)
        
      # Activity filters
      when 'transactions_count_min'
        contracts = contracts.where("CAST(data->'counters'->>'transactions_count' AS INTEGER) >= ?", value.to_i)
      when 'transactions_count_max'
        contracts = contracts.where("CAST(data->'counters'->>'transactions_count' AS INTEGER) <= ?", value.to_i)
      when 'token_transfers_count_min'
        contracts = contracts.where("CAST(data->'counters'->>'token_transfers_count' AS INTEGER) >= ?", value.to_i)
      when 'token_transfers_count_max'
        contracts = contracts.where("CAST(data->'counters'->>'token_transfers_count' AS INTEGER) <= ?", value.to_i)
        
      # Boolean features
      when 'has_logs'
        contracts = contracts.where("data->'info'->>'has_logs' = ?", value.to_s)
      when 'has_token_transfers'
        contracts = contracts.where("data->'info'->>'has_token_transfers' = ?", value.to_s)
      when 'has_tokens'
        contracts = contracts.where("data->'info'->>'has_tokens' = ?", value.to_s)
      when 'is_scam'
        contracts = contracts.where("data->'info'->>'is_scam' = ?", value.to_s)
        
      # Implementation filters
      when 'implementation_address'
        contracts = contracts.where("data->'smart_contract'->'implementations' @> ?", [{ "address" => value }].to_json)
      when 'implementation_name'
        contracts = contracts.where("data->'smart_contract'->'implementations' @> ?", [{ "name" => value }].to_json)
      when 'has_implementations'
        if value.to_s == 'true'
          contracts = contracts.where("jsonb_array_length(COALESCE(data->'smart_contract'->'implementations', '[]'::jsonb)) > 0")
        else
          contracts = contracts.where("jsonb_array_length(COALESCE(data->'smart_contract'->'implementations', '[]'::jsonb)) = 0")
        end
      when 'has_external_libraries'
        if value.to_s == 'true'
          contracts = contracts.where("jsonb_array_length(COALESCE(data->'smart_contract'->'external_libraries', '[]'::jsonb)) > 0")
        else
          contracts = contracts.where("jsonb_array_length(COALESCE(data->'smart_contract'->'external_libraries', '[]'::jsonb)) = 0")
        end
      when 'has_constructor_args'
        if value.to_s == 'true'
          contracts = contracts.where("data->'smart_contract'->'constructor_args' IS NOT NULL AND data->'smart_contract'->>'constructor_args' != ''")
        else
          contracts = contracts.where("data->'smart_contract'->'constructor_args' IS NULL OR data->'smart_contract'->>'constructor_args' = ''")
        end
        
      # Names and identifiers
      when 'ens_domain_name'
        contracts = contracts.where("data->'info'->>'ens_domain_name' = ?", value)
      end
    end
    
    # Apply sorting
    sort_by = params['sort_by'] || 'id'
    sort_order = params['sort_order']&.downcase == 'asc' ? 'asc' : 'desc'
    
    allowed_sort_fields = {
      'id' => 'ethereum_addresses.id',
      'created_at' => 'ethereum_addresses.created_at',
      'verification_date' => "data->'smart_contract'->>'verified_at'",
      'compiler_version' => "data->'smart_contract'->>'compiler_version'",
      'optimization_runs' => "CAST(data->'smart_contract'->>'optimization_runs' AS INTEGER)",
      'deployed_bytecode_size' => "LENGTH(COALESCE(data->'smart_contract'->>'deployed_bytecode', ''))",
      'source_code_size' => "LENGTH(COALESCE(data->'smart_contract'->>'source_code', ''))",
      'abi_function_count' => "jsonb_array_length(COALESCE(data->'smart_contract'->'abi', '[]'::jsonb))",
      'contract_name' => "data->'smart_contract'->>'name'",
      'eth_balance' => "CAST(data->'info'->>'coin_balance' AS NUMERIC)",
      'transaction_count' => "CAST(data->'counters'->>'transactions_count' AS INTEGER)",
      'token_transfers_count' => "CAST(data->'counters'->>'token_transfers_count' AS INTEGER)"
    }
    
    if allowed_sort_fields.key?(sort_by)
      sort_column = allowed_sort_fields[sort_by]
      if sort_column.include?("data->")
        contracts = contracts.order(Arel.sql("#{sort_column} #{sort_order} NULLS LAST"))
      else
        contracts = contracts.order(Arel.sql("#{sort_column} #{sort_order}"))
      end
    else
      contracts = contracts.order(Arel.sql("ethereum_addresses.id DESC"))
    end
    
    # Apply pagination
    limit = [params['limit']&.to_i || 10, 50].min
    offset = params['offset']&.to_i || 0
    
    # If page is specified, calculate offset from page
    if params['page'].present?
      page = [params['page'].to_i, 1].max
      offset = (page - 1) * limit
    end
    
    # Return the address hashes
    contracts.limit(limit).offset(offset).pluck(:address_hash)
  end

  def execute_api_request(parameters)
    uri = URI("#{@base_url}/api/v1/ethereum/smart-contracts/json_search")
    parameters = parameters.merge(full_json: @full_json)
    uri.query = URI.encode_www_form(parameters)
    
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
          smart_contracts: result.dig("results") || []
        }
      else
        {
          error: "API request failed with status: #{response.code}",
          response_body: response.body,
          parameters_used: parameters,
          count: 0,
          smart_contracts: []
        }
      end
    rescue Net::ReadTimeout, Net::OpenTimeout, Net::WriteTimeout => e
      retries += 1
      if retries <= max_retries
        Rails.logger.warn "Timeout on attempt #{retries}/#{max_retries} for smart contract search: #{e.message}"
        sleep(1 * retries)
        retry
      else
        Rails.logger.error "Smart contract search failed after #{max_retries} retries: #{e.message}"
        {
          error: "Request timeout after #{max_retries} retries: #{e.message}",
          parameters_used: parameters,
          count: 0,
          smart_contracts: []
        }
      end
    rescue => e
      Rails.logger.error "Smart contract search failed: #{e.message}"
      {
        error: "Request failed: #{e.message}",
        parameters_used: parameters,
        count: 0,
        smart_contracts: []
      }
    end
  end
end