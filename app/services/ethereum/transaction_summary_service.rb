require 'bigdecimal'
require 'time'
require 'set'

class Ethereum::TransactionSummaryService < Ethereum::BaseService
  attr_reader :transaction_data

  def initialize(transaction_data)
    @transaction_data = transaction_data || {}
  end

  def call
    generate_text_representation(@transaction_data)
  rescue => e
    tx_hash = @transaction_data.dig('info', 'hash') || 'unknown'
    puts "Error generating text for transaction #{tx_hash}: #{e.message}"
    puts e.backtrace
    nil
  end

  private

  # Generate comprehensive text representation of transaction data
  def generate_text_representation(data)
    data ||= {}
    parts = []

    # --- Part 1: Core Transaction Identity & Status ---
    info = data.fetch('info', {})
    
    parts << "Transaction #{info['hash']} was executed on #{format_timestamp(info['timestamp'])}."
    
    # Transaction status and result
    status_text = info['status'] == 'ok' ? 'successful' : 'failed'
    parts << "The transaction was #{status_text}."
    
    if info['revert_reason']
      parts << "It failed with reason: #{info['revert_reason']}."
    end

    # Basic transaction details
    parts << "It was included in block #{info['block_number']} at position #{info['position']}."
    parts << "The transaction has #{info['confirmations']} confirmations." if info['confirmations']

    # --- Part 2: Address and Identity Information ---
    from_info = info['from'] || {}
    to_info = info['to'] || {}

    # From address
    from_name = get_address_display_name(from_info)
    parts << "It was sent from #{from_name} (#{from_info['hash']})."
    
    # Add from address context
    if from_info['ens_domain_name']
      parts << "The sender is known by the ENS name #{from_info['ens_domain_name']}."
    end
    
    add_address_tags_info(parts, from_info, "sender")

    # To address
    to_name = get_address_display_name(to_info)
    contract_type = to_info['is_contract'] ? 'contract' : 'address'
    parts << "It was sent to the #{contract_type} #{to_name} (#{to_info['hash']})."
    
    if to_info['ens_domain_name']
      parts << "The recipient is known by the ENS name #{to_info['ens_domain_name']}."
    end
    
    add_address_tags_info(parts, to_info, "recipient")

    # --- Part 3: Value and Fee Analysis ---
    eth_value = to_eth(info['value'])
    if eth_value > 0
      parts << "The transaction transferred #{eth_value.to_f.round(6)} ETH."
    end

    # Gas and fee details
    gas_used = info['gas_used']
    gas_limit = info['gas_limit']
    if gas_used && gas_limit
      gas_efficiency = (gas_used.to_f / gas_limit.to_f * 100).round(2)
      parts << "It used #{format_number(gas_used)} gas out of #{format_number(gas_limit)} limit (#{gas_efficiency}% efficiency)."
    end

    # Fee breakdown
    if info['fee']
      fee_eth = to_eth(info['fee']['value'])
      parts << "The total transaction fee was #{fee_eth.to_f.round(6)} ETH."
    end

    if info['transaction_burnt_fee']
      burnt_fee_eth = to_eth(info['transaction_burnt_fee'])
      parts << "Of this, #{burnt_fee_eth.to_f.round(6)} ETH was burnt as the base fee."
    end

    if info['priority_fee']
      priority_fee_eth = to_eth(info['priority_fee'])
      parts << "The priority fee was #{priority_fee_eth.to_f.round(6)} ETH."
    end

    # Gas price information
    if info['gas_price']
      gas_price_gwei = to_eth(info['gas_price'], 9)
      parts << "The gas price was #{gas_price_gwei.to_f.round(2)} gwei."
    end

    # --- Part 4: Transaction Type and Method ---
    if info['transaction_types']&.any?
      types_list = info['transaction_types'].join(', ')
      parts << "This transaction involved: #{types_list}."
    end

    if info['method']
      method_name = info['decoded_input']&.dig('method_call') || info['method']
      parts << "It called the #{method_name} method." if method_name != info['method']
    end

    if info['transaction_tag']
      parts << "It has been tagged as: #{info['transaction_tag']}."
    end

    # --- Part 5: Token Transfer Analysis ---
    analyze_token_transfers(parts, data)

    # --- Part 6: Internal Transactions ---
    analyze_internal_transactions(parts, data)

    # --- Part 7: State Changes ---
    analyze_state_changes(parts, data)

    # --- Part 8: Security and Risk Analysis ---
    analyze_security_risks(parts, info, from_info, to_info)

    parts.join(' ')
  end

  # Analyze token transfers within the transaction
  def analyze_token_transfers(parts, data)
    raw_transfers = data.fetch('token_transfers', {})
    token_transfers = raw_transfers.is_a?(Hash) ? raw_transfers.fetch('items', []) : []
    
    return unless token_transfers.any?

    total_transfers = token_transfers.length
    parts << "The transaction included #{total_transfers} token transfer#{total_transfers > 1 ? 's' : ''}."

    # Analyze transferred tokens
    transferred_tokens = Set.new
    total_transfer_value = BigDecimal("0")

    token_transfers.each do |transfer|
      next unless transfer.is_a?(Hash)
      
      token = transfer['token']
      if token && token['symbol']
        transferred_tokens.add(token['symbol'])
        
        # Calculate USD value if available
        if token['exchange_rate'] && transfer['total']
          token_amount = to_eth(transfer['total']['value'], token['decimals'].to_i)
          usd_value = token_amount * BigDecimal(token['exchange_rate'].to_s)
          total_transfer_value += usd_value
        end
      end
    end

    if transferred_tokens.any?
      parts << "Tokens transferred include: #{transferred_tokens.to_a.join(', ')}."
    end

    if total_transfer_value > 0
      parts << "The estimated total value of token transfers was $#{total_transfer_value.to_f.round(2)}."
    end
  end

  # Analyze internal transactions
  def analyze_internal_transactions(parts, data)
    raw_internal = data.fetch('internal_transactions', {})
    internal_txs = raw_internal.is_a?(Hash) ? raw_internal.fetch('items', []) : []
    
    return unless internal_txs.any?

    successful_internal = internal_txs.count { |tx| tx['success'] }
    failed_internal = internal_txs.length - successful_internal

    parts << "It triggered #{internal_txs.length} internal transaction#{internal_txs.length > 1 ? 's' : ''}."
    
    if failed_internal > 0
      parts << "#{failed_internal} internal transaction#{failed_internal > 1 ? 's' : ''} failed."
    end

    # Check for contract creation
    created_contracts = internal_txs.select { |tx| tx['created_contract'] }
    if created_contracts.any?
      parts << "#{created_contracts.length} new contract#{created_contracts.length > 1 ? 's were' : ' was'} created."
    end
  end

  # Analyze state changes
  def analyze_state_changes(parts, data)
    raw_changes = data.fetch('state_changes', {})
    state_changes = raw_changes.is_a?(Hash) ? raw_changes.fetch('items', []) : []
    
    return unless state_changes.any?

    eth_changes = state_changes.select { |change| change['type'] == 'coin' }
    token_changes = state_changes.select { |change| change['type'] == 'token' }

    if eth_changes.any?
      affected_addresses = eth_changes.length
      parts << "The transaction affected ETH balances of #{affected_addresses} address#{affected_addresses > 1 ? 'es' : ''}."
    end

    if token_changes.any?
      affected_token_addresses = token_changes.length
      parts << "Token balances were modified for #{affected_token_addresses} address#{affected_token_addresses > 1 ? 'es' : ''}."
    end
  end

  # Analyze security risks and warnings
  def analyze_security_risks(parts, info, from_info, to_info)
    risks = []

    # Check for scam addresses
    if from_info['is_scam']
      risks << "the sender is flagged as a scam address"
    end

    if to_info['is_scam']
      risks << "the recipient is flagged as a scam address"
    end

    # Check for phishing/hack tags
    [from_info, to_info].each do |addr_info|
      if has_security_tag?(addr_info, ['phish', 'hack', 'drainer'])
        risks << "involves addresses associated with phishing or hacking activities"
        break
      end
    end

    # Check transaction tag for security warnings
    if info['transaction_tag']&.downcase&.include?('phish')
      risks << "has been tagged as potentially malicious"
    end

    if risks.any?
      parts << "⚠️ Security warning: This transaction #{risks.join(' and ')}."
    end
  end

  # Check if address has security-related tags
  def has_security_tag?(addr_info, security_keywords)
    return false unless addr_info.dig('metadata', 'tags')

    addr_info['metadata']['tags'].any? do |tag|
      tag_name = tag['name']&.downcase || ''
      tag_slug = tag['slug']&.downcase || ''
      security_keywords.any? { |keyword| tag_name.include?(keyword) || tag_slug.include?(keyword) }
    end
  end

  # Add address tag information to summary
  def add_address_tags_info(parts, addr_info, role)
    return unless addr_info

    # Public tags
    if addr_info['public_tags']&.any?
      parts << "The #{role} has public tags: #{addr_info['public_tags'].join(', ')}."
    end

    # Notable metadata tags
    if addr_info.dig('metadata', 'tags')
      notable_tags = addr_info['metadata']['tags']
        .select { |tag| tag['tagType'] == 'protocol' || tag['tagType'] == 'name' }
        .map { |tag| tag['name'] }
        .compact
        .first(3)

      if notable_tags.any?
        parts << "The #{role} is associated with: #{notable_tags.join(', ')}."
      end
    end
  end

  # Get display name for an address
  def get_address_display_name(addr_info)
    return 'unknown address' unless addr_info

    addr_info['name'] || 
    addr_info['ens_domain_name'] || 
    addr_info.dig('metadata', 'tags')&.find { |tag| tag['tagType'] == 'name' }&.dig('name') ||
    'unnamed address'
  end

  # Helper to format timestamp
  def format_timestamp(timestamp_str)
    return "unknown time" unless timestamp_str
    Time.parse(timestamp_str).strftime("%B %d, %Y at %H:%M:%S UTC")
  rescue
    timestamp_str
  end

  # Helper to format large numbers with commas
  def format_number(number)
    return "0" unless number
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
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
