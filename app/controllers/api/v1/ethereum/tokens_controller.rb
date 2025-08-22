class Api::V1::Ethereum::TokensController < Api::V1::Ethereum::BaseController

  # @summary Get token information
  # @parameter token(path) [!String] The token address or symbol
  # @response success(200) [Hash{info: Hash, transfers: Hash, holders: Hash, counters: Hash, instances: Hash}]
  def show
    token = params[:token]
    Async do
      tasks = {
        info: Async { get_token_info(token) },
        transfers: Async { get_token_transfers(token) },
        holders: Async { get_token_holders(token) },
        counters: Async { get_token_counters(token) },
        instances: Async { get_token_instances(token) }
      }
      render json: tasks.transform_values(&:wait)
    end
  end

  # @summary LLM Search for tokens
  # @parameter query(query) [!String] The query to search for
  # @response success(200) [Hash{results: String}]
  # This endpoint leverages gemini-2.5-flash model to analyze and select the most suitable parameters from available token options
  def llm_search
    query = params[:query]
    response = TokenDataSearchService.new(query).call
    render json: response
  end

  # @summary Token Summary
  # @parameter token_address(query) [!String] The token address hash to search for
  # @response success(200) [Hash{summary: String}]
  def token_summary
    token_address = params[:token_address]
    token_data = Ethereum::TokenDataService.new(token_address).call
    summary = Ethereum::TokenSummaryService.new(token_data).call
    render json: { summary: summary }
  end

  # @summary Semantic Search for tokens
  # @parameter query(query) [!String] The query to search for
  # @parameter limit(query) [!Integer] The number of results to return (default: 10)
  # @response success(200) [Hash{result: Hash{points: Array<Hash{id: Integer, version: Integer, score: Float, payload: Hash{token_summary: String}}}>}}]
  # This endpoint queries Qdrant to search for tokens based on the provided input. Token summaries are embedded using gemini-embedding-001 and stored in Qdrant's 'tokens' collection.
  def semantic_search
    query = params[:query]
    limit = params[:limit] || 10
    embedding = Embedding::GeminiService.new(query).embed_query
    qdrant_objects = QdrantService.new.query_points(collection: "tokens", query: embedding, limit: limit)
    render json: qdrant_objects
  end

  # @summary JSON Search for tokens
  # @parameter name(query) [String] Token name
  # @parameter symbol(query) [String] Token symbol
  # @parameter address(query) [String] Token contract address
  # @parameter type(query) [String] Token type (ERC-20, ERC-721, ERC-1155)
  # @parameter decimals_min(query) [Integer] Minimum decimals
  # @parameter decimals_max(query) [Integer] Maximum decimals
  # @parameter holders_count_min(query) [Integer] Minimum holder count
  # @parameter holders_count_max(query) [Integer] Maximum holder count
  # @parameter total_supply_min(query) [String] Minimum total supply
  # @parameter total_supply_max(query) [String] Maximum total supply
  # @parameter exchange_rate_min(query) [String] Minimum exchange rate (USD)
  # @parameter exchange_rate_max(query) [String] Maximum exchange rate (USD)
  # @parameter volume_24h_min(query) [String] Minimum 24h volume
  # @parameter volume_24h_max(query) [String] Maximum 24h volume
  # @parameter circulating_market_cap_min(query) [String] Minimum circulating market cap
  # @parameter circulating_market_cap_max(query) [String] Maximum circulating market cap
  # @parameter icon_url(query) [String] Token icon URL
  # @parameter limit(query) [Integer] Number of results to return (default: 10, max: 50)
  # @parameter offset(query) [Integer] Number of results to skip for pagination (default: 0)
  # @parameter page(query) [Integer] Page number (alternative to offset, starts at 1)
  # @parameter sort_by(query) [String] Field to sort by (default: "id")
  # @parameter sort_order(query) [String] Sort direction: "asc" or "desc" (default: "desc")
  # @response success(200) [Hash{results: Array<Hash{id: Integer, address_hash: String, data: Hash}>, pagination: Hash{total: Integer, limit: Integer, offset: Integer, page: Integer, total_pages: Integer}}]
  # This endpoint provides comprehensive search parameters for tokens based on the provided input.
  def json_search
    tokens = EthereumToken.where(nil)
    
    # Basic info fields - String exact matches
    tokens = tokens.where("data->'info'->>'name' = ?", params[:name]) if params[:name].present?
    tokens = tokens.where("data->'info'->>'symbol' = ?", params[:symbol]) if params[:symbol].present?
    tokens = tokens.where("data->'info'->>'address' = ?", params[:address]) if params[:address].present?
    tokens = tokens.where("data->'info'->>'address_hash' = ?", params[:address]) if params[:address].present?
    tokens = tokens.where("data->'info'->>'type' = ?", params[:type]) if params[:type].present?
    tokens = tokens.where("data->'info'->>'icon_url' = ?", params[:icon_url]) if params[:icon_url].present?
    
    # Numeric fields with min/max ranges
    tokens = tokens.where("CAST(data->'info'->>'decimals' AS INTEGER) >= ?", params[:decimals_min].to_i) if params[:decimals_min].present?
    tokens = tokens.where("CAST(data->'info'->>'decimals' AS INTEGER) <= ?", params[:decimals_max].to_i) if params[:decimals_max].present?
    tokens = tokens.where("CAST(data->'info'->>'holders_count' AS INTEGER) >= ?", params[:holders_count_min].to_i) if params[:holders_count_min].present?
    tokens = tokens.where("CAST(data->'info'->>'holders_count' AS INTEGER) <= ?", params[:holders_count_max].to_i) if params[:holders_count_max].present?
    tokens = tokens.where("CAST(data->'info'->>'total_supply' AS NUMERIC) >= ?", params[:total_supply_min]) if params[:total_supply_min].present?
    tokens = tokens.where("CAST(data->'info'->>'total_supply' AS NUMERIC) <= ?", params[:total_supply_max]) if params[:total_supply_max].present?
    tokens = tokens.where("CAST(data->'info'->>'exchange_rate' AS DECIMAL) >= ?", params[:exchange_rate_min].to_f) if params[:exchange_rate_min].present?
    tokens = tokens.where("CAST(data->'info'->>'exchange_rate' AS DECIMAL) <= ?", params[:exchange_rate_max].to_f) if params[:exchange_rate_max].present?
    tokens = tokens.where("CAST(data->'info'->>'volume_24h' AS NUMERIC) >= ?", params[:volume_24h_min]) if params[:volume_24h_min].present?
    tokens = tokens.where("CAST(data->'info'->>'volume_24h' AS NUMERIC) <= ?", params[:volume_24h_max]) if params[:volume_24h_max].present?
    tokens = tokens.where("CAST(data->'info'->>'circulating_market_cap' AS NUMERIC) >= ?", params[:circulating_market_cap_min]) if params[:circulating_market_cap_min].present?
    tokens = tokens.where("CAST(data->'info'->>'circulating_market_cap' AS NUMERIC) <= ?", params[:circulating_market_cap_max]) if params[:circulating_market_cap_max].present?

    # Apply sorting
    sort_by = params[:sort_by] || 'id'
    sort_order = params[:sort_order]&.downcase == 'asc' ? 'asc' : 'desc'
    
    allowed_sort_fields = {
      # Basic fields
      'id' => 'ethereum_tokens.id',
      'created_at' => 'ethereum_tokens.created_at',
      'updated_at' => 'ethereum_tokens.updated_at',
      'address_hash' => 'ethereum_tokens.address_hash',
      
      # Token info fields (from JSON data)
      'name' => "data->'info'->>'name'",
      'symbol' => "data->'info'->>'symbol'",
      'address' => "data->'info'->>'address'",
      'type' => "data->'info'->>'type'",
      'decimals' => "CAST(data->'info'->>'decimals' AS INTEGER)",
      'holders_count' => "CAST(data->'info'->>'holders_count' AS INTEGER)",
      'total_supply' => "CAST(data->'info'->>'total_supply' AS NUMERIC)",
      'exchange_rate' => "CAST(data->'info'->>'exchange_rate' AS DECIMAL)",
      'volume_24h' => "CAST(data->'info'->>'volume_24h' AS NUMERIC)",
      'circulating_market_cap' => "CAST(data->'info'->>'circulating_market_cap' AS NUMERIC)",
      'icon_url' => "data->'info'->>'icon_url'"
    }
    
    if allowed_sort_fields.key?(sort_by)
      sort_column = allowed_sort_fields[sort_by]
      # Add NULLS LAST for JSON-based fields to ensure tokens with data come first
      if sort_column.include?("data->")
        tokens = tokens.order(Arel.sql("#{sort_column} #{sort_order} NULLS LAST"))
      else
        tokens = tokens.order(Arel.sql("#{sort_column} #{sort_order}"))
      end
    else
      # Default fallback
      tokens = tokens.order(Arel.sql("ethereum_tokens.id DESC"))
    end
    
    # Apply pagination with defaults
    limit = params[:limit]&.to_i || 10
    limit = [limit, 50].min # Ensure limit doesn't exceed maximum
    
    # Calculate offset from either offset param or page param
    offset = if params[:page].present?
               page = [params[:page].to_i, 1].max # Ensure page is at least 1
               (page - 1) * limit
             else
               params[:offset]&.to_i || 0
             end
    
    # Get total count before applying limit/offset
    total_count = tokens.count
    
    # Apply pagination
    paginated_tokens = tokens.limit(limit).offset(offset)
    
    # Calculate pagination metadata
    current_page = (offset / limit) + 1
    total_pages = (total_count.to_f / limit).ceil
    
    render json: {
      results: paginated_tokens.pluck(:address_hash),
      pagination: {
        total: total_count,
        limit: limit,
        offset: offset,
        page: current_page,
        total_pages: total_pages
      }
    }
  end

  private

  def get_token_info(token)
    blockscout_api_get("/tokens/#{token}")
  end

  def get_token_transfers(token)
    blockscout_api_get("/tokens/#{token}/transfers")
  end

  def get_token_holders(token)
    blockscout_api_get("/tokens/#{token}/holders")
  end

  def get_token_counters(token)
    blockscout_api_get("/tokens/#{token}/counters")
  end

  def get_token_instances(token)
    blockscout_api_get("/tokens/#{token}/instances")
  end

end