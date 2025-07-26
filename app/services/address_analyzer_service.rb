class AddressAnalyzerService
  require 'net/http'
  require 'json'
  
  ETHEREUM_URL = 'https://ethereum.chainfetch.app'
  BEARER_TOKEN = 'u82736GTDV28DME08HD87H3D3JHGD33ed'
  
  # Classification thresholds
  WHALE_THRESHOLD = 100 # ETH
  HIGH_ACTIVITY_THRESHOLD = 100 # transactions per day
  BOT_PATTERN_THRESHOLD = 0.8 # similarity threshold for bot detection
  
  def initialize
    @decoder = ContractDecoderService.instance
  end
  
  def analyze_address_behavior(address, options = {})
    return { error: 'Invalid address format' } unless valid_address?(address)
    
    # Get basic account information
    balance = get_address_balance(address)
    transaction_count = get_transaction_count(address)
    code = get_address_code(address)
    
    is_contract = code && code != '0x'
    
    # Get recent transaction history (optional with more detailed analysis)
    transaction_history = options['include_history'] ? get_recent_transactions(address, options['limit'] || 100) : []
    
    analysis = {
      address: address,
      is_contract: is_contract,
      basic_info: {
        balance_eth: (balance / 1e18.to_f).round(6),
        transaction_count: transaction_count,
        address_type: is_contract ? 'Contract' : 'EOA (Externally Owned Account)'
      },
      classification: classify_address(balance, transaction_count, transaction_history, is_contract),
      activity_analysis: analyze_activity_patterns(transaction_history),
      risk_assessment: assess_risk_factors(address, transaction_history, is_contract)
    }
    
    # Add detailed transaction analysis if requested
    if options['include_detailed_analysis'] && transaction_history.any?
      analysis[:detailed_analysis] = {
        contract_interactions: analyze_contract_interactions(transaction_history),
        gas_usage_patterns: analyze_gas_patterns(transaction_history),
        value_transfer_patterns: analyze_value_patterns(transaction_history),
        time_patterns: analyze_time_patterns(transaction_history)
      }
    end
    
    analysis
  end
  
  private
  
  def valid_address?(address)
    address.match?(/^0x[a-fA-F0-9]{40}$/)
  end
  
  def get_address_balance(address)
    result = rpc_call('eth_getBalance', [address, 'latest'])
    result ? result.to_i(16) : 0
  rescue => e
    Rails.logger.error "❌ Balance fetch error: #{e.message}"
    0
  end
  
  def get_transaction_count(address)
    result = rpc_call('eth_getTransactionCount', [address, 'latest'])
    result ? result.to_i(16) : 0
  rescue => e
    Rails.logger.error "❌ Transaction count fetch error: #{e.message}"
    0
  end
  
  def get_address_code(address)
    rpc_call('eth_getCode', [address, 'latest'])
  rescue => e
    Rails.logger.error "❌ Code fetch error: #{e.message}"
    '0x'
  end
  
  def get_recent_transactions(address, limit = 100)
    # Note: This is a simplified version. In production, you'd use a service like Etherscan API
    # or maintain your own indexed transaction database for efficient address history queries
    []
  end
  
  def classify_address(balance, tx_count, history, is_contract)
    balance_eth = balance / 1e18.to_f
    
    classifications = []
    
    # Whale classification
    if balance_eth >= WHALE_THRESHOLD
      classifications << {
        type: 'whale',
        confidence: 0.9,
        reason: "Balance of #{balance_eth.round(2)} ETH exceeds whale threshold"
      }
    end
    
    # High activity classification
    if tx_count >= HIGH_ACTIVITY_THRESHOLD
      classifications << {
        type: 'high_activity',
        confidence: 0.8,
        reason: "#{tx_count} transactions indicates high activity"
      }
    end
    
    # Contract type classification
    if is_contract
      contract_type = classify_contract_type(balance, tx_count)
      classifications << {
        type: contract_type,
        confidence: 0.7,
        reason: "Smart contract with specific usage patterns"
      }
    end
    
    # Bot pattern detection (based on transaction patterns)
    if history.any? && detect_bot_patterns(history)
      classifications << {
        type: 'bot',
        confidence: 0.6,
        reason: "Regular transaction patterns suggest automated behavior"
      }
    end
    
    {
      primary_type: classifications.first&.dig(:type) || 'regular_user',
      all_classifications: classifications,
      confidence_score: classifications.first&.dig(:confidence) || 0.5
    }
  end
  
  def classify_contract_type(balance, tx_count)
    case
    when tx_count > 10000
      'popular_protocol'
    when balance > 1000 * 1e18 # 1000 ETH
      'treasury_contract'
    when tx_count < 10
      'inactive_contract'
    else
      'active_contract'
    end
  end
  
  def analyze_activity_patterns(history)
    return { status: 'No transaction history available' } if history.empty?
    
    {
      total_transactions: history.length,
      avg_gas_price: calculate_avg_gas_price(history),
      most_active_period: find_most_active_period(history),
      interaction_patterns: analyze_interaction_patterns(history)
    }
  end
  
  def assess_risk_factors(address, history, is_contract)
    risk_factors = []
    risk_score = 0
    
    # Check for known risky patterns
    if history.any? && has_suspicious_patterns?(history)
      risk_factors << "Unusual transaction patterns detected"
      risk_score += 0.3
    end
    
    # Check if it's a new address with high activity
    if history.length > 50 && estimate_address_age(history) < 7 # days
      risk_factors << "High activity on new address"
      risk_score += 0.2
    end
    
    # Check for contract without verification (simplified)
    if is_contract
      risk_factors << "Unverified smart contract"
      risk_score += 0.1
    end
    
    {
      risk_level: case risk_score
                  when 0..0.2 then 'low'
                  when 0.2..0.5 then 'medium'
                  else 'high'
                  end,
      risk_score: risk_score.round(2),
      risk_factors: risk_factors
    }
  end
  
  def analyze_contract_interactions(history)
    # Analyze which contracts this address interacts with
    contract_interactions = history.select { |tx| tx['to'] && get_address_code(tx['to']) != '0x' }
    
    {
      total_contract_calls: contract_interactions.length,
      unique_contracts: contract_interactions.map { |tx| tx['to'] }.uniq.length,
      top_contracts: contract_interactions.group_by { |tx| tx['to'] }
                                        .sort_by { |_, txs| -txs.length }
                                        .first(5)
                                        .map { |addr, txs| { address: addr, call_count: txs.length } }
    }
  end
  
  def analyze_gas_patterns(history)
    gas_prices = history.map { |tx| (tx['gasPrice'] || '0x0').to_i(16) }.reject(&:zero?)
    
    return { status: 'No gas data available' } if gas_prices.empty?
    
    {
      avg_gas_price_gwei: (gas_prices.sum / gas_prices.length / 1e9).round(2),
      min_gas_price_gwei: (gas_prices.min / 1e9).round(2),
      max_gas_price_gwei: (gas_prices.max / 1e9).round(2),
      gas_strategy: determine_gas_strategy(gas_prices)
    }
  end
  
  def analyze_value_patterns(history)
    values = history.map { |tx| (tx['value'] || '0x0').to_i(16) }.reject(&:zero?)
    
    return { status: 'No value transfers found' } if values.empty?
    
    total_eth = values.sum / 1e18.to_f
    
    {
      total_eth_transferred: total_eth.round(6),
      avg_transfer_eth: (total_eth / values.length).round(6),
      largest_transfer_eth: (values.max / 1e18.to_f).round(6),
      transfer_frequency: values.length
    }
  end
  
  def analyze_time_patterns(history)
    return { status: 'No timestamp data available' } if history.empty?
    
    # This would require timestamps from transaction data
    # Simplified analysis
    {
      analysis_period: "Last #{history.length} transactions",
      pattern_detected: "Regular activity", # Simplified
      active_hours: "Analysis requires timestamp data"
    }
  end
  
  # Helper methods
  def detect_bot_patterns(history)
    # Simplified bot detection - look for very regular intervals or patterns
    return false if history.length < 10
    
    # Check for regular gas prices (bots often use fixed gas prices)
    gas_prices = history.map { |tx| (tx['gasPrice'] || '0x0').to_i(16) }.reject(&:zero?)
    return false if gas_prices.empty?
    
    # If more than 80% of transactions use the same gas price, likely a bot
    most_common_gas = gas_prices.group_by(&:itself).values.max_by(&:length)
    (most_common_gas.length.to_f / gas_prices.length) > BOT_PATTERN_THRESHOLD
  end
  
  def calculate_avg_gas_price(history)
    gas_prices = history.map { |tx| (tx['gasPrice'] || '0x0').to_i(16) }.reject(&:zero?)
    return 0 if gas_prices.empty?
    
    (gas_prices.sum / gas_prices.length / 1e9).round(2) # Return in Gwei
  end
  
  def find_most_active_period(history)
    # Simplified - would need timestamp analysis
    "Analysis requires timestamp data"
  end
  
  def analyze_interaction_patterns(history)
    contract_calls = history.count { |tx| tx['input'] && tx['input'] != '0x' }
    simple_transfers = history.length - contract_calls
    
    {
      contract_interactions: contract_calls,
      simple_transfers: simple_transfers,
      interaction_ratio: contract_calls.to_f / history.length
    }
  end
  
  def has_suspicious_patterns?(history)
    # Simplified suspicious pattern detection
    return false if history.length < 10
    
    # Check for identical transaction values (could indicate automated behavior)
    values = history.map { |tx| tx['value'] }
    most_common_value = values.group_by(&:itself).values.max_by(&:length)
    (most_common_value.length.to_f / values.length) > 0.7
  end
  
  def estimate_address_age(history)
    # Would need timestamp data from transactions
    # Return placeholder
    30 # days
  end
  
  def determine_gas_strategy(gas_prices)
    variance = calculate_variance(gas_prices)
    avg = gas_prices.sum / gas_prices.length
    
    if variance < (avg * 0.1) # Low variance
      'consistent'
    elsif gas_prices.max > (avg * 2) # Some very high gas prices
      'aggressive_when_needed'
    else
      'market_adaptive'
    end
  end
  
  def calculate_variance(array)
    return 0 if array.length < 2
    
    mean = array.sum.to_f / array.length
    sum_of_squares = array.map { |x| (x - mean) ** 2 }.sum
    sum_of_squares / array.length
  end
  
  def rpc_call(method, params)
    uri = URI(ETHEREUM_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10
    
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{BEARER_TOKEN}"
    request['Content-Type'] = 'application/json'
    request['User-Agent'] = 'ChainFetch-AddressAnalyzer/1.0'
    
    rpc_request = {
      jsonrpc: '2.0',
      method: method,
      params: params,
      id: 1
    }
    
    request.body = rpc_request.to_json
    response = http.request(request)
    
    result = JSON.parse(response.body)
    result['result']
  rescue => e
    Rails.logger.error "❌ RPC call error: #{e.message}"
    nil
  end
end 