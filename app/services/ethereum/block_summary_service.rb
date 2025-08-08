require 'bigdecimal'
require 'time'
require 'set'

class Ethereum::BlockSummaryService < Ethereum::BaseService
  attr_reader :block_data

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

    # --- Part 2: Transaction Analysis ---
    raw_transactions = data.fetch('transactions', {})
    transactions = raw_transactions.is_a?(Hash) ? raw_transactions.fetch('items', []) : []
    
    if transactions.any?
      total_value_transferred = BigDecimal("0")
      successful_txs = 0
      failed_txs = 0
      contract_calls = 0
      contract_creations = 0
      unique_addresses = Set.new
      transaction_types = Set.new
      
      transactions.each do |tx|
        next unless tx.is_a?(Hash)
        
        # Accumulate transaction value
        tx_value = tx['value']
        total_value_transferred += to_eth(tx_value) if tx_value
        
        # Count success/failure
        if tx['status'] == 'ok' || tx['result'] == 'success'
          successful_txs += 1
        else
          failed_txs += 1
        end
        
        # Track address interactions
        from_hash = tx.dig('from', 'hash')
        to_hash = tx.dig('to', 'hash')
        unique_addresses.add(from_hash) if from_hash
        unique_addresses.add(to_hash) if to_hash
        
        # Analyze transaction types
        if tx['transaction_types']&.any?
          tx['transaction_types'].each { |type| transaction_types.add(type) }
        end
        
        # Check for contract interactions
        if tx.dig('to', 'is_contract')
          contract_calls += 1
        end
        
        if tx['created_contract']
          contract_creations += 1
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

    # --- Part 3: Withdrawal Analysis ---
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

    # --- Part 4: Network and Performance Metrics ---
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
end
