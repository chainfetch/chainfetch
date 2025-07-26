class BlockAnalyzerService
  require 'net/http'
  require 'json'
  
  ETHEREUM_URL = 'https://ethereum.chainfetch.app'
  BEARER_TOKEN = 'u82736GTDV28DME08HD87H3D3JHGD33ed'
  WHALE_THRESHOLD = 10 # ETH
  
  def initialize
    @decoder = ContractDecoderService.instance
  end
  
  def analyze_block(block_number)
    # Convert block number to hex if it's a string number
    block_hex = block_number.to_s.start_with?('0x') ? block_number : "0x#{block_number.to_i.to_s(16)}"
    
    # Fetch block data
    block_data = rpc_call('eth_getBlockByNumber', [block_hex, true])
    return { error: 'Block not found' } unless block_data
    
    {
      block: block_data,
      transactions: block_data['transactions'] || [],
      summary: calculate_summary(block_data),
      whale_transactions: find_whale_transactions(block_data['transactions'] || []),
      fee_analysis: analyze_fees(block_data),
      health_metrics: calculate_health_metrics(block_data)
    }
  end
  
  def get_block_summary(block_number)
    result = analyze_block(block_number)
    return result if result[:error]
    
    summary = result[:summary]
    {
      block_number: summary[:block_number],
      timestamp: summary[:timestamp],
      timestamp_utc: summary[:timestamp_utc],
      block_interval: summary[:block_interval],
      transaction_count: summary[:transaction_count],
      gas_used: summary[:gas_used],
      gas_limit: summary[:gas_limit],
      gas_usage_percentage: summary[:gas_usage_percentage],
      base_fee_gwei: summary[:base_fee_gwei],
      miner: summary[:miner],
      total_eth_value: summary[:total_eth_value]
    }
  end
  
  def get_block_transactions(block_number, filters = {})
    result = analyze_block(block_number)
    return result if result[:error]
    
    transactions = result[:transactions]
    
    # Apply filters
    if filters[:min_value]
      min_wei = (filters[:min_value].to_f * 1e18).to_i
      transactions = transactions.select { |tx| (tx['value'] || '0x0').to_i(16) >= min_wei }
    end
    
    if filters[:contract_only]
      transactions = transactions.select { |tx| tx['input'] && tx['input'] != '0x' }
    end
    
    # Analyze each transaction
    analyzed_transactions = transactions.map do |tx|
      analyze_transaction(tx)
    end
    
    {
      block_number: result[:block][:number],
      total_transactions: result[:transactions].length,
      filtered_transactions: analyzed_transactions.length,
      transactions: analyzed_transactions
    }
  end
  
  def get_whale_transactions(block_number)
    result = analyze_block(block_number)
    return result if result[:error]
    
    whale_txs = result[:whale_transactions]
    
    {
      block_number: result[:block][:number],
      whale_threshold: "#{WHALE_THRESHOLD} ETH",
      whale_count: whale_txs.length,
      total_whale_value: whale_txs.sum { |tx| tx[:value_eth] },
      transactions: whale_txs
    }
  end
  
  def get_fee_analysis(block_number)
    result = analyze_block(block_number)
    return result if result[:error]
    
    result[:fee_analysis]
  end
  
  def get_health_metrics(block_number)
    result = analyze_block(block_number)
    return result if result[:error]
    
    result[:health_metrics]
  end
  
  # =============================================================================
  # PHASE 2: SMART CONTRACT INTELLIGENCE
  # =============================================================================
  
  def get_defi_activity(block_number)
    result = analyze_block(block_number)
    return result if result[:error]
    
    transactions = result[:transactions]
    defi_analysis = analyze_defi_activity(transactions, block_number)
    
    {
      block_number: result[:block]['number'].to_i(16),
      defi_summary: defi_analysis[:summary],
      top_protocols: defi_analysis[:protocols],
      swap_activity: defi_analysis[:swaps],
      lending_activity: defi_analysis[:lending],
      total_defi_volume: defi_analysis[:total_volume]
    }
  end
  
  def get_nft_activity(block_number)
    result = analyze_block(block_number)
    return result if result[:error]
    
    transactions = result[:transactions]
    nft_analysis = analyze_nft_activity(transactions, block_number)
    
    {
      block_number: result[:block]['number'].to_i(16),
      nft_summary: nft_analysis[:summary],
      mints: nft_analysis[:mints],
      transfers: nft_analysis[:transfers],
      marketplaces: nft_analysis[:marketplaces],
      total_nft_volume: nft_analysis[:total_volume]
    }
  end
  
  def get_smart_contract_events(block_number)
    result = analyze_block(block_number)
    return result if result[:error]
    
    # Get transaction receipts to analyze events/logs
    events_analysis = analyze_smart_contract_events(result[:transactions], block_number)
    
    {
      block_number: result[:block]['number'].to_i(16),
      total_events: events_analysis[:total_events],
      event_categories: events_analysis[:categories],
      decoded_events: events_analysis[:decoded_events],
      top_contracts: events_analysis[:top_contracts]
    }
  end
  
  private
  
  def calculate_summary(block_data)
    timestamp = block_data['timestamp'].to_i(16)
    timestamp_utc = Time.at(timestamp).utc
    
    gas_used = block_data['gasUsed'].to_i(16)
    gas_limit = block_data['gasLimit'].to_i(16)
    gas_usage_percentage = (gas_used.to_f / gas_limit * 100).round(1)
    
    base_fee_wei = block_data['baseFeePerGas']&.to_i(16) || 0
    base_fee_gwei = (base_fee_wei / 1e9).round(2)
    
    transactions = block_data['transactions'] || []
    total_eth_value = transactions.sum do |tx|
      (tx['value'] || '0x0').to_i(16) / 1e18.to_f
    end
    
    # Calculate block interval (would need previous block for accurate calculation)
    block_interval = 12.0 # Default to 12 seconds, could fetch previous block for actual calculation
    
    {
      block_number: block_data['number'].to_i(16),
      timestamp: timestamp,
      timestamp_utc: timestamp_utc.strftime('%Y-%m-%d %H:%M:%S UTC'),
      block_interval: block_interval,
      transaction_count: transactions.length,
      gas_used: gas_used,
      gas_limit: gas_limit,
      gas_usage_percentage: gas_usage_percentage,
      base_fee_gwei: base_fee_gwei,
      miner: block_data['miner'],
      total_eth_value: total_eth_value.round(4)
    }
  end
  
  def find_whale_transactions(transactions)
    whale_threshold_wei = (WHALE_THRESHOLD * 1e18).to_i
    
    whale_txs = transactions.select do |tx|
      (tx['value'] || '0x0').to_i(16) >= whale_threshold_wei
    end
    
    whale_txs.map do |tx|
      value_eth = (tx['value'] || '0x0').to_i(16) / 1e18.to_f
      activity_type, contract_name = @decoder.decode_transaction(tx)
      
      {
        hash: tx['hash'],
        from: tx['from'],
        to: tx['to'],
        value_eth: value_eth.round(6),
        gas_price_gwei: ((tx['gasPrice'] || tx['maxFeePerGas'] || '0x0').to_i(16) / 1e9).round(2),
        activity_type: activity_type,
        contract_name: contract_name,
        input_data: (tx['input'] && tx['input'].length > 2) ? "#{tx['input'][0..10]}..." : nil
      }
    end
  end
  
  def analyze_fees(block_data)
    transactions = block_data['transactions'] || []
    base_fee_wei = block_data['baseFeePerGas']&.to_i(16) || 0
    base_fee_gwei = (base_fee_wei / 1e9).round(2)
    
    gas_prices = transactions.map do |tx|
      (tx['gasPrice'] || tx['maxFeePerGas'] || '0x0').to_i(16) / 1e9
    end.compact
    
    priority_fees = transactions.map do |tx|
      (tx['maxPriorityFeePerGas'] || '0x0').to_i(16) / 1e9
    end.compact
    
    total_gas_used = transactions.sum { |tx| (tx['gas'] || '0x0').to_i(16) }
    
    {
      base_fee_gwei: base_fee_gwei,
      avg_gas_price_gwei: gas_prices.empty? ? 0 : (gas_prices.sum / gas_prices.length).round(2),
      median_gas_price_gwei: gas_prices.empty? ? 0 : gas_prices.sort[gas_prices.length / 2].round(2),
      max_gas_price_gwei: gas_prices.empty? ? 0 : gas_prices.max.round(2),
      avg_priority_fee_gwei: priority_fees.empty? ? 0 : (priority_fees.sum / priority_fees.length).round(2),
      high_fee_transactions: transactions.count { |tx| (tx['maxFeePerGas'] || tx['gasPrice'] || '0x0').to_i(16) / 1e9 > 100 },
      total_gas_used: total_gas_used,
      estimated_total_fees_eth: (total_gas_used * base_fee_wei / 1e18.to_f).round(6)
    }
  end
  
  def calculate_health_metrics(block_data)
    gas_used = block_data['gasUsed'].to_i(16)
    gas_limit = block_data['gasLimit'].to_i(16)
    gas_usage_percentage = (gas_used.to_f / gas_limit * 100).round(1)
    
    transaction_count = (block_data['transactions'] || []).length
    
    # Network congestion indicators
    congestion_level = case gas_usage_percentage
                      when 0..30 then 'low'
                      when 31..70 then 'moderate'
                      when 71..90 then 'high'
                      else 'critical'
                      end
    
    {
      gas_usage_percentage: gas_usage_percentage,
      congestion_level: congestion_level,
      transaction_count: transaction_count,
      block_fullness: "#{gas_usage_percentage}%",
      network_status: congestion_level == 'critical' ? 'congested' : 'healthy',
      recommended_gas_price: calculate_recommended_gas_price(block_data)
    }
  end
  
  def calculate_recommended_gas_price(block_data)
    base_fee_wei = block_data['baseFeePerGas']&.to_i(16) || 0
    base_fee_gwei = base_fee_wei / 1e9
    
    # Simple recommendation: base fee + small priority
    recommended_gwei = (base_fee_gwei + 2).round(2)
    
    {
      base_fee_gwei: base_fee_gwei.round(2),
      recommended_gwei: recommended_gwei,
      fast_gwei: (recommended_gwei + 5).round(2)
    }
  end
  
  def analyze_transaction(tx)
    value_eth = (tx['value'] || '0x0').to_i(16) / 1e18.to_f
    gas_price_gwei = ((tx['gasPrice'] || tx['maxFeePerGas'] || '0x0').to_i(16) / 1e9).round(2)
    activity_type, contract_name = @decoder.decode_transaction(tx)
    
    {
      hash: tx['hash'],
      from: tx['from'],
      to: tx['to'],
      value_eth: value_eth.round(6),
      gas_price_gwei: gas_price_gwei,
      activity_type: activity_type,
      contract_name: contract_name,
      is_contract_interaction: tx['input'] && tx['input'] != '0x',
      is_eip1559: tx.key?('maxFeePerGas')
    }
  end
  
  def rpc_call(method, params)
    uri = URI(ETHEREUM_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10
    
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{BEARER_TOKEN}"
    request['Content-Type'] = 'application/json'
    request['User-Agent'] = 'ChainFetch-Analyzer/1.0'
    
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
  
  # =============================================================================
  # PHASE 2: ANALYSIS IMPLEMENTATIONS
  # =============================================================================
  
  def analyze_defi_activity(transactions, block_number)
    defi_txs = []
    protocols = Hash.new(0)
    swaps = []
    lending = []
    total_volume = 0
    
    transactions.each do |tx|
      activity_type, contract_name = @decoder.decode_transaction(tx)
      
      # Check if it's a DeFi transaction
      if is_defi_transaction?(tx, activity_type, contract_name)
        value_eth = (tx['value'] || '0x0').to_i(16) / 1e18.to_f
        
        defi_tx = {
          hash: tx['hash'],
          protocol: contract_name || 'Unknown',
          activity_type: activity_type,
          value_eth: value_eth.round(6),
          from: tx['from'],
          to: tx['to']
        }
        
        defi_txs << defi_tx
        protocols[contract_name || 'Unknown'] += 1
        total_volume += value_eth
        
        # Categorize by activity type
        if activity_type.to_s.include?('swap')
          swaps << defi_tx
        elsif activity_type.to_s.include?('lend') || activity_type.to_s.include?('borrow') || activity_type.to_s.include?('deposit')
          lending << defi_tx
        end
      end
    end
    
    {
      summary: {
        total_defi_transactions: defi_txs.length,
        unique_protocols: protocols.keys.length,
        swap_transactions: swaps.length,
        lending_transactions: lending.length
      },
      protocols: protocols.sort_by { |_, count| -count }.first(10).to_h,
      swaps: swaps.first(20),
      lending: lending.first(10),
      total_volume: total_volume.round(4)
    }
  end
  
  def analyze_nft_activity(transactions, block_number)
    nft_txs = []
    mints = []
    transfers = []
    marketplaces = Hash.new(0)
    total_volume = 0
    
    transactions.each do |tx|
      activity_type, contract_name = @decoder.decode_transaction(tx)
      
      # Check if it's an NFT transaction
      if is_nft_transaction?(tx, activity_type, contract_name)
        value_eth = (tx['value'] || '0x0').to_i(16) / 1e18.to_f
        
        nft_tx = {
          hash: tx['hash'],
          marketplace: contract_name || 'Direct Transfer',
          activity_type: activity_type,
          value_eth: value_eth.round(6),
          from: tx['from'],
          to: tx['to']
        }
        
        nft_txs << nft_tx
        total_volume += value_eth
        
        # Categorize by activity type
        if tx['from'] == '0x0000000000000000000000000000000000000000'
          mints << nft_tx
        else
          transfers << nft_tx
          marketplaces[contract_name || 'Direct Transfer'] += 1 if value_eth > 0
        end
      end
    end
    
    {
      summary: {
        total_nft_transactions: nft_txs.length,
        mints: mints.length,
        transfers: transfers.length,
        marketplaces_active: marketplaces.keys.length
      },
      mints: mints.first(10),
      transfers: transfers.first(20),
      marketplaces: marketplaces.sort_by { |_, count| -count }.first(5).to_h,
      total_volume: total_volume.round(4)
    }
  end
  
  def analyze_smart_contract_events(transactions, block_number)
    all_events = []
    event_categories = Hash.new(0)
    contract_activity = Hash.new(0)
    decoded_events = []
    
    # Sample a subset of transactions for event analysis (to avoid too many RPC calls)
    sample_transactions = transactions.sample([transactions.length, 50].min)
    
    sample_transactions.each do |tx|
      next unless tx['input'] && tx['input'] != '0x'
      
      # Get transaction receipt for events/logs
      receipt = get_transaction_receipt(tx['hash'])
      next unless receipt && receipt['logs']
      
      receipt['logs'].each do |log|
        next unless log['topics'] && log['topics'].any?
        
        event_signature = log['topics'][0]
        contract_address = log['address']
        
        # Decode known event signatures
        decoded_event = decode_event_signature(event_signature, log, tx)
        if decoded_event
          all_events << decoded_event
          decoded_events << decoded_event if decoded_events.length < 100
          event_categories[decoded_event[:category]] += 1
          contract_activity[contract_address] += 1
        end
      end
    end
    
    top_contracts = contract_activity.sort_by { |_, count| -count }.first(10).map do |addr, count|
      contract_name = @decoder.class::CONTRACTS[addr.downcase]&.dig(:name) || "#{addr[0..7]}...#{addr[-4..-1]}"
      { address: addr, name: contract_name, event_count: count }
    end
    
    {
      total_events: all_events.length,
      categories: event_categories,
      decoded_events: decoded_events.first(50),
      top_contracts: top_contracts
    }
  end
  
  def is_defi_transaction?(tx, activity_type, contract_name)
    return false unless tx['input'] && tx['input'] != '0x'
    
    # Check known DeFi protocols
    defi_contracts = @decoder.class::CONTRACTS.values.select { |c| c[:category] == 'DeFi' }
    defi_addresses = @decoder.class::CONTRACTS.select { |_, v| v[:category] == 'DeFi' }.keys
    
    defi_addresses.include?(tx['to']&.downcase) ||
      activity_type.to_s.include?('swap') ||
      activity_type.to_s.include?('lend') ||
      activity_type.to_s.include?('borrow') ||
      activity_type.to_s.include?('deposit') ||
      activity_type.to_s.include?('withdraw')
  end
  
  def is_nft_transaction?(tx, activity_type, contract_name)
    return false unless tx['input'] && tx['input'] != '0x'
    
    # Check known NFT marketplaces and contracts
    nft_contracts = @decoder.class::CONTRACTS.values.select { |c| c[:category] == 'NFT' }
    nft_addresses = @decoder.class::CONTRACTS.select { |_, v| v[:category] == 'NFT' }.keys
    
    nft_addresses.include?(tx['to']&.downcase) ||
      activity_type.to_s.include?('mint') ||
      activity_type.to_s.include?('transfer') ||
      contract_name.to_s.include?('OpenSea') ||
      contract_name.to_s.include?('Marketplace')
  end
  
  def get_transaction_receipt(tx_hash)
    rpc_call('eth_getTransactionReceipt', [tx_hash])
  rescue => e
    Rails.logger.error "❌ Receipt fetch error: #{e.message}"
    nil
  end
  
  def decode_event_signature(signature, log, tx)
    # Known event signatures
    event_signatures = {
      '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef' => {
        name: 'Transfer',
        category: 'Token',
        description: 'Token transfer (ERC-20/721/1155)'
      },
      '0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925' => {
        name: 'Approval',
        category: 'Token',
        description: 'Token approval'
      },
      '0xd78ad95fa46c994b6551d0da85fc275fe613ce37657fb8d5e3d130840159d822' => {
        name: 'Swap',
        category: 'DeFi',
        description: 'Uniswap V2 token swap'
      },
      '0xc42079f94a6350d7e6235f29174924f928cc2ac818eb64fed8004e115fbcca67' => {
        name: 'Swap',
        category: 'DeFi', 
        description: 'Uniswap V3 token swap'
      }
    }
    
    if event_info = event_signatures[signature]
      {
        signature: signature,
        name: event_info[:name],
        category: event_info[:category],
        description: event_info[:description],
        contract_address: log['address'],
        transaction_hash: tx['hash'],
        topics: log['topics'],
        data: log['data']
      }
    end
  end
end 