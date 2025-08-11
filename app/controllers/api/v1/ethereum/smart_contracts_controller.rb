class Api::V1::Ethereum::SmartContractsController < Api::V1::Ethereum::BaseController
  # @summary Get smart contract info
  # @parameter address(path) [!String] The smart contract address
  # @response success(200) [Hash{smart_contract: Hash}]
  def show
    address = params[:address]
    render json: get_smart_contract(address)
  end

  # @summary Semantic Search for smart contracts
  # @parameter query(query) [!String] The query to search for
  # @parameter limit(query) [!Integer] The number of results to return (default: 10)
  # @response success(200) [Hash{result: Hash{points: Array<Hash{id: Integer, version: Integer, score: Float, payload: Hash{address_summary: String}}}>}}]
  # This endpoint queries Qdrant to search smart contracts based on the provided input. Contract summaries are embedded using dengcao/Qwen3-Embedding-0.6B:Q8_0 and stored in Qdrant's 'addresses' collection, filtered for contracts only.
  def semantic_search
    query = params[:query]
    limit = params[:limit] || 10
    embedding = EmbeddingService.new(query).call
    qdrant_objects = QdrantService.new.query_points(collection: "smart_contracts", query: embedding, limit: limit)
    render json: qdrant_objects
  end

  # @summary Smart Contract Summary
  # @parameter address(query) [!String] The smart contract address to get summary for
  # @response success(200) [Hash{summary: String}]
  def smart_contract_summary
    address = params[:address]
    
    begin
      contract_data = Ethereum::SmartContractDataService.new(address).call
      summary = Ethereum::SmartContractSummaryService.new(contract_data, address).call
      render json: { summary: summary }
    rescue Ethereum::BaseService::NotFoundError => e
      render json: { error: "Address #{address} is not a smart contract" }, status: 400
    rescue Ethereum::BaseService::ApiError => e
      render json: { error: "Failed to fetch smart contract data: #{e.message}" }, status: 502
    rescue => e
      Rails.logger.error "Unexpected error in smart_contract_summary: #{e.class.name}: #{e.message}"
      render json: { error: "Internal server error" }, status: 500
    end
  end

  # @summary LLM Search for smart contracts
  # @parameter query(query) [!String] The query to search for
  # @response success(200) [Hash{results: String}]
  # This endpoint leverages LLaMA 3.2 3B model to analyze and select the most suitable parameters from 150+ available options for smart contract search
  def llm_search
    query = params[:query]
    
    # Create a smart contract specific search service that filters for contracts only
    response = SmartContractDataSearchService.new(query).call
    render json: response
  end

  # @summary JSON Search for smart contracts
  # @parameter is_self_destructed(query) [Boolean] Whether the contract is self-destructed
  # @parameter file_path(query) [String] Contract file path
  # @parameter is_verified(query) [Boolean] Whether the contract is verified
  # @parameter optimization_enabled(query) [Boolean] Whether optimization is enabled
  # @parameter verified_twin_address_hash(query) [String] Verified twin address hash
  # @parameter is_verified_via_verifier_alliance(query) [Boolean] Whether verified via verifier alliance
  # @parameter verified_at_min(query) [String] Minimum verification date (ISO format)
  # @parameter verified_at_max(query) [String] Maximum verification date (ISO format)
  # @parameter proxy_type(query) [String] Proxy type (e.g., "eip1967")
  # @parameter status(query) [String] Contract status (e.g., "success")
  # @parameter name(query) [String] Contract name
  # @parameter is_blueprint(query) [Boolean] Whether the contract is a blueprint
  # @parameter license_type(query) [String] License type
  # @parameter is_fully_verified(query) [Boolean] Whether the contract is fully verified
  # @parameter is_verified_via_eth_bytecode_db(query) [Boolean] Whether verified via ETH bytecode DB
  # @parameter language(query) [String] Programming language (e.g., "solidity")
  # @parameter evm_version(query) [String] EVM version
  # @parameter can_be_visualized_via_sol2uml(query) [Boolean] Whether can be visualized via sol2uml
  # @parameter is_verified_via_sourcify(query) [Boolean] Whether verified via sourcify
  # @parameter certified(query) [Boolean] Whether the contract is certified
  # @parameter is_changed_bytecode(query) [Boolean] Whether bytecode is changed
  # @parameter is_partially_verified(query) [Boolean] Whether partially verified
  # @parameter compiler_version(query) [String] Compiler version (e.g., "v0.4.24+commit.e67f0147")
  # @parameter optimization_runs_min(query) [Integer] Minimum optimization runs
  # @parameter optimization_runs_max(query) [Integer] Maximum optimization runs
  # @parameter has_constructor_args(query) [Boolean] Whether has constructor arguments
  # @parameter has_decoded_constructor_args(query) [Boolean] Whether has decoded constructor arguments
  # @parameter abi_function_count_min(query) [Integer] Minimum ABI function count
  # @parameter abi_function_count_max(query) [Integer] Maximum ABI function count
  # @parameter abi_event_count_min(query) [Integer] Minimum ABI event count
  # @parameter abi_event_count_max(query) [Integer] Maximum ABI event count
  # @parameter has_external_libraries(query) [Boolean] Whether has external libraries
  # @parameter library_count_min(query) [Integer] Minimum library count
  # @parameter library_count_max(query) [Integer] Maximum library count
  # @parameter implementation_address(query) [String] Implementation address for proxy contracts
  # @parameter implementation_name(query) [String] Implementation name
  # @parameter has_implementations(query) [Boolean] Whether has implementations
  # @parameter implementation_count_min(query) [Integer] Minimum implementation count
  # @parameter implementation_count_max(query) [Integer] Maximum implementation count
  # @parameter creation_bytecode_size_min(query) [Integer] Minimum creation bytecode size
  # @parameter creation_bytecode_size_max(query) [Integer] Maximum creation bytecode size
  # @parameter deployed_bytecode_size_min(query) [Integer] Minimum deployed bytecode size
  # @parameter deployed_bytecode_size_max(query) [Integer] Maximum deployed bytecode size
  # @parameter source_code_lines_min(query) [Integer] Minimum source code lines
  # @parameter source_code_lines_max(query) [Integer] Maximum source code lines
  # @parameter source_code_size_min(query) [Integer] Minimum source code size
  # @parameter source_code_size_max(query) [Integer] Maximum source code size
  # @parameter sourcify_repo_url(query) [String] Sourcify repository URL
  # @parameter constructor_args(query) [String] Constructor arguments (hex string)
  # @parameter has_additional_sources(query) [Boolean] Whether has additional source files
  # @parameter additional_sources_count_min(query) [Integer] Minimum additional sources count
  # @parameter additional_sources_count_max(query) [Integer] Maximum additional sources count
  # @parameter compiler_optimizer_enabled(query) [Boolean] Whether compiler optimization is enabled
  # @parameter compiler_optimizer_runs_min(query) [Integer] Minimum compiler optimizer runs
  # @parameter compiler_optimizer_runs_max(query) [Integer] Maximum compiler optimizer runs
  # @parameter has_compiler_libraries(query) [Boolean] Whether compiler uses libraries

  # @parameter limit(query) [Integer] Number of results to return (default: 10, max: 50)
  # @parameter offset(query) [Integer] Number of results to skip for pagination (default: 0)
  # @parameter page(query) [Integer] Page number (alternative to offset, starts at 1)
  # @parameter sort_by(query) [String] Field to sort by (default: "id")
  # @parameter sort_order(query) [String] Sort direction: "asc" or "desc" (default: "desc")
  # @response success(200) [Hash{results: Array<Hash{id: Integer, address_hash: String, data: Hash}>, pagination: Hash{total: Integer, limit: Integer, offset: Integer, page: Integer, total_pages: Integer}}]
  # This endpoint provides 50+ parameters to search for smart contracts based on the provided input.
  def json_search
    # Start with all addresses and filter for contracts only
    contracts = EthereumSmartContract.where(nil)
    
    # Contract-specific boolean fields (from flat smart contract data structure)
    contracts = contracts.where("data->>'is_self_destructed' = ?", params[:is_self_destructed].to_s) if params[:is_self_destructed].present?
    contracts = contracts.where("data->>'is_verified' = ?", params[:is_verified].to_s) if params[:is_verified].present?
    contracts = contracts.where("data->>'optimization_enabled' = ?", params[:optimization_enabled].to_s) if params[:optimization_enabled].present?
    contracts = contracts.where("data->>'is_verified_via_verifier_alliance' = ?", params[:is_verified_via_verifier_alliance].to_s) if params[:is_verified_via_verifier_alliance].present?
    contracts = contracts.where("data->>'is_blueprint' = ?", params[:is_blueprint].to_s) if params[:is_blueprint].present?
    contracts = contracts.where("data->>'is_fully_verified' = ?", params[:is_fully_verified].to_s) if params[:is_fully_verified].present?
    contracts = contracts.where("data->>'is_verified_via_eth_bytecode_db' = ?", params[:is_verified_via_eth_bytecode_db].to_s) if params[:is_verified_via_eth_bytecode_db].present?
    contracts = contracts.where("data->>'can_be_visualized_via_sol2uml' = ?", params[:can_be_visualized_via_sol2uml].to_s) if params[:can_be_visualized_via_sol2uml].present?
    contracts = contracts.where("data->>'is_verified_via_sourcify' = ?", params[:is_verified_via_sourcify].to_s) if params[:is_verified_via_sourcify].present?
    contracts = contracts.where("data->>'certified' = ?", params[:certified].to_s) if params[:certified].present?
    contracts = contracts.where("data->>'is_changed_bytecode' = ?", params[:is_changed_bytecode].to_s) if params[:is_changed_bytecode].present?
    contracts = contracts.where("data->>'is_partially_verified' = ?", params[:is_partially_verified].to_s) if params[:is_partially_verified].present?
    
    # Contract-specific string fields (from flat smart contract data structure)
    contracts = contracts.where("data->>'file_path' = ?", params[:file_path]) if params[:file_path].present?
    contracts = contracts.where("data->>'verified_twin_address_hash' = ?", params[:verified_twin_address_hash]) if params[:verified_twin_address_hash].present?
    contracts = contracts.where("data->>'proxy_type' = ?", params[:proxy_type]) if params[:proxy_type].present?
    contracts = contracts.where("data->>'status' = ?", params[:status]) if params[:status].present?
    contracts = contracts.where("data->>'name' = ?", params[:name]) if params[:name].present?
    contracts = contracts.where("data->>'license_type' = ?", params[:license_type]) if params[:license_type].present?
    contracts = contracts.where("data->>'language' = ?", params[:language]) if params[:language].present?
    contracts = contracts.where("data->>'evm_version' = ?", params[:evm_version]) if params[:evm_version].present?
    contracts = contracts.where("data->>'compiler_version' = ?", params[:compiler_version]) if params[:compiler_version].present?
    contracts = contracts.where("data->>'sourcify_repo_url' = ?", params[:sourcify_repo_url]) if params[:sourcify_repo_url].present?
    
    # Compiler settings filters (nested object searches)
    contracts = contracts.where("data->'compiler_settings'->'optimizer'->>'enabled' = ?", params[:compiler_optimizer_enabled].to_s) if params[:compiler_optimizer_enabled].present?
    contracts = contracts.where("CAST(data->'compiler_settings'->'optimizer'->>'runs' AS INTEGER) >= ?", params[:compiler_optimizer_runs_min].to_i) if params[:compiler_optimizer_runs_min].present?
    contracts = contracts.where("CAST(data->'compiler_settings'->'optimizer'->>'runs' AS INTEGER) <= ?", params[:compiler_optimizer_runs_max].to_i) if params[:compiler_optimizer_runs_max].present?
    contracts = contracts.where("data->'compiler_settings'->'libraries' IS NOT NULL AND jsonb_typeof(data->'compiler_settings'->'libraries') = 'object'") if params[:has_compiler_libraries] == 'true'
    contracts = contracts.where("data->'compiler_settings'->'libraries' IS NULL OR jsonb_typeof(data->'compiler_settings'->'libraries') != 'object'") if params[:has_compiler_libraries] == 'false'
    
    # Date range filters (from flat smart contract data structure)
    contracts = contracts.where("data->>'verified_at' >= ?", params[:verified_at_min]) if params[:verified_at_min].present?
    contracts = contracts.where("data->>'verified_at' <= ?", params[:verified_at_max]) if params[:verified_at_max].present?
    
    # Numeric range filters (from flat smart contract data structure)
    contracts = contracts.where("CAST(data->>'optimization_runs' AS INTEGER) >= ?", params[:optimization_runs_min].to_i) if params[:optimization_runs_min].present?
    contracts = contracts.where("CAST(data->>'optimization_runs' AS INTEGER) <= ?", params[:optimization_runs_max].to_i) if params[:optimization_runs_max].present?
    
    # ABI-related filters (calculated from ABI array)
    if params[:abi_function_count_min].present? || params[:abi_function_count_max].present?
      contracts = contracts.where("jsonb_array_length(COALESCE(data->'abi', '[]'::jsonb)) >= ?", params[:abi_function_count_min].to_i) if params[:abi_function_count_min].present?
      contracts = contracts.where("jsonb_array_length(COALESCE(data->'abi', '[]'::jsonb)) <= ?", params[:abi_function_count_max].to_i) if params[:abi_function_count_max].present?
    end
    
    # Implementation-related filters (for proxy contracts)
    if params[:implementation_address].present?
      contracts = contracts.where("data->'implementations' @> ?", [{ "address" => params[:implementation_address] }].to_json)
    end
    if params[:implementation_name].present?
      contracts = contracts.where("data->'implementations' @> ?", [{ "name" => params[:implementation_name] }].to_json)
    end
    contracts = contracts.where("jsonb_array_length(COALESCE(data->'implementations', '[]'::jsonb)) > 0") if params[:has_implementations] == 'true'
    contracts = contracts.where("jsonb_array_length(COALESCE(data->'implementations', '[]'::jsonb)) = 0") if params[:has_implementations] == 'false'
    contracts = contracts.where("jsonb_array_length(COALESCE(data->'implementations', '[]'::jsonb)) >= ?", params[:implementation_count_min].to_i) if params[:implementation_count_min].present?
    contracts = contracts.where("jsonb_array_length(COALESCE(data->'implementations', '[]'::jsonb)) <= ?", params[:implementation_count_max].to_i) if params[:implementation_count_max].present?
    
    # External libraries filters
    contracts = contracts.where("jsonb_array_length(COALESCE(data->'external_libraries', '[]'::jsonb)) > 0") if params[:has_external_libraries] == 'true'
    contracts = contracts.where("jsonb_array_length(COALESCE(data->'external_libraries', '[]'::jsonb)) = 0") if params[:has_external_libraries] == 'false'
    contracts = contracts.where("jsonb_array_length(COALESCE(data->'external_libraries', '[]'::jsonb)) >= ?", params[:library_count_min].to_i) if params[:library_count_min].present?
    contracts = contracts.where("jsonb_array_length(COALESCE(data->'external_libraries', '[]'::jsonb)) <= ?", params[:library_count_max].to_i) if params[:library_count_max].present?
    
    # Additional sources filters
    contracts = contracts.where("jsonb_array_length(COALESCE(data->'additional_sources', '[]'::jsonb)) > 0") if params[:has_additional_sources] == 'true'
    contracts = contracts.where("jsonb_array_length(COALESCE(data->'additional_sources', '[]'::jsonb)) = 0") if params[:has_additional_sources] == 'false'
    contracts = contracts.where("jsonb_array_length(COALESCE(data->'additional_sources', '[]'::jsonb)) >= ?", params[:additional_sources_count_min].to_i) if params[:additional_sources_count_min].present?
    contracts = contracts.where("jsonb_array_length(COALESCE(data->'additional_sources', '[]'::jsonb)) <= ?", params[:additional_sources_count_max].to_i) if params[:additional_sources_count_max].present?
    
    # Constructor args filters
    contracts = contracts.where("data->>'constructor_args' = ?", params[:constructor_args]) if params[:constructor_args].present?
    contracts = contracts.where("data->'constructor_args' IS NOT NULL AND data->>'constructor_args' != ''") if params[:has_constructor_args] == 'true'
    contracts = contracts.where("data->'constructor_args' IS NULL OR data->>'constructor_args' = ''") if params[:has_constructor_args] == 'false'
    contracts = contracts.where("data->'decoded_constructor_args' IS NOT NULL AND jsonb_array_length(COALESCE(data->'decoded_constructor_args', '[]'::jsonb)) > 0") if params[:has_decoded_constructor_args] == 'true'
    contracts = contracts.where("data->'decoded_constructor_args' IS NULL OR jsonb_array_length(COALESCE(data->'decoded_constructor_args', '[]'::jsonb)) = 0") if params[:has_decoded_constructor_args] == 'false'
    
    # Bytecode size filters (calculated from hex strings)
    contracts = contracts.where("LENGTH(COALESCE(data->>'creation_bytecode', '')) >= ?", params[:creation_bytecode_size_min].to_i * 2) if params[:creation_bytecode_size_min].present? # Each byte = 2 hex chars
    contracts = contracts.where("LENGTH(COALESCE(data->>'creation_bytecode', '')) <= ?", params[:creation_bytecode_size_max].to_i * 2) if params[:creation_bytecode_size_max].present?
    contracts = contracts.where("LENGTH(COALESCE(data->>'deployed_bytecode', '')) >= ?", params[:deployed_bytecode_size_min].to_i * 2) if params[:deployed_bytecode_size_min].present?
    contracts = contracts.where("LENGTH(COALESCE(data->>'deployed_bytecode', '')) <= ?", params[:deployed_bytecode_size_max].to_i * 2) if params[:deployed_bytecode_size_max].present?
    
    # Source code size filters
    if params[:source_code_lines_min].present? || params[:source_code_lines_max].present?
      contracts = contracts.where("LENGTH(COALESCE(data->>'source_code', '')) - LENGTH(REPLACE(COALESCE(data->>'source_code', ''), chr(10), '')) >= ?", params[:source_code_lines_min].to_i) if params[:source_code_lines_min].present?
      contracts = contracts.where("LENGTH(COALESCE(data->>'source_code', '')) - LENGTH(REPLACE(COALESCE(data->>'source_code', ''), chr(10), '')) <= ?", params[:source_code_lines_max].to_i) if params[:source_code_lines_max].present?
    end
    contracts = contracts.where("LENGTH(COALESCE(data->>'source_code', '')) >= ?", params[:source_code_size_min].to_i) if params[:source_code_size_min].present?
    contracts = contracts.where("LENGTH(COALESCE(data->>'source_code', '')) <= ?", params[:source_code_size_max].to_i) if params[:source_code_size_max].present?

    
    # Apply sorting
    sort_by = params[:sort_by] || 'id'
    sort_order = params[:sort_order]&.downcase == 'asc' ? 'asc' : 'desc'
    
    allowed_sort_fields = {
      # Basic fields
      'id' => 'ethereum_smart_contracts.id',
      'created_at' => 'ethereum_smart_contracts.created_at',
      'updated_at' => 'ethereum_smart_contracts.updated_at',
      'address_hash' => 'ethereum_smart_contracts.address_hash',
      
      # Contract-specific fields (from flat smart contract JSON structure)
      'verification_date' => "data->>'verified_at'",
      'compiler_version' => "data->>'compiler_version'",
      'optimization_runs' => "CAST(data->>'optimization_runs' AS INTEGER)",
      'creation_bytecode_size' => "LENGTH(COALESCE(data->>'creation_bytecode', ''))",
      'deployed_bytecode_size' => "LENGTH(COALESCE(data->>'deployed_bytecode', ''))",
      'source_code_size' => "LENGTH(COALESCE(data->>'source_code', ''))",
      'abi_function_count' => "jsonb_array_length(COALESCE(data->'abi', '[]'::jsonb))",
      'implementation_count' => "jsonb_array_length(COALESCE(data->'implementations', '[]'::jsonb))",
      'library_count' => "jsonb_array_length(COALESCE(data->'external_libraries', '[]'::jsonb))",
      'contract_name' => "data->>'name'",
      'language' => "data->>'language'",
      'proxy_type' => "data->>'proxy_type'",
      'license_type' => "data->>'license_type'",
      'evm_version' => "data->>'evm_version'",
      'status' => "data->>'status'",
      'is_verified' => "CASE WHEN data->>'is_verified' = 'true' THEN 1 ELSE 0 END",
      'is_blueprint' => "CASE WHEN data->>'is_blueprint' = 'true' THEN 1 ELSE 0 END",
      'sourcify_repo_url' => "data->>'sourcify_repo_url'",
      'constructor_args' => "data->>'constructor_args'",
      'additional_sources_count' => "jsonb_array_length(COALESCE(data->'additional_sources', '[]'::jsonb))",
      'compiler_optimizer_enabled' => "CASE WHEN data->'compiler_settings'->'optimizer'->>'enabled' = 'true' THEN 1 ELSE 0 END",
      'compiler_optimizer_runs' => "CAST(data->'compiler_settings'->'optimizer'->>'runs' AS INTEGER)"
    }
    
    if allowed_sort_fields.key?(sort_by)
      sort_column = allowed_sort_fields[sort_by]
      # Add NULLS LAST for JSON-based fields to ensure contracts with data come first
      if sort_column.include?("data->")
        contracts = contracts.order(Arel.sql("#{sort_column} #{sort_order} NULLS LAST"))
      else
        contracts = contracts.order(Arel.sql("#{sort_column} #{sort_order}"))
      end
    else
      # Default fallback
      contracts = contracts.order(Arel.sql("ethereum_smart_contracts.id DESC"))
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
    total_count = contracts.count
    
    # Apply pagination
    paginated_contracts = contracts.limit(limit).offset(offset)
    
    # Calculate pagination metadata
    current_page = (offset / limit) + 1
    total_pages = (total_count.to_f / limit).ceil
    
    render json: {
      results: paginated_contracts.map { |contract| 
        { 
          id: contract.id, 
          address_hash: contract.address_hash, 
          data: contract.data 
        } 
      },
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

  def get_smart_contract(address)
    blockscout_api_get("/smart-contracts/#{address}")
  end
end






