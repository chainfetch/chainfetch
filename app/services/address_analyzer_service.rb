require 'net/http'
require 'json'

class AddressAnalyzerService
  ETHEREUM_URL = 'https://ethereum.chainfetch.app'
  BEARER_TOKEN = 'u82736GTDV28DME08HD87H3D3JHGD33ed'
  ETHERSCAN_URL = 'https://api.etherscan.io/api'
  ETHERSCAN_API_KEY = Rails.application.credentials.etherscan_api_key

  # Classification thresholds
  WHALE_THRESHOLD = 100 # ETH
  HIGH_ACTIVITY_THRESHOLD = 100 # transactions per day
  BOT_PATTERN_THRESHOLD = 0.8 # similarity threshold for bot detection
  NEW_ADDRESS_AGE_DAYS = 7 # Days for considering address as new
  SMALL_TX_THRESHOLD = 0.001 # ETH for dusting
  MIXER_ADDRESSES = [ # Known Tornado Cash and other mixer addresses (lowercase)
    '0x910cbd523d972eb0a6f4cae4618ad62622b39dbf', # Tornado 10 ETH
    '0xa160cdab225685da1d56aa342ad8841c3b53f291', # Tornado 100 ETH
    '0xd4b88df4d29f5cedd6857912842cff3b20c8cfa3', # Tornado pool
    '0xfd8610d20aa15b7b2e3be39b396a1bc3516c7144', # Tornado pool
    '0x722122df12d4e14e13ac3b6895a86e84145b6967', # Tornado pool
    # Add more from OFAC list or known mixers
    '0xdd4c48c0b24039969fc16d1cdf626eab821d3384',
    '0xd90e2f925da726b50c4ed8d0fb90ad053324f31b',
    '0xd96f2b1c14db8458374d9aca76e26c3d18364307',
    '0x4736dcf1b7a3d580672cce6e7c65cd5cc9cfba9d',
    '0x00000000006c3852cbef3e08e8df289169ede581' # OpenSea Seaport, but not mixer; focus on Tornado
  ].freeze

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

    # Get recent transaction history
    limit = options['limit'] || 100
    transaction_history = options['include_history'] ? get_recent_transactions(address, limit) : []

    # Estimate age
    address_age_days = estimate_address_age(transaction_history, is_contract, address)

    analysis = {
      address: address,
      is_contract: is_contract,
      basic_info: {
        balance_eth: (balance / 1e18.to_f).round(6),
        transaction_count: transaction_count,
        address_type: is_contract ? 'Contract' : 'EOA (Externally Owned Account)',
        estimated_age_days: address_age_days
      },
      classification: classify_address(balance, transaction_count, transaction_history, is_contract, address_age_days),
      activity_analysis: analyze_activity_patterns(transaction_history),
      risk_assessment: assess_risk_factors(address, transaction_history, is_contract, address_age_days)
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
  end

  def get_transaction_count(address)
    result = rpc_call('eth_getTransactionCount', [address, 'latest'])
    result ? result.to_i(16) : 0
  end

  def get_address_code(address)
    rpc_call('eth_getCode', [address, 'latest'])
  end

  def get_recent_transactions(address, limit = 100)
    params = {
      module: 'account',
      action: 'txlist',
      address: address,
      startblock: 0,
      endblock: 'latest',
      page: 1,
      offset: limit,
      sort: 'desc',
      apikey: ETHERSCAN_API_KEY
    }
    response = etherscan_call(params)
    response ? response.map do |tx|
      {
        'hash' => tx['hash'],
        'from' => tx['from'],
        'to' => tx['to'],
        'value' => "0x#{tx['value'].to_i.to_s(16)}",
        'gasPrice' => "0x#{tx['gasPrice'].to_i.to_s(16)}",
        'gas' => "0x#{tx['gas'].to_i.to_s(16)}",
        'input' => tx['input'],
        'timestamp' => tx['timeStamp'].to_i
      }
    end : []
  rescue => e
    Rails.logger.error "❌ Etherscan tx fetch error: #{e.message}"
    []
  end

  def estimate_address_age(history, is_contract, address)
    if history.any?
      earliest_timestamp = history.min_by { |tx| tx['timestamp'] }['timestamp']
      current_time = Time.now.to_i
      age_seconds = current_time - earliest_timestamp
      (age_seconds / 86400.0).round(1) # days
    elsif is_contract
      # For contracts without history, fetch creation tx
      params = {
        module: 'contract',
        action: 'getcontractcreation',
        contractaddresses: address,
        apikey: ETHERSCAN_API_KEY
      }
      response = etherscan_call(params)
      if response && response.first
        tx_hash = response.first['txHash']
        tx = rpc_call('eth_getTransactionByHash', [tx_hash])
        if tx && tx['blockNumber']
          block = rpc_call('eth_getBlockByNumber', [tx['blockNumber'], false])
          block ? (Time.now.to_i - block['timestamp'].to_i(16)) / 86400.0 : 0
        else
          0
        end
      else
        0
      end
    else
      0 # Unknown
    end
  end

  def classify_address(balance, tx_count, history, is_contract, age_days)
    balance_eth = balance / 1e18.to_f
    classifications = []
    confidence = 0.5

    if balance_eth >= WHALE_THRESHOLD
      classifications << { type: 'whale', confidence: 0.9, reason: "Balance #{balance_eth.round(2)} ETH exceeds threshold" }
      confidence += 0.4
    end

    avg_daily_tx = tx_count / [age_days, 1].max
    if avg_daily_tx >= HIGH_ACTIVITY_THRESHOLD
      classifications << { type: 'high_activity', confidence: 0.8, reason: "#{tx_count} tx over #{age_days} days" }
      confidence += 0.3
    end

    if is_contract
      contract_type = classify_contract_type(balance, tx_count, history)
      classifications << { type: contract_type, confidence: 0.7, reason: "Contract with #{contract_type} patterns" }
      confidence += 0.2
    end

    if history.any? && detect_bot_patterns(history)
      classifications << { type: 'bot', confidence: 0.6, reason: "Automated transaction patterns detected" }
      confidence += 0.1
    end

    if has_mixer_interactions(history)
      classifications << { type: 'mixer_user', confidence: 0.85, reason: "Interactions with known mixer contracts" }
      confidence += 0.3
    end

    primary_type = classifications.max_by { |c| c[:confidence] }&.[](:type) || 'regular_user'
    {
      primary_type: primary_type,
      all_classifications: classifications,
      confidence_score: [confidence / (classifications.length + 1), 0.95].min.round(2)
    }
  end

  def classify_contract_type(balance, tx_count, history)
    if has_mixer_interactions(history)
      'mixer_contract'
    elsif tx_count > 10000
      'popular_protocol'
    elsif balance > 1000 * 1e18
      'treasury_contract'
    elsif tx_count < 10
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

  def assess_risk_factors(address, history, is_contract, age_days)
    risk_factors = []
    risk_score = 0.0

    if history.any? && has_suspicious_patterns?(history)
      risk_factors << "Unusual transaction patterns detected"
      risk_score += 0.3
    end

    if age_days < NEW_ADDRESS_AGE_DAYS && (get_address_balance(address) / 1e18.to_f > 1 || history.length > 50)
      risk_factors << "High activity/value on new address"
      risk_score += 0.25
    end

    if is_contract && get_address_code(address).length < 100 # Short code might be suspicious
      risk_factors << "Potentially unverified or simple smart contract"
      risk_score += 0.15
    end

    if has_mixer_interactions(history)
      risk_factors << "Interactions with known mixer contracts (e.g., Tornado Cash)"
      risk_score += 0.4
    end

    if has_dusting_attacks(history)
      risk_factors << "Possible dusting attacks detected (many small incoming tx)"
      risk_score += 0.2
    end

    risk_level = case risk_score
                 when 0..0.2 then 'low'
                 when 0.21..0.5 then 'medium'
                 else 'high'
                 end

    {
      risk_level: risk_level,
      risk_score: risk_score.round(2),
      risk_factors: risk_factors
    }
  end

  def analyze_contract_interactions(history)
    contract_interactions = history.select { |tx| tx['to'] && tx['input'] != '0x' }

    {
      total_contract_calls: contract_interactions.length,
      unique_contracts: contract_interactions.map { |tx| tx['to'] }.uniq.length,
      top_contracts: contract_interactions.group_by { |tx| tx['to'] }
                           .transform_values(&:length)
                           .sort_by { |_, count| -count }
                           .first(5)
                           .map { |addr, count| { address: addr, call_count: count } }
    }
  end

  def analyze_gas_patterns(history)
    gas_prices = history.map { |tx| tx['gasPrice'].to_i(16) }.reject(&:zero?)

    return { status: 'No gas data available' } if gas_prices.empty?

    {
      avg_gas_price_gwei: (gas_prices.sum / gas_prices.length.to_f / 1e9).round(2),
      min_gas_price_gwei: (gas_prices.min / 1e9).round(2),
      max_gas_price_gwei: (gas_prices.max / 1e9).round(2),
      gas_strategy: determine_gas_strategy(gas_prices)
    }
  end

  def analyze_value_patterns(history)
    values = history.map { |tx| tx['value'].to_i(16) }.reject(&:zero?)

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
    return { status: 'No timestamp data available' } if history.empty? || history.none? { |tx| tx['timestamp'] }

    timestamps = history.map { |tx| tx['timestamp'] }.sort
    intervals = timestamps.each_cons(2).map { |a, b| b - a }.reject(&:zero?)

    {
      active_hours: find_active_hours(timestamps),
      average_interval_seconds: intervals.any? ? (intervals.sum / intervals.length.to_f).round(2) : 0,
      pattern_detected: intervals.any? && calculate_variance(intervals) < 1000 ? 'regular' : 'irregular' # Low variance = regular
    }
  end

  # Helper methods
  def detect_bot_patterns(history)
    return false if history.length < 10

    gas_prices = history.map { |tx| tx['gasPrice'].to_i(16) }.reject(&:zero?)
    return false if gas_prices.empty?

    most_common_gas = gas_prices.tally.max_by { |_, count| count }[1]
    (most_common_gas.to_f / gas_prices.length) > BOT_PATTERN_THRESHOLD
  end

  def calculate_avg_gas_price(history)
    gas_prices = history.map { |tx| tx['gasPrice'].to_i(16) }.reject(&:zero?)
    return 0 if gas_prices.empty?

    (gas_prices.sum / gas_prices.length.to_f / 1e9).round(2) # Gwei
  end

  def find_most_active_period(history)
    return 'Unknown' if history.none? { |tx| tx['timestamp'] }

    hours = history.map { |tx| Time.at(tx['timestamp']).hour }.tally
    most_active_hour = hours.max_by { |_, count| count }[0]
    "#{most_active_hour}:00 - #{most_active_hour + 1}:00 UTC"
  end

  def analyze_interaction_patterns(history)
    contract_calls = history.count { |tx| tx['input'] && tx['input'] != '0x' }
    simple_transfers = history.length - contract_calls

    {
      contract_interactions: contract_calls,
      simple_transfers: simple_transfers,
      interaction_ratio: (contract_calls.to_f / [history.length, 1].max).round(2)
    }
  end

  def has_suspicious_patterns?(history)
    return false if history.length < 10

    values = history.map { |tx| tx['value'].to_i(16) }
    most_common_value = values.tally.max_by { |_, count| count }[1]
    (most_common_value.to_f / values.length) > 0.7
  end

  def has_mixer_interactions(history)
    history.any? { |tx| MIXER_ADDRESSES.include?(tx['to']&.downcase) || MIXER_ADDRESSES.include?(tx['from']&.downcase) }
  end

  def has_dusting_attacks(history)
    small_incoming = history.count { |tx| tx['to'].downcase == address.downcase && tx['value'].to_i(16) / 1e18.to_f < SMALL_TX_THRESHOLD && tx['from'] != address }
    small_incoming > 5 # Arbitrary threshold for suspicion
  end

  def find_active_hours(timestamps)
    hours = timestamps.map { |ts| Time.at(ts).hour }.tally
    top_hours = hours.sort_by { |_, count| -count }.first(3).map(&:first).join(', ')
    "Most active hours (UTC): #{top_hours}"
  end

  def determine_gas_strategy(gas_prices)
    variance = calculate_variance(gas_prices)
    avg = gas_prices.sum / gas_prices.length.to_f

    if variance < (avg * 0.1)
      'consistent'
    elsif gas_prices.max > (avg * 2)
      'aggressive_when_needed'
    else
      'market_adaptive'
    end
  end

  def calculate_variance(array)
    return 0 if array.length < 2

    mean = array.sum.to_f / array.length
    sum_of_squares = array.sum { |x| (x - mean)**2 }
    sum_of_squares / array.length
  end

  def etherscan_call(params)
    uri = URI(ETHERSCAN_URL)
    uri.query = URI.encode_www_form(params)
    response = Net::HTTP.get_response(uri)
    if response.is_a?(Net::HTTPSuccess)
      json = JSON.parse(response.body)
      json['status'] == '1' ? json['result'] : nil
    else
      nil
    end
  rescue => e
    Rails.logger.error "❌ Etherscan error: #{e.message}"
    nil
  end

  def rpc_call(method, params)
    uri = URI(ETHEREUM_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path)
    request['Authorization'] = "Bearer #{BEARER_TOKEN}"
    request['Content-Type'] = 'application/json'

    body = {
      jsonrpc: '2.0',
      method: method,
      params: params,
      id: 1
    }.to_json

    request.body = body
    response = http.request(request)
    JSON.parse(response.body)['result']
  rescue => e
    Rails.logger.error "❌ RPC error: #{e.message}"
    nil
  end
end