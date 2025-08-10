require 'bigdecimal'
require 'time'
require 'set'

class Ethereum::BlockSummaryService < Ethereum::BaseService
  attr_reader :block_data
  CURRENT_DATE = Time.now

  def initialize(block_data)
    @block_data = block_data || {}
  end

  def call
    generate_text_representation(@block_data)
  rescue => e
    block_hash = @block_data.dig('info', 'hash') || 'unknown'
    puts "Error generating text for block #{block_hash}: #{e.message}"
    puts e.backtrace
    nil
  end

  private

  # Generate comprehensive text representation of block data
  def generate_text_representation(data)
    data ||= {}
    parts = []
    # --- Part 1: Core Block Identity & Stats ---
    info = data.fetch('info', {})

    parts << "Block #{info['height']} (#{info['hash']}) was mined on #{format_timestamp(info['timestamp'])}."

    # Miner information
    miner = info['miner'] || {}
    miner_name = miner['name'] || miner['ens_domain_name'] || "unknown miner"
    parts << "It was mined by #{miner_name} (#{miner['hash']})."

    # --- Part 2: Block Classification Information ---
    # Early classification before detailed analysis
    raw_transactions = data.fetch('transactions', {})
    transactions = raw_transactions.is_a?(Hash) ? raw_transactions.fetch('items', []) : []
    
    # Calculate basic metrics for classification
    failed_txs = 0
    contract_creations = 0
    transaction_types = Set.new
    total_value_transferred = BigDecimal("0")
    
    transactions.each do |tx|
      next unless tx.is_a?(Hash)
      
      tx_value = tx['value']
      total_value_transferred += to_eth(tx_value) if tx_value
      
      failed_txs += 1 if tx['status'] != 'ok' && tx['result'] != 'success'
      contract_creations += 1 if tx['created_contract']
      
      if tx['transaction_types']&.any?
        tx['transaction_types'].each { |type| transaction_types.add(type) }
      end
    end

    # Add miner classification
    miner_classification = classify_miner(miner)
    if miner_classification != 'Unknown'
      parts << "This block was produced by a #{miner_classification.downcase} mining entity, representing the validator or mining pool responsible for block creation."
    end

    # Add congestion classification
    congestion_info = classify_congestion(info['gas_used_percentage'])
    case congestion_info[:level].downcase
    when /low/
      parts << "This block shows low network congestion with under-utilized gas capacity, indicating light transaction volume during this period."
    when /normal/
      parts << "This block demonstrates normal network activity with balanced gas usage, representing typical blockchain operation conditions."
    when /high/
      parts << "This block indicates high network congestion with near-maximum gas utilization, showing heavy transaction demand and potential fee pressure."
    end

    # Add value tier classification
    value_tier_info = classify_value_tier(total_value_transferred)
    case value_tier_info[:tier].downcase
    when /low/
      parts << "This is a low-value block with minimal ETH transfers under 100 ETH, representing routine small-scale transaction activity."
    when /medium/
      parts << "This is a medium-value block with moderate ETH transfers between 100-1,000 ETH, indicating significant but not exceptional economic activity."
    when /high/
      parts << "This is a high-value block with substantial ETH transfers exceeding 1,000 ETH, representing major economic transactions and significant value movement."
    end

    # Add block type classification
    block_type = classify_block_type(transaction_types, info['blob_transaction_count'] || 0, contract_creations, failed_txs)
    case block_type.downcase
    when /blob/
      parts << "This is a blob-heavy block containing significant data availability transactions, indicating high-throughput layer-2 scaling activity."
    when /deployment/
      parts << "This is a deployment-intensive block with numerous smart contract creations, showing active development and protocol deployment activity."
    when /failure/
      parts << "This is a high-failure block with an elevated rate of failed transactions, indicating network stress, gas estimation issues, or protocol conflicts."
    when /creation/
      parts << "This is a contract creation block featuring smart contract deployments, representing development and infrastructure expansion on the network."
    when /standard/
      parts << "This is a standard block containing typical transaction patterns with balanced activity across various operation types."
    end

    # Add risk classification
    risk_info = classify_block_risk(failed_txs, info['transactions_count'])
    case risk_info[:level].downcase
    when /low/
      parts << "This block carries low risk with successful transaction execution, indicating stable network conditions and reliable operations."
    when /medium/
      parts << "This block has medium risk with some transaction failures, suggesting moderate network stress or gas estimation challenges."
    when /high/
      parts << "This block presents high risk due to significant transaction failure rates, indicating network congestion, protocol issues, or adverse conditions."
    end

    # Basic block stats
    parts << "The block contains #{info['transactions_count']} transactions and #{info['withdrawals_count']} withdrawals."
    parts << "It has a size of #{format_bytes(info['size'])} and used #{format_gas_percentage(info['gas_used_percentage'])} of its gas limit."

    # Gas and fee information
    base_fee_eth = to_eth(info['base_fee_per_gas'], 9) # base fee is in gwei
    burnt_fees_eth = to_eth(info['burnt_fees'])
    total_fees_eth = to_eth(info['transaction_fees'])

    parts << "The base fee was #{base_fee_eth.to_f.round(2)} gwei with #{burnt_fees_eth.to_f.round(6)} ETH burnt."
    parts << "Total transaction fees were #{total_fees_eth.to_f.round(6)} ETH."

    # Blob data if present
    if info['blob_transaction_count'] && info['blob_transaction_count'] > 0
      blob_gas_price_eth = to_eth(info['blob_gas_price'], 9)
      parts << "The block included #{info['blob_transaction_count']} blob transactions using #{info['blob_gas_used']} blob gas at #{blob_gas_price_eth.to_f} gwei."
    end

    # --- Part 3: Transaction Analysis ---
    if transactions.any?
      successful_txs = 0
      contract_calls = 0
      unique_addresses = Set.new

      transactions.each do |tx|
        next unless tx.is_a?(Hash)

        # Count success/failure (reusing previous calculation)
        if tx['status'] == 'ok' || tx['result'] == 'success'
          successful_txs += 1
        end

        # Track address interactions
        from_hash = tx.dig('from', 'hash')
        to_hash = tx.dig('to', 'hash')
        unique_addresses.add(from_hash) if from_hash
        unique_addresses.add(to_hash) if to_hash

        # Check for contract interactions
        if tx.dig('to', 'is_contract')
          contract_calls += 1
        end
      end

      parts << "Across all transactions, #{total_value_transferred.to_f.round(6)} ETH was transferred."
      parts << "#{successful_txs} transactions succeeded and #{failed_txs} failed." if failed_txs > 0
      parts << "The block involved #{unique_addresses.size} unique addresses."

      if contract_calls > 0
        parts << "#{contract_calls} transactions were contract calls."
      end

      if contract_creations > 0
        parts << "#{contract_creations} new contracts were created."
      end

      if transaction_types.any?
        types_list = transaction_types.to_a.join(', ')
        parts << "Transaction types included: #{types_list}."
      end
    end

    # --- Part 4: Withdrawal Analysis ---
    raw_withdrawals = data.fetch('withdrawals', {})
    withdrawals = raw_withdrawals.is_a?(Hash) ? raw_withdrawals.fetch('items', []) : []

    if withdrawals.any?
      total_withdrawn = BigDecimal("0")
      validator_indices = Set.new

      withdrawals.each do |withdrawal|
        next unless withdrawal.is_a?(Hash)

        amount = withdrawal['amount']
        total_withdrawn += to_eth(amount) if amount

        validator_index = withdrawal['validator_index']
        validator_indices.add(validator_index) if validator_index
      end

      parts << "Withdrawals totaled #{total_withdrawn.to_f.round(6)} ETH from #{validator_indices.size} unique validators."
    end

    # --- Part 5: Network and Performance Metrics ---
    if info['gas_target_percentage']
      target_usage = info['gas_target_percentage'].round(2)
      parts << "Gas usage was #{target_usage}% of the target, indicating #{target_usage > 50 ? 'high' : 'normal'} network congestion."
    end

    if info['difficulty'] && info['difficulty'] != "0"
      parts << "The block had a difficulty of #{info['difficulty']}."
    end
    parts.join(' ')
  end

  # Helper to format timestamp
  def format_timestamp(timestamp_str)
    return "unknown time" unless timestamp_str
    Time.parse(timestamp_str).strftime("%B %d, %Y at %H:%M:%S UTC")
  rescue
    timestamp_str
  end

  # Helper to format bytes
  def format_bytes(bytes)
    return "0 bytes" unless bytes

    units = ['bytes', 'KB', 'MB', 'GB']
    size = bytes.to_f
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end

    "#{size.round(2)} #{units[unit_index]}"
  end

  # Helper to format gas percentage
  def format_gas_percentage(percentage)
    return "0%" unless percentage
    "#{percentage.round(2)}%"
  end

  # Helper to safely convert Wei strings to readable ETH BigDecimal
  def to_eth(wei_string, decimals = 18)
    return BigDecimal("0") if wei_string.nil? || wei_string.to_s.empty?
    BigDecimal(wei_string.to_s) / (10**decimals)
  end

  # Helper to safely access nested hash data
  def safe_dig(hash, *keys)
    hash.is_a?(Hash) ? hash.dig(*keys) : nil
  end

  # New: Classify miner based on tags
  def classify_miner(miner)
    tags = miner.dig('metadata', 'tags') || miner['public_tags'] || []
    if tags.any?
      tags.map { |t| t.is_a?(Hash) ? t['name'] : t }.join(', ')
    else
      'Unknown'
    end
  end

  # New: Classify congestion level
  def classify_congestion(gas_used_percentage)
    percentage = gas_used_percentage.to_f
    case percentage
    when 0...30
      { level: 'Low', description: 'Under-utilized block' }
    when 30...70
      { level: 'Normal', description: 'Balanced network activity' }
    else
      { level: 'High', description: 'Congested network' }
    end
  end

  # New: Classify block value tier (total ETH transferred)
  def classify_value_tier(total_eth)
    eth = total_eth.to_f
    case eth
    when 0...100
      { tier: 'Low', description: '< 100 ETH transferred' }
    when 100...1000
      { tier: 'Medium', description: '100 - 1,000 ETH transferred' }
    else
      { tier: 'High', description: '> 1,000 ETH transferred' }
    end
  end

  # New: Classify block type based on contents
  def classify_block_type(transaction_types, blob_count, contract_creations, failed_txs)
    if blob_count > 0
      'Blob-Heavy'
    elsif contract_creations > 5
      'Deployment-Intensive'
    elsif failed_txs > (transaction_types.size * 0.1)
      'High-Failure'
    elsif transaction_types.include?('contract_creation')
      'Contract Creation Block'
    else
      'Standard'
    end
  end

  # New: Classify block risk (simple, based on failure rate)
  def classify_block_risk(failed_txs, total_txs)
    failure_rate = (failed_txs.to_f / total_txs) * 100
    case failure_rate
    when 0
      { level: 'Low', description: 'No failures' }
    when 0...10
      { level: 'Medium', description: 'Low failure rate' }
    else
      { level: 'High', description: 'High failure rate' }
    end
  end
end