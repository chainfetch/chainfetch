require 'bigdecimal'
require 'time'
require 'set'

class Ethereum::AddressSummaryService < Ethereum::BaseService
  attr_reader :address_data

  def initialize(address_data)
    @address_data = address_data || {}
  end

  def call
    generate_text_representation(@address_data)
  rescue => e
    address_hash = @address_data.dig('info', 'hash') || 'unknown'
    puts "Error generating text for address #{address_hash}: #{e.message}"
    puts e.backtrace
    nil
  end

  private

  # This is our main feature engineering function, using your precise logic.
  def generate_text_representation(data)
    data ||= {}
    parts = []

    # --- Part 1: Core Identity & High-Level Stats ---
    info = data.fetch('info', {})
    counters = data.fetch('counters', {})

    address_type = info['is_contract'] ? "a smart contract" : "a standard EOA (Externally Owned Account)"
    parts << "Address #{info['hash']} is #{address_type}."
    
    parts << "It is known as '#{info['name']}'." if info['name']
    parts << "It is associated with the ENS name '#{info['ens_domain_name']}'." if info['ens_domain_name']

    eth_balance = to_eth(info['coin_balance'])
    parts << "It currently holds #{eth_balance.to_f.round(6)} ETH."
    
    parts << "Warning: This address has been flagged as a potential scam." if info['is_scam']
    parts << "It has public tags including: #{info['public_tags'].join(', ')}." if info['public_tags']&.any?
    parts << "The address has executed #{counters['transactions_count']} transactions and been involved in #{counters['token_transfers_count']} token transfers."

    # --- Part 2: Aggregate & Summarize Transaction Behavior ---
    raw_transactions = data.fetch('transactions', [])
    transactions = raw_transactions.is_a?(Hash) ? raw_transactions.fetch('items', []) : raw_transactions
    transactions ||= []

    if transactions.any?
      total_sent = BigDecimal("0")
      total_received = BigDecimal("0")
      sent_count = 0
      received_count = 0
      unique_counterparties = Set.new
      
      transactions.each do |tx|
        next unless tx.is_a?(Hash)
        
        from_hash = tx.is_a?(Hash) && tx['from'].is_a?(Hash) ? tx['from']['hash'] : nil
        to_hash = tx.is_a?(Hash) && tx['to'].is_a?(Hash) ? tx['to']['hash'] : nil
        tx_value = tx.is_a?(Hash) ? tx['value'] : nil
        
        if from_hash&.casecmp(info['hash'])&.zero?
          sent_count += 1
          total_sent += to_eth(tx_value)
          unique_counterparties.add(to_hash) if to_hash
        elsif to_hash&.casecmp(info['hash'])&.zero?
          received_count += 1
          total_received += to_eth(tx_value)
          unique_counterparties.add(from_hash) if from_hash
        end
      end
      
      if transactions.any? && transactions.first.is_a?(Hash) && transactions.last.is_a?(Hash)
        first_timestamp = transactions.last['timestamp']
        last_timestamp = transactions.first['timestamp']
        
        if first_timestamp && last_timestamp
          first_tx_time = Time.parse(first_timestamp)
          last_tx_time = Time.parse(last_timestamp)
          active_days = ((last_tx_time - first_tx_time) / (3600 * 24)).to_i
          parts << "Its transaction history spans over #{active_days} days."
        end
      end

      parts << "In total, it has sent #{total_sent.to_f.round(4)} ETH across #{sent_count} transactions and received #{total_received.to_f.round(4)} ETH from #{received_count} transactions."
      parts << "It has interacted with #{unique_counterparties.size} unique addresses."
    end
    
    # --- Part 3: Summarize Token Holdings and Activity ---
    token_balances = data.fetch('token_balances', [])
    if token_balances.any?
      held_tokens = token_balances.map do |t|
        t.is_a?(Hash) ? t.dig('token', 'name') || t.dig('token', 'symbol') : t
      end.compact
      parts << "Current token holdings include: #{held_tokens.first(5).join(', ')}." if held_tokens.any?
    end

    raw_transfers = data.fetch('token_transfers', [])
    token_transfers = raw_transfers.is_a?(Hash) ? raw_transfers.fetch('items', []) : raw_transfers
    token_transfers ||= []

    if token_transfers.any?
      transferred_tokens = token_transfers.map { |t| t.is_a?(Hash) ? t.dig('token', 'symbol') : nil }.compact.uniq
      parts << "It has actively transferred tokens such as #{transferred_tokens.first(6).join(', ')}." if transferred_tokens.any?

      # Correctly identify notable interactions - look at both "to" and "from" for protocol names
      protocol_names = Set.new
      token_transfers.each do |tx|
        if tx.is_a?(Hash)
          # Check if "to" has a name (protocol interaction when receiving)
          to_name = tx.dig('to', 'name')
          protocol_names.add(to_name) if to_name && !to_name.empty?
          
          # Check if "from" has a name (protocol interaction when sending)
          from_name = tx.dig('from', 'name')
          protocol_names.add(from_name) if from_name && !from_name.empty?
          
          # Extract protocol names from token names directly
          token_name = tx.dig('token', 'name')
          if token_name && !token_name.empty? && token_name != tx.dig('token', 'symbol')
            protocol_names.add(token_name)
          end
        end
      end
      
      if protocol_names.any?
        parts << "It has notably interacted with protocols like #{protocol_names.to_a.join(', ')}."
      end
    end

    parts.join(' ')
  end

  # A robust helper to safely access nested hash data.
  def safe_dig(hash, *keys)
    hash.is_a?(Hash) ? hash.dig(*keys) : nil
  end

  # Helper to safely convert Wei strings to a readable ETH BigDecimal
  def to_eth(wei_string, decimals = 18)
    return BigDecimal("0") if wei_string.nil?
    BigDecimal(wei_string) / (10**decimals)
  end
end