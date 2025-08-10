require 'bigdecimal'
require 'time'
require 'set'

class Ethereum::TransactionSummaryService < Ethereum::BaseService
  attr_reader :transaction_data
  CURRENT_DATE = Time.now

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

    # --- Part 2: Classification Information ---
    from_info = info['from'] || {}
    to_info = info['to'] || {}
    
    service_category = classify_service_category(from_info, to_info)
    if service_category != 'Unknown'
      parts << "This transaction operates within the #{service_category} ecosystem and represents a #{service_category.downcase} protocol interaction."
    end

    protocol = classify_protocol(to_info)
    if protocol
      parts << "The transaction was executed through #{protocol}, utilizing this specific decentralized finance protocol for the operation."
    end

    action = classify_action(info)
    if action != 'Unknown'
      case action.downcase
      when /swap/
        parts << "This represents a token swap operation where users exchange one cryptocurrency asset for another through automated market makers."
      when /transfer/
        parts << "This is a direct transfer operation moving digital assets from one wallet address to another on the blockchain."
      when /deposit|supply/
        parts << "This involves supplying or depositing cryptocurrency assets into a DeFi protocol to earn yield or provide liquidity."
      when /borrow/
        parts << "This is a borrowing transaction where the user takes out a loan against their collateral in a lending protocol."
      when /withdraw|repay/
        parts << "This represents a withdrawal or repayment operation, either removing assets from a protocol or paying back borrowed funds."
      when /approval/
        parts << "This is a token approval transaction that grants permission for a smart contract to spend tokens on behalf of the user."
      when /claim/
        parts << "This is a reward claiming transaction where the user collects earned tokens, fees, or incentives from a DeFi protocol."
      else
        parts << "The transaction performs a #{action.downcase} operation within the decentralized finance ecosystem."
      end
    end

    outcome_info = classify_outcome(info)
    case outcome_info[:level].downcase
    when /success/
      parts << "The transaction executed successfully and completed all intended operations without any errors or reverts."
    when /partial/
      parts << "The transaction completed with partial success, meaning the main operation succeeded but some internal calls failed."
    when /failure/
      parts << "The transaction failed to execute properly and was reverted, meaning no state changes were applied to the blockchain."
    end

    risk_info = classify_risk(info, from_info, to_info, data)
    case risk_info[:level].downcase
    when /high/
      parts << "This transaction carries high risk due to potential security concerns, scam addresses, or suspicious activity patterns."
    when /medium/
      parts << "This transaction has medium complexity and risk, involving multiple smart contract interactions or sophisticated DeFi operations."
    when /low/
      parts << "This is a low-risk transaction with standard operations and no known security concerns or complex interactions."
    end

    # Calculate value tier for classification (will be calculated again later for precise values)
    eth_value = to_eth(info['value'])
    # Quick estimate for early classification
    raw_transfers = data.fetch('token_transfers', {})
    token_transfers = raw_transfers.is_a?(Hash) ? raw_transfers.fetch('items', []) : []
    estimated_transfer_value = BigDecimal("0")
    
    token_transfers.each do |transfer|
      next unless transfer.is_a?(Hash)
      token = transfer['token']
      if token && token['exchange_rate'] && transfer['total']
        token_amount = to_eth(transfer['total']['value'], token['decimals'].to_i)
        usd_value = token_amount * BigDecimal(token['exchange_rate'].to_s)
        estimated_transfer_value += usd_value
      end
    end
    
    eth_exchange_rate = BigDecimal(info['historic_exchange_rate'] || info['exchange_rate'] || '0')
    eth_usd = eth_value * eth_exchange_rate
    estimated_total_usd = eth_usd + estimated_transfer_value
    value_tier_info = classify_value_tier(estimated_total_usd)
    case value_tier_info[:tier].downcase
    when /micro/
      parts << "This is a micro-scale transaction involving very small amounts under $100, typically representing tiny transfers, test transactions, or minimal DeFi interactions."
    when /low/
      parts << "This is a small-scale retail transaction with low monetary value ranging from $100 to $1,000, representing typical individual user activity and personal transfers."
    when /medium/
      parts << "This is a medium-scale transaction with moderate financial value between $1,000 and $10,000, indicating significant personal or small business financial activity."
    when /^high$/
      parts << "This is a high-value transaction with substantial monetary worth ranging from $10,000 to $100,000, representing major financial operations or institutional activity."
    when /very high/
      parts << "This is a very high-value transaction involving large sums between $100,000 and $1 million, typically associated with institutional trading, major liquidity operations, or significant corporate transfers."
    when /ultra/
      parts << "This is an ultra-high-value whale transaction exceeding $1 million, representing massive institutional operations, major protocol interactions, or significant market-moving activities."
    end
    parts << "The total estimated transaction value is approximately $#{estimated_total_usd.to_f.round(2)} USD across all transferred assets."

    # --- Part 3: Address and Identity Information ---
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
    else
      parts << "No ETH was transferred in this transaction."
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
    total_transfer_value = analyze_token_transfers(parts, data) || BigDecimal("0")



    # --- Part 6: Internal Transactions ---
    analyze_internal_transactions(parts, data)

    # --- Part 7: State Changes ---
    analyze_state_changes(parts, data)

    # --- Part 8: Security and Risk Analysis ---
    analyze_security_risks(parts, info, from_info, to_info)

    parts.join(' ')
  end

  # Analyze token transfers within the transaction (return total_transfer_value for value tier)
  def analyze_token_transfers(parts, data)
    raw_transfers = data.fetch('token_transfers', {})
    token_transfers = raw_transfers.is_a?(Hash) ? raw_transfers.fetch('items', []) : []

    return BigDecimal("0") unless token_transfers.any?
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
    total_transfer_value
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
        .map { |tag| tag['name'] if tag['name'].length > 1 } # Filter noisy
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

  # New: Classify service category (e.g., Credit for Aave, DEX for Uniswap)
  def classify_service_category(from_info, to_info)
    tags = (from_info.dig('metadata', 'tags') || []) + (to_info.dig('metadata', 'tags') || [])
    tag_names = tags.map { |t| t['name']&.downcase || '' }.compact
    if tag_names.any? { |n| n.include?('aave') || n.include?('compound') || n.include?('lending') }
      'Credit'
    elsif tag_names.any? { |n| n.include?('uniswap') || n.include?('dex') || n.include?('amm') }
      'DEX'
    elsif tag_names.any? { |n| n.include?('defi') }
      'DeFi'
    else
      'Unknown'
    end
  end

  # New: Classify protocol (e.g., Uniswap V3, Aave, 1inch)
  def classify_protocol(to_info)
    # First check metadata tags
    tags = to_info.dig('metadata', 'tags') || []
    protocols = tags.select { |t| t['tagType'] == 'protocol' || t['name']&.include?('Protocol') }
                    .map { |t| t['name'] if t['name'].length > 1 }
                    .compact
                    .first(3)
    
    return protocols.join(', ') if protocols.any?
    
    # Fallback to contract name analysis
    contract_name = to_info['name']&.downcase || ''
    address_hash = to_info['hash']&.downcase || ''
    
    case 
    when contract_name.include?('aggregationrouterv5') || address_hash == '0x1111111254eeb25477b68fb85ed929f73a960582'
      '1inch Protocol'
    when contract_name.include?('uniswap')
      'Uniswap Protocol'
    when contract_name.include?('aave')
      'Aave Protocol'
    when contract_name.include?('compound')
      'Compound Protocol'
    when contract_name.include?('curve')
      'Curve Protocol'
    when contract_name.include?('sushiswap')
      'SushiSwap Protocol'
    else
      nil
    end
  end

  # New: Classify action/method (common DeFi mappings)
  def classify_action(info)
    method = (info['decoded_input']&.dig('method_call') || info['method'] || '').downcase
    case method
    when /swap/
      'Token Swap'
    when /supply|deposit|mint/
      'Supply/Deposit'
    when /borrow/
      'Borrow'
    when /repay|redeem|withdraw/
      'Repay/Withdraw'
    when /transferfrom|transfer/
      'Transfer'
    when /flashloan/
      'Flash Loan'
    when /liquidate/
      'Liquidate'
    when /claim/
      'Claim Rewards'
    when /approve/
      'Token Approval'
    when /multicall/
      'Batch Transaction'
    else
      'Unknown'
    end
  end

  # New: Classify outcome
  def classify_outcome(info)
    if info['status'] == 'ok' && !info['has_error_in_internal_transactions']
      { level: 'Success', description: 'Fully successful execution' }
    elsif info['status'] == 'ok'
      { level: 'Partial Success', description: 'Success with internal errors' }
    else
      { level: 'Failure', description: info['revert_reason'] || 'Execution failed' }
    end
  end

  # New: Classify risk/complexity (extended from security risks)
  def classify_risk(info, from_info, to_info, data)
    internal_count = data.fetch('internal_transactions', {})['items']&.length || 0
    if from_info['is_scam'] || to_info['is_scam'] || has_security_tag?(from_info, ['phish', 'hack']) || has_security_tag?(to_info, ['phish', 'hack'])
      { level: 'High', description: 'Potential scam or hack involvement' }
    elsif internal_count > 5 || info['method']&.downcase&.include?('flashloan') || info['method']&.downcase&.include?('leveraged')
      { level: 'Medium', description: 'Complex or high-risk method' }
    else
      { level: 'Low', description: 'No known risks' }
    end
  end

  # New: Classify value tier based on total USD
  def classify_value_tier(total_usd)
    case total_usd.to_f
    when 0...100
      { tier: 'Micro', description: 'micro volume transaction under $100, very small value transfer' }
    when 100...1000
      { tier: 'Low', description: 'low volume transaction ranging $100-$1,000, small retail transaction' }
    when 1000...10000
      { tier: 'Medium', description: 'medium volume transaction ranging $1,000-$10,000, moderate value transfer' }
    when 10000...100000
      { tier: 'High', description: 'high volume transaction ranging $10,000-$100,000, significant value transfer' }
    when 100000...1000000
      { tier: 'Very High', description: 'very high volume transaction ranging $100,000-$1M, large institutional transfer' }
    else
      { tier: 'Ultra-High', description: 'ultra high volume transaction exceeding $1M, whale-level massive value transfer' }
    end
  end
end