#
# ChainFetch Ethereum Intelligence API provides comprehensive blockchain analysis tools
# including block analysis, DeFi/NFT tracking, smart contract intelligence, and RPC proxy services.
#
class Api::EthereumController < ActionController::API
  require 'net/http'
  require 'json'
  
  ETHEREUM_URL = 'https://ethereum.chainfetch.app'
  BEARER_TOKEN = 'u82736GTDV28DME08HD87H3D3JHGD33ed'
  
  # @summary Get block summary with timing and gas analysis
  # @parameter number(path) [!String] Block number (hex or decimal) or 'latest'
  # @parameter api_key(query) [String] Optional API key for usage tracking
  # @response success(200) [Hash{block_number: Integer, timestamp: Integer, timestamp_utc: String, block_interval: Float, transaction_count: Integer, gas_used: Integer, gas_limit: Integer, gas_usage_percentage: Float, base_fee_gwei: Float, miner: String, total_eth_value: Float}]
  # @response not_found(404) [Hash{error: String}]
  def block_summary
    api_key = request.headers['X-API-Key'] || params[:api_key]
    Rails.logger.info "🔍 Block summary request for block #{params[:number]}" + (api_key ? " from key: #{api_key[0..7]}..." : "")
    
    analyzer = BlockAnalyzerService.new
    result = analyzer.get_block_summary(params[:number])
    
    render json: result
  end
  
  # @summary Get analyzed block transactions with filters
  # @parameter number(path) [!String] Block number (hex or decimal) or 'latest'
  # @parameter min_value(query) [String] Minimum transaction value in ETH
  # @parameter contract_only(query) [String] Filter only contract interactions
  # @parameter api_key(query) [String] Optional API key for usage tracking
  # @response success(200) [Hash{block_number: Integer, total_transactions: Integer, filtered_transactions: Integer, transactions: Array<Hash{hash: String, from: String, to: String, value_eth: Float, gas_price_gwei: Float, contract_name: String, is_contract_interaction: Boolean, is_eip1559: Boolean, activity_type: String, function_signature: String, function_name: String, category: String, input_data: String}>}]
  # @response not_found(404) [Hash{error: String}]
  def block_transactions
    api_key = request.headers['X-API-Key'] || params[:api_key]
    Rails.logger.info "📊 Block transactions request for block #{params[:number]}" + (api_key ? " from key: #{api_key[0..7]}..." : "")
    
    # Parse filter parameters
    filters = {}
    filters[:min_value] = params[:min_value] if params[:min_value]
    filters[:contract_only] = params[:contract_only] == 'true' if params[:contract_only]
    
    analyzer = BlockAnalyzerService.new
    result = analyzer.get_block_transactions(params[:number], filters)
    
    render json: result
  end
  
  # @summary Get whale transactions (>10 ETH)
  # @parameter number(path) [!String] Block number (hex or decimal) or 'latest'
  # @parameter api_key(query) [String] Optional API key for usage tracking
  # @response success(200) [Hash{block_number: Integer, whale_threshold: String, whale_count: Integer, total_whale_value: Float, transactions: Array<Hash{hash: String, from: String, to: String, value_eth: Float, gas_price_gwei: Float, contract_name: String, function_signature: String, input_data: String}>}]
  # @response not_found(404) [Hash{error: String}]
  def block_whale
    api_key = request.headers['X-API-Key'] || params[:api_key]
    Rails.logger.info "🐋 Whale transactions request for block #{params[:number]}" + (api_key ? " from key: #{api_key[0..7]}..." : "")
    
    analyzer = BlockAnalyzerService.new
    result = analyzer.get_whale_transactions(params[:number])
    
    render json: result
  end
  
  # @summary Get gas fee analysis and recommendations
  # @parameter number(path) [!String] Block number (hex or decimal) or 'latest'
  # @parameter api_key(query) [String] Optional API key for usage tracking
  # @response success(200) [Hash{base_fee_gwei: Float, avg_gas_price_gwei: Float, median_gas_price_gwei: Float, max_gas_price_gwei: Float, avg_priority_fee_gwei: Float, high_fee_transactions: Integer, total_gas_used: Integer, estimated_total_fees_eth: Float}]
  # @response not_found(404) [Hash{error: String}]
  def block_fees
    api_key = request.headers['X-API-Key'] || params[:api_key]
    Rails.logger.info "⛽ Fee analysis request for block #{params[:number]}" + (api_key ? " from key: #{api_key[0..7]}..." : "")
    
    analyzer = BlockAnalyzerService.new
    result = analyzer.get_fee_analysis(params[:number])
    
    render json: result
  end
  
  # @summary Get network health and congestion metrics
  # @parameter number(path) [!String] Block number (hex or decimal) or 'latest'
  # @parameter api_key(query) [String] Optional API key for usage tracking
  # @response success(200) [Hash{gas_usage_percentage: Float, congestion_level: String, transaction_count: Integer, block_fullness: String, network_status: String, recommended_gas_price: Float}]
  # @response not_found(404) [Hash{error: String}]
  def block_health
    api_key = request.headers['X-API-Key'] || params[:api_key]
    Rails.logger.info "🏥 Network health request for block #{params[:number]}" + (api_key ? " from key: #{api_key[0..7]}..." : "")
    
    analyzer = BlockAnalyzerService.new
    result = analyzer.get_health_metrics(params[:number])
    
    render json: result
  end
  
  # @summary Get DeFi activity summary and protocol analysis
  # @parameter number(path) [!String] Block number (hex or decimal) or 'latest'
  # @parameter api_key(query) [String] Optional API key for usage tracking
  # @response success(200) [Hash{block_number: Integer, defi_summary: Hash{total_defi_transactions: Integer, unique_protocols: Integer, swap_transactions: Integer, lending_transactions: Integer}, top_protocols: Hash, swap_activity: Array<Hash{hash: String, protocol: String, activity_type: String, value_eth: Float, from: String, to: String}>, lending_activity: Array<Hash{hash: String, protocol: String, activity_type: String, value_eth: Float, from: String, to: String}>, total_defi_volume: Float}]
  # @response not_found(404) [Hash{error: String}]
  def block_defi
    api_key = request.headers['X-API-Key'] || params[:api_key]
    Rails.logger.info "🏦 DeFi activity request for block #{params[:number]}" + (api_key ? " from key: #{api_key[0..7]}..." : "")
    
    analyzer = BlockAnalyzerService.new
    result = analyzer.get_defi_activity(params[:number])
    
    render json: result
  end
  
  # @summary Get NFT mints, transfers, and marketplace activity
  # @parameter number(path) [!String] Block number (hex or decimal) or 'latest'
  # @parameter api_key(query) [String] Optional API key for usage tracking
  # @response success(200) [Hash{block_number: Integer, nft_summary: Hash{total_nft_transactions: Integer, mints: Integer, transfers: Integer, marketplaces_active: Integer}, mints: Array<Hash{hash: String, marketplace: String, activity_type: String, value_eth: Float, from: String, to: String}>, transfers: Array<Hash{hash: String, marketplace: String, activity_type: String, value_eth: Float, from: String, to: String}>, marketplaces: Hash, total_nft_volume: Float}]
  # @response not_found(404) [Hash{error: String}]
  def block_nft
    api_key = request.headers['X-API-Key'] || params[:api_key]
    Rails.logger.info "🎨 NFT activity request for block #{params[:number]}" + (api_key ? " from key: #{api_key[0..7]}..." : "")
    
    analyzer = BlockAnalyzerService.new
    result = analyzer.get_nft_activity(params[:number])
    
    render json: result
  end
  
  # @summary Get decoded smart contract events and logs
  # @parameter number(path) [!String] Block number (hex or decimal) or 'latest'
  # @parameter api_key(query) [String] Optional API key for usage tracking
  # @response success(200) [Hash{block_number: Integer, total_events: Integer, event_categories: Hash, decoded_events: Array<Hash>, top_contracts: Hash}]
  # @response not_found(404) [Hash{error: String}]
  def block_events
    api_key = request.headers['X-API-Key'] || params[:api_key]
    Rails.logger.info "📡 Smart contract events request for block #{params[:number]}" + (api_key ? " from key: #{api_key[0..7]}..." : "")
    
    analyzer = BlockAnalyzerService.new
    result = analyzer.get_smart_contract_events(params[:number])
    
    render json: result
  end
  
  # @summary Analyze address behavior and classification
  # @parameter address(path) [!String] Ethereum address
  # @parameter api_key(query) [String] Optional API key for usage tracking
  # @response success(200) [Hash{address: String, is_contract: Boolean, basic_info: Hash{balance_eth: Float, transaction_count: Integer, address_type: String}, classification: Hash{primary_type: String, all_classifications: Array<Hash{type: String, confidence: Float, reason: String}>, confidence_score: Float}, activity_analysis: Hash{status: String, total_transactions: Integer, avg_gas_price: Float, most_active_period: String, interaction_patterns: Hash}, risk_assessment: Hash{risk_level: String, risk_score: Float, risk_factors: Array<String>}}]
  # @response bad_request(400) [Hash{error: String}]
  def address_behavior
    api_key = request.headers['X-API-Key'] || params[:api_key]
    address = params[:address]
    Rails.logger.info "👤 Address behavior analysis for #{address}" + (api_key ? " from key: #{api_key[0..7]}..." : "")
    
    # Parse request body for analysis parameters
    analysis_params = {}
    if request.content_type&.include?('application/json') && request.body.read.present?
      analysis_params = JSON.parse(request.body.read)
    end
    
    address_analyzer = AddressAnalyzerService.new
    result = address_analyzer.analyze_address_behavior(address, analysis_params)
    
    render json: result
  end
  
  # @summary Universal Ethereum RPC proxy
  # @parameter api_key(query) [String] Optional API key for usage tracking
  # @response success(200) [Hash{jsonrpc: String, result: Hash, id: Integer}]
  # @response payment_required(402) [Hash{error: String}]
  # @response internal_server_error(500) [Hash{error: Hash{code: Integer, message: String}}]
  def rpc_proxy
    # Extract API key for credit tracking (optional)
    api_key = request.headers['X-API-Key'] || params[:api_key]
    
    # Custom logic can go here:
    # - Validate API key
    # - Check API credits/usage limits
    # - Rate limiting per API key
    # - Log usage for billing
    # - Method filtering (block certain RPC methods)
    
    if api_key
      Rails.logger.info "🔑 API call from key: #{api_key[0..7]}..."
      # TODO: Implement credit checking/deduction
      # return render json: { error: 'Insufficient API credits' }, status: 402 if credits_exhausted?
    end
    
    # Forward the RPC call to Ethereum node
    rpc_request = if request.content_type&.include?('application/json')
                    JSON.parse(request.body.read)
                  else
                    {
                      jsonrpc: '2.0',
                      method: params[:method],
                      params: params[:params] || [],
                      id: params[:id] || 1
                    }
                  end
    
    Rails.logger.info "📡 Proxying RPC: #{rpc_request['method']}"
    
    result = forward_rpc_call(rpc_request)
    
    # Custom logic after RPC call:
    # - Log successful calls for billing
    # - Track method usage statistics
    # - Cache responses (for read-only methods)
    
    render json: result
  end
  
  # @summary List all supported API methods and endpoints
  # @parameter api_key(query) [String] Optional API key for usage tracking
  # @response success(200) [Hash{rpc_methods: Hash{blocks: Array<String>, transactions: Array<String>, accounts: Array<String>, contracts: Array<String>, network: Array<String>}, total_rpc_methods: Integer, block_analysis_endpoints: Hash, smart_contract_intelligence: Hash, usage: Hash{rpc: String, analysis: String, address_analysis: String}}]
  def supported_methods
    methods = {
      blocks: [
        'eth_blockNumber',
        'eth_getBlockByNumber',
        'eth_getBlockByHash',
        'eth_getBlockTransactionCountByNumber',
        'eth_getBlockTransactionCountByHash'
      ],
      transactions: [
        'eth_getTransactionByHash',
        'eth_getTransactionByBlockHashAndIndex',
        'eth_getTransactionByBlockNumberAndIndex',
        'eth_getTransactionReceipt',
        'eth_sendRawTransaction'
      ],
      accounts: [
        'eth_getBalance',
        'eth_getTransactionCount',
        'eth_getCode',
        'eth_getStorageAt'
      ],
      contracts: [
        'eth_call',
        'eth_estimateGas',
        'eth_getLogs'
      ],
      network: [
        'eth_chainId',
        'eth_gasPrice',
        'eth_maxPriorityFeePerGas',
        'eth_syncing',
        'net_peerCount',
        'web3_clientVersion'
      ]
    }
    
    block_analysis = {
      'GET /api/ethereum/block/:number/summary' => 'Block timing, gas usage, miner info',
      'GET /api/ethereum/block/:number/transactions' => 'Analyzed transactions with filters',
      'GET /api/ethereum/block/:number/whale' => 'Large transactions over 10 ETH',
      'GET /api/ethereum/block/:number/fees' => 'Gas fee analysis and recommendations',
      'GET /api/ethereum/block/:number/health' => 'Network health and congestion metrics'
    }
    
    smart_contract_intelligence = {
      'GET /api/ethereum/block/:number/defi' => 'DeFi activity summary and protocol analysis',
      'GET /api/ethereum/block/:number/nft' => 'NFT mints, transfers, and marketplace activity',
      'GET /api/ethereum/block/:number/events' => 'Decoded smart contract events and logs',
      'POST /api/ethereum/address/:address/behavior' => 'Address behavior analysis and classification'
    }

    render json: {
      rpc_methods: methods,
      total_rpc_methods: methods.values.flatten.length,
      block_analysis_endpoints: block_analysis,
      smart_contract_intelligence: smart_contract_intelligence,
      usage: {
        rpc: "POST /api/ethereum/rpc with JSON-RPC 2.0 format",
        analysis: "GET requests with block number (hex or decimal)",
        address_analysis: "POST requests with address and optional parameters"
      }
    }
  end
  
  # @summary Get API usage statistics for authenticated user
  # @parameter api_key(query) [!String] API key for authentication
  # @response success(200) [Hash{api_key: String, calls_today: Integer, credits_remaining: Integer, rate_limit: String, most_used_methods: Array<String>}]
  # @response unauthorized(401) [Hash{error: String}]
  def api_stats
    api_key = request.headers['X-API-Key'] || params[:api_key]
    
    if api_key.blank?
      return render json: { error: 'API key required' }, status: 401
    end
    
    # TODO: Implement actual usage tracking
    render json: {
      api_key: "#{api_key[0..7]}...",
      calls_today: 0,      # TODO: Get from database
      credits_remaining: 10000,  # TODO: Get from database
      rate_limit: '1000 calls/hour',
      most_used_methods: []  # TODO: Get from usage logs
    }
  end
  
  private
  
  # Forward RPC call to Ethereum node
  def forward_rpc_call(rpc_request)
    uri = URI(ETHEREUM_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10  # Configurable timeout
    
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{BEARER_TOKEN}"
    request['Content-Type'] = 'application/json'
    request['User-Agent'] = 'ChainFetch-Proxy/1.0'
    
    request.body = rpc_request.to_json
    response = http.request(request)
    
    JSON.parse(response.body)
  rescue JSON::ParserError => e
    { 'error' => { 'code' => -32700, 'message' => 'Parse error' } }
  rescue => e
    Rails.logger.error "❌ RPC proxy error: #{e.message}"
    { 'error' => { 'code' => -32603, 'message' => 'Internal error' } }
  end
  
  # TODO: Implement these methods for your business logic
  # def credits_exhausted?
  #   # Check if API key has remaining credits
  #   false
  # end
  # 
  # def deduct_credits(api_key, method)
  #   # Deduct credits based on RPC method cost
  # end
  # 
  # def log_usage(api_key, method, success)
  #   # Log API call for billing/analytics
  # end
end