require 'anthropic'
require 'json'

class AddressDataSearchService
  # Error classes for better error handling
  class ApiError < StandardError; end
  class InvalidQueryError < StandardError; end
  class DatabaseError < StandardError; end
  class SecurityError < StandardError; end

  def initialize(query)
    @query = query
    @client = Anthropic::Client.new(api_key: Rails.application.credentials.anthropic_api_key)
  end

  def call
    # Use Claude 4 with function calling to generate safe query conditions
    query_conditions = generate_query_conditions(@query)
    
    # Execute the query safely using ActiveRecord where clauses
    execute_safe_query(query_conditions)
  rescue Anthropic::APIErrorObject, Anthropic::InvalidRequestError, Anthropic::AuthenticationError => e
    Rails.logger.error "Claude API error: #{e.message}"
    raise ApiError, "AI service unavailable: #{e.message}"
  rescue SecurityError => e
    Rails.logger.error "Security violation: #{e.message}"
    raise e
  rescue DatabaseError => e
    Rails.logger.error "Database error: #{e.message}"
    raise e
  rescue => e
    Rails.logger.error "Unexpected error in AddressDataSearchService: #{e.message}"
    raise e
  end

  private

  def generate_query_conditions(user_query)
    # Sample JSONB structure to provide context
    sample_jsonb = {
      "info" => {
        "block_number_balance_updated_at" => 23066996,
        "coin_balance" => "345285048595154",
        "creation_transaction_hash" => nil,
        "creator_address_hash" => nil,
        "ens_domain_name" => nil,
        "exchange_rate" => "3548.64",
        "has_beacon_chain_withdrawals" => false,
        "has_logs" => false,
        "has_token_transfers" => true,
        "has_tokens" => true,
        "has_validated_blocks" => false,
        "hash" => "0xb71630a6995Bc76283d3010697D0b7833181D910",
        "implementations" => [],
        "is_contract" => false,
        "is_scam" => false,
        "is_verified" => false,
        "metadata" => nil,
        "name" => nil,
        "private_tags" => [],
        "proxy_type" => nil,
        "public_tags" => [],
        "token" => nil,
        "watchlist_address_id" => nil,
        "watchlist_names" => []
      },
      "counters" => {
        "transactions_count" => "29",
        "gas_usage_count" => "887617", 
        "token_transfers_count" => "13",
        "validations_count" => "0"
      },
      "transactions" => {
        "items" => [
          {
            "priority_fee" => "26250000000000",
            "hash" => "0x18716cdff9964bd904ca553d857d6ccaa5994776fd2575d421938a4b881c15dd",
            "value" => "199000000000000000",
            "from" => {
              "hash" => "0xb71630a6995Bc76283d3010697D0b7833181D910"
            },
            "to" => {
              "hash" => "0xA58F1C42FAE774EA8974dbf0Fc8AFAb22bc710bA"
            },
            "gas_used" => "21000",
            "gas_price" => "1958834765",
            "block_number" => 22602298,
            "timestamp" => "2025-05-31T11:05:35.000000Z"
          }
        ]
      },
      "token_transfers" => {
        "items" => [
          {
            "block_number" => 22154359,
            "from" => {
              "hash" => "0xD8d98eE915A5A4f52C40D97fCD8ffaDEa1eE8604"
            },
            "to" => {
              "hash" => "0xb71630a6995Bc76283d3010697D0b7833181D910"
            },
            "token" => {
              "address" => "0xC31ED16220EA819e0516Fc4960ddfeCb7Ec42CAB",
              "name" => "genesis-eth.net",
              "symbol" => "claim rewards on genesis-eth.net",
              "type" => "ERC-1155"
            }
          }
        ]
      },
      "tokens" => {
        "items" => [
          {
            "token" => {
              "address" => "0x8eB24319393716668D768dCEC29356ae9CfFe285",
              "name" => "SingularityNET Token",
              "symbol" => "AGI",
              "type" => "ERC-20"
            },
            "value" => "55188200000"
          }
        ]
      }
    }

    # Create the prompt for Claude
    system_prompt = <<~PROMPT
      You are an expert in ActiveRecord and PostgreSQL JSONB queries for blockchain address data.
      You will generate safe ActiveRecord where conditions to search the 'addresses' table which has:
      - id (primary key)
      - address_hash (string, indexed)  
      - data (jsonb column with GIN index, contains address information)
      - created_at, updated_at (timestamps)

      The JSONB data structure contains blockchain address information with nested objects for:
      - info: basic address info (hash, balance, contract status, etc.)
      - counters: transaction counts and statistics
      - transactions: array of transaction objects
      - token_transfers: array of token transfer objects  
      - tokens: array of token balance objects
      - And other blockchain-related data

      Generate ActiveRecord where conditions using JSONB operators as strings:
      - "data -> 'key'" for accessing JSON object keys
      - "data ->> 'key'" for getting text values  
      - "data @> ?" for containment with parameters
      - "data ? 'key'" for key existence
      - "CAST(data ->> 'path' AS INTEGER) > ?" for numeric comparisons
      
      Return conditions that can be used directly with Address.where(condition, *params)
      Use the generate_query_conditions function to return your response.
      PROMPT

    user_prompt = <<~PROMPT
      Based on this sample JSONB structure: #{sample_jsonb.to_json}

      Generate ActiveRecord where conditions for: "#{user_query}"

      Use the generate_query_conditions function to provide the where condition string and any parameters needed.
      PROMPT

    response = @client.messages.create(
      model: "claude-opus-4-1-20250805",
      max_tokens: 1000,
      system: system_prompt,
      messages: [
        {
          role: "user", 
          content: user_prompt
        }
      ],
      tools: [
        {
          name: "generate_query_conditions",
          description: "Generate ActiveRecord where conditions to search address data stored in JSONB format",
          input_schema: {
            type: "object",
            properties: {
              condition: {
                type: "string",
                description: "ActiveRecord where condition string using JSONB operators"
              },
              parameters: {
                type: "array",
                description: "Array of parameters to bind to the condition (if any)",
                items: {
                  type: ["string", "number", "boolean", "object"]
                }
              },
              explanation: {
                type: "string", 
                description: "Brief explanation of what the condition searches for"
              }
            },
            required: ["condition", "parameters", "explanation"]
          }
        }
      ],
      tool_choice: { type: "tool", name: "generate_query_conditions" }
    )

    # Extract the function call result
    tool_use = response.content.find { |c| c.type == :tool_use }
    
    if tool_use.nil?
      raise InvalidQueryError, "Claude did not generate valid query conditions"
    end

    function_result = tool_use.input
    condition = function_result["condition"] || function_result[:condition]
    parameters = function_result["parameters"] || function_result[:parameters] || []
    explanation = function_result["explanation"] || function_result[:explanation]

    if condition.blank?
      raise InvalidQueryError, "No query condition generated"
    end

    # Validate that condition only contains safe read operations
    validate_safe_condition(condition)

    Rails.logger.info "Generated condition: #{condition}"
    Rails.logger.info "Parameters: #{parameters.inspect}"
    Rails.logger.info "Query explanation: #{explanation}"

    { condition: condition, parameters: parameters }
  end

  def validate_safe_condition(condition)
    # Ensure the condition only contains safe read operations
    dangerous_keywords = %w[INSERT UPDATE DELETE DROP CREATE ALTER GRANT REVOKE TRUNCATE EXECUTE]
    
    dangerous_keywords.each do |keyword|
      if condition.upcase.include?(keyword)
        raise SecurityError, "Unsafe operation detected: #{keyword}. Only read operations are allowed."
      end
    end

    # Additional validation: ensure it's working with the data column
    unless condition.include?('data')
      raise SecurityError, "Invalid condition: must query the 'data' JSONB column"
    end
  end

  def execute_safe_query(query_conditions)
    condition = query_conditions[:condition]
    parameters = query_conditions[:parameters]
    
    # Convert hash parameters to JSON strings for JSONB queries
    processed_parameters = parameters.map do |param|
      if param.is_a?(Hash)
        param.to_json
      else
        param
      end
    end
    
    # Execute the query safely using ActiveRecord where clauses  
    addresses = if processed_parameters.any?
      Address.where(condition, *processed_parameters)
    else
      Address.where(condition)
    end
    
    {
      count: addresses.count,
      addresses: addresses.map do |address|
        {
          id: address.id,
          address_hash: address.address_hash,
          data: address.data,
          created_at: address.created_at,
          updated_at: address.updated_at
        }
      end
    }
  rescue ActiveRecord::StatementInvalid => e
    # Log the error and raise a more user-friendly message
    Rails.logger.error "Query execution failed: #{e.message}"
    Rails.logger.error "Condition was: #{condition}"
    Rails.logger.error "Parameters were: #{processed_parameters.inspect}"
    raise DatabaseError, "Invalid query conditions or database error"
  end
end