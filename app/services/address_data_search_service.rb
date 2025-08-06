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
    # NOTE: coin_balance is in WEI (1 ETH = 10^18 wei)
    sample_jsonb = {
      "info" => {
        "block_number_balance_updated_at" => 23076754,
        "coin_balance" => "345285048595154", # This is in WEI! (~0.000345 ETH)
        "creation_transaction_hash" => nil,
        "creator_address_hash" => nil,
        "ens_domain_name" => nil,
        "exchange_rate" => "3588.91", # USD price per ETH
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
      "logs" => {
        "items" => [],
        "next_page_params" => nil
      },
      "blocks_validated" => {
        "items" => [],
        "next_page_params" => nil
      },
      "token_balances" => [
        {
          "token" => {
            "address" => "0x8eB24319393716668D768dCEC29356ae9CfFe285",
            "address_hash" => "0x8eB24319393716668D768dCEC29356ae9CfFe285",
            "circulating_market_cap" => nil,
            "decimals" => "8",
            "exchange_rate" => nil,
            "holders" => "26247",
            "holders_count" => "26247",
            "icon_url" => "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/0x8eB24319393716668D768dCEC29356ae9CfFe285/logo.png",
            "name" => "SingularityNET Token",
            "symbol" => "AGI",
            "total_supply" => "99993398717278375",
            "type" => "ERC-20",
            "volume_24h" => nil
          },
          "token_id" => nil,
          "token_instance" => nil,
          "value" => "55188200000"
        },
        {
          "token" => {
            "address" => "0xC31ED16220EA819e0516Fc4960ddfeCb7Ec42CAB",
            "address_hash" => "0xC31ED16220EA819e0516Fc4960ddfeCb7Ec42CAB",
            "circulating_market_cap" => nil,
            "decimals" => nil,
            "exchange_rate" => nil,
            "holders" => "13501",
            "holders_count" => "13501",
            "icon_url" => nil,
            "name" => "genesis-eth.net",
            "symbol" => "claim rewards on genesis-eth.net",
            "total_supply" => "20000",
            "type" => "ERC-1155",
            "volume_24h" => nil
          },
          "token_id" => "0",
          "token_instance" => nil,
          "value" => "1"
        }
      ],
      "tokens" => {
        "items" => [
          {
            "token" => {
              "address" => "0x8eB24319393716668D768dCEC29356ae9CfFe285",
              "address_hash" => "0x8eB24319393716668D768dCEC29356ae9CfFe285",
              "circulating_market_cap" => nil,
              "decimals" => "8",
              "exchange_rate" => nil,
              "holders" => "26247",
              "holders_count" => "26247",
              "icon_url" => "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/0x8eB24319393716668D768dCEC29356ae9CfFe285/logo.png",
              "name" => "SingularityNET Token",
              "symbol" => "AGI",
              "total_supply" => "99993398717278375",
              "type" => "ERC-20",
              "volume_24h" => nil
            },
            "token_id" => nil,
            "token_instance" => nil,
            "value" => "55188200000"
          },
          {
            "token" => {
              "address" => "0xC31ED16220EA819e0516Fc4960ddfeCb7Ec42CAB",
              "address_hash" => "0xC31ED16220EA819e0516Fc4960ddfeCb7Ec42CAB",
              "circulating_market_cap" => nil,
              "decimals" => nil,
              "exchange_rate" => nil,
              "holders" => "13501",
              "holders_count" => "13501",
              "icon_url" => nil,
              "name" => "genesis-eth.net",
              "symbol" => "claim rewards on genesis-eth.net",
              "total_supply" => "20000",
              "type" => "ERC-1155",
              "volume_24h" => nil
            },
            "token_id" => "0",
            "token_instance" => {
              "animation_url" => nil,
              "external_app_url" => nil,
              "id" => "0",
              "image_url" => "https://ipfs.io/ipfs/QmeTAazmYyHgw2TBgRjH52vSoPMkgd79YdUgqJzBu6wsnx",
              "is_unique" => nil,
              "media_type" => nil,
              "media_url" => "https://ipfs.io/ipfs/QmeTAazmYyHgw2TBgRjH52vSoPMkgd79YdUgqJzBu6wsnx",
              "metadata" => {
                "description" => "Visit genesis-eth.net to claim rewards",
                "image" => "https://ipfs.io/ipfs/QmeTAazmYyHgw2TBgRjH52vSoPMkgd79YdUgqJzBu6wsnx",
                "name" => "Visit genesis-eth.net to claim rewards"
              },
              "owner" => nil,
              "thumbnails" => nil,
              "token" => {
                "address" => "0xC31ED16220EA819e0516Fc4960ddfeCb7Ec42CAB",
                "address_hash" => "0xC31ED16220EA819e0516Fc4960ddfeCb7Ec42CAB",
                "circulating_market_cap" => nil,
                "decimals" => nil,
                "exchange_rate" => nil,
                "holders" => "13501",
                "holders_count" => "13501",
                "icon_url" => nil,
                "name" => "genesis-eth.net",
                "symbol" => "claim rewards on genesis-eth.net",
                "total_supply" => "20000",
                "type" => "ERC-1155",
                "volume_24h" => nil
              }
            },
            "value" => "1"
          }
        ],
        "next_page_params" => nil
      },
      "withdrawals" => {
        "items" => [],
        "next_page_params" => nil
      },
      "nft" => {
        "items" => [
          {
            "animation_url" => nil,
            "external_app_url" => nil,
            "id" => "0",
            "image_url" => "https://ipfs.io/ipfs/QmeTAazmYyHgw2TBgRjH52vSoPMkgd79YdUgqJzBu6wsnx",
            "is_unique" => nil,
            "media_type" => nil,
            "media_url" => "https://ipfs.io/ipfs/QmeTAazmYyHgw2TBgRjH52vSoPMkgd79YdUgqJzBu6wsnx",
            "metadata" => {
              "description" => "Visit genesis-eth.net to claim rewards",
              "image" => "https://ipfs.io/ipfs/QmeTAazmYyHgw2TBgRjH52vSoPMkgd79YdUgqJzBu6wsnx",
              "name" => "Visit genesis-eth.net to claim rewards"
            },
            "owner" => nil,
            "thumbnails" => nil,
            "token" => {
              "address" => "0xC31ED16220EA819e0516Fc4960ddfeCb7Ec42CAB",
              "address_hash" => "0xC31ED16220EA819e0516Fc4960ddfeCb7Ec42CAB",
              "circulating_market_cap" => nil,
              "decimals" => nil,
              "exchange_rate" => nil,
              "holders" => "13501",
              "holders_count" => "13501",
              "icon_url" => nil,
              "name" => "genesis-eth.net",
              "symbol" => "claim rewards on genesis-eth.net",
              "total_supply" => "20000",
              "type" => "ERC-1155",
              "volume_24h" => nil
            },
            "token_type" => "ERC-1155",
            "value" => "1"
          }
        ],
        "next_page_params" => nil
      },
      "nft_collections" => {
        "items" => [
          {
            "amount" => "1",
            "token" => {
              "address" => "0xC31ED16220EA819e0516Fc4960ddfeCb7Ec42CAB",
              "address_hash" => "0xC31ED16220EA819e0516Fc4960ddfeCb7Ec42CAB",
              "circulating_market_cap" => nil,
              "decimals" => nil,
              "exchange_rate" => nil,
              "holders" => "13501",
              "holders_count" => "13501",
              "icon_url" => nil,
              "name" => "genesis-eth.net",
              "symbol" => "claim rewards on genesis-eth.net",
              "total_supply" => "20000",
              "type" => "ERC-1155",
              "volume_24h" => nil
            },
            "token_instances" => [
              {
                "animation_url" => nil,
                "external_app_url" => nil,
                "id" => "0",
                "image_url" => "https://ipfs.io/ipfs/QmeTAazmYyHgw2TBgRjH52vSoPMkgd79YdUgqJzBu6wsnx",
                "is_unique" => nil,
                "media_type" => nil,
                "media_url" => "https://ipfs.io/ipfs/QmeTAazmYyHgw2TBgRjH52vSoPMkgd79YdUgqJzBu6wsnx",
                "metadata" => {
                  "description" => "Visit genesis-eth.net to claim rewards",
                  "image" => "https://ipfs.io/ipfs/QmeTAazmYyHgw2TBgRjH52vSoPMkgd79YdUgqJzBu6wsnx",
                  "name" => "Visit genesis-eth.net to claim rewards"
                },
                "owner" => nil,
                "thumbnails" => nil,
                "token" => nil,
                "token_type" => "ERC-1155",
                "value" => "1"
              }
            ]
          }
        ],
        "next_page_params" => nil
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

      IMPORTANT: BALANCE UNITS
      - coin_balance is stored in WEI (smallest unit of ETH)
      - 1 ETH = 1,000,000,000,000,000,000 wei (10^18)
      - 1 Gwei = 1,000,000,000 wei (10^9)
      
      For balance queries, you MUST convert ETH amounts to wei:
      - "1 ETH" = "1000000000000000000" wei
      - "0.1 ETH" = "100000000000000000" wei
      - "10 ETH" = "10000000000000000000" wei

      Generate ActiveRecord where conditions using JSONB operators as strings:
      - "data -> 'key'" for accessing JSON object keys
      - "data ->> 'key'" for getting text values  
      - "data @> ?" for containment with parameters
      - "data ? 'key'" for key existence
      - "CAST(data -> 'info' ->> 'coin_balance' AS NUMERIC) > ?" for balance comparisons (remember: coin_balance is in wei!)
      
      For ORDER BY clauses, provide the order string separately:
      - "CAST(data -> 'info' ->> 'coin_balance' AS NUMERIC) DESC" for balance descending
      - "CAST(data -> 'info' ->> 'coin_balance' AS NUMERIC) ASC" for balance ascending
      - "data ->> 'address_hash'" for alphabetical ordering
      
      For ordering-only queries (no specific filtering), use a basic condition like:
      - "data -> 'info' ->> 'coin_balance' IS NOT NULL" to get addresses with balance data
      - "data -> 'info' ->> 'hash' IS NOT NULL" to get valid addresses
      
      IMPORTANT: Never generate empty conditions as this would query all addresses (millions of records).
      Always include some basic filtering condition.
      
      For LIMIT clauses, specify the number of records to return:
      - For "top 10" queries, use limit: 10
      - For "first 100" queries, use limit: 100
      - Default limit is 1000 if not specified to prevent large result sets
      
      Return conditions that can be used with Address.where(condition, *params).order(order_clause).limit(limit)
      Use the generate_query_conditions function to return your response.
      PROMPT

    user_prompt = <<~PROMPT
      Based on this sample JSONB structure: #{sample_jsonb.to_json}

      Generate ActiveRecord where conditions for: "#{user_query}"

      Use the generate_query_conditions function to provide the where condition string and any parameters needed.
      PROMPT

    response = @client.messages.create(
      model: "claude-sonnet-4-20250514",
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
                description: "ActiveRecord where condition string using JSONB operators (can be empty for ordering-only queries)"
              },
              parameters: {
                type: "array",
                description: "Array of parameters to bind to the condition (if any)",
                items: {
                  type: ["string", "number", "boolean", "object"]
                }
              },
              order_clause: {
                type: "string",
                description: "ActiveRecord order clause string (e.g., 'CAST(data -> 'info' ->> 'coin_balance' AS NUMERIC) DESC')"
              },
              limit: {
                type: "integer",
                description: "Number of records to return (default: 1000)"
              },
              explanation: {
                type: "string", 
                description: "Brief explanation of what the condition searches for"
              }
            },
            required: ["condition", "parameters", "order_clause", "explanation"]
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
    order_clause = function_result["order_clause"] || function_result[:order_clause]
    limit = function_result["limit"] || function_result[:limit] || 1000 # Default to 1000
    explanation = function_result["explanation"] || function_result[:explanation]

    if condition.blank?
      raise InvalidQueryError, "No query condition generated"
    end

    # Validate that condition only contains safe read operations
    validate_safe_condition(condition)

    Rails.logger.info "Generated condition: #{condition}"
    Rails.logger.info "Parameters: #{parameters.inspect}"
    Rails.logger.info "Query explanation: #{explanation}"

    { condition: condition, parameters: parameters, order_clause: order_clause, limit: limit }
  end

  def validate_safe_condition(condition)
    # Ensure the condition only contains safe read operations
    dangerous_keywords = %w[INSERT UPDATE DELETE DROP CREATE ALTER GRANT REVOKE TRUNCATE EXECUTE]
    
    dangerous_keywords.each do |keyword|
      if condition.upcase.include?(keyword)
        raise SecurityError, "Unsafe operation detected: #{keyword}. Only read operations are allowed."
      end
    end

    # Always require a condition to prevent querying all records
    if condition.blank?
      raise SecurityError, "Condition cannot be empty. Use a basic filter like 'data -> 'info' ->> 'hash' IS NOT NULL' for ordering-only queries."
    end

    # Additional validation: ensure it's working with the data column
    unless condition.include?('data')
      raise SecurityError, "Invalid condition: must query the 'data' JSONB column"
    end
  end

  def execute_safe_query(query_conditions)
    condition = query_conditions[:condition]
    parameters = query_conditions[:parameters]
    order_clause = query_conditions[:order_clause]
    limit = query_conditions[:limit]
    
    # Convert hash parameters to JSON strings for JSONB queries
    processed_parameters = parameters.map do |param|
      if param.is_a?(Hash)
        param.to_json
      else
        param
      end
    end
    
    # Build the query relation (condition is always required now)
    addresses_relation = if processed_parameters.any?
      Address.where(condition, *processed_parameters)
    else
      Address.where(condition)
    end

    # Add order clause if provided
    if order_clause.present?
      addresses_relation = addresses_relation.order(Arel.sql(order_clause))
    end

    # Add limit if provided
    if limit.present?
      addresses_relation = addresses_relation.limit(limit)
    end
    
    # Capture the generated SQL query
    generated_sql = addresses_relation.to_sql
    
    # Execute the query safely using ActiveRecord where clauses  
    addresses_result = addresses_relation.to_a
    
    {
      count: addresses_result.count,
      sql_query: generated_sql,
      addresses: addresses_result.map do |address|
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