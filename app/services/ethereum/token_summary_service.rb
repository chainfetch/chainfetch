require 'bigdecimal'
require 'time'
require 'set'

class Ethereum::TokenSummaryService < Ethereum::BaseService
  attr_reader :token_data
  CURRENT_DATE = Time.now

  def initialize(token_data)
    @token_data = token_data || {}
  end

  def call
    generate_text_representation(@token_data)
  rescue => e
    token_address = @token_data.dig('info', 'address') || 'unknown'
    puts "Error generating text for token #{token_address}: #{e.message}"
    puts e.backtrace
    nil
  end

  private

  # Generate comprehensive narrative summary optimized for semantic search
  def generate_text_representation(data)
    data ||= {}
    parts = []
    
    # --- Part 1: Core Token Identity & Basic Properties ---
    info = data.fetch('info', {})
    counters = data.fetch('counters', {})
    
    token_name = info['name'] || 'Unknown Token'
    token_symbol = info['symbol'] || 'N/A'
    token_address = info['address'] || info['address_hash']
    token_type = info['type'] || 'Unknown'
    
    parts << "#{token_name} (#{token_symbol}) is a #{token_type} token deployed at address #{token_address}."
    
    # Market metrics and scale
    if info['holders_count'] || info['holders']
      holder_count = (info['holders_count'] || info['holders']).to_i
      holder_tier = classify_holder_tier(holder_count)
      parts << "The token has #{holder_count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} holders, placing it in the '#{holder_tier[:tier]}' category (#{holder_tier[:description]})."
    end
    
    # Token economics and supply
    if info['total_supply']
      total_supply = BigDecimal(info['total_supply'])
      decimals = info['decimals']&.to_i || 18
      human_supply = total_supply / (10**decimals)
      supply_scale = classify_supply_scale(human_supply)
      parts << "It has a total supply of #{format_large_number(human_supply)} tokens, representing a '#{supply_scale[:scale]}' supply model (#{supply_scale[:description]})."
    end
    
    # Market data and liquidity
    if info['exchange_rate']
      exchange_rate = BigDecimal(info['exchange_rate']).to_f
      if exchange_rate > 0
        parts << "The token is currently priced at $#{exchange_rate.round(6)} USD."
      end
    end
    
    if info['volume_24h']
      volume = BigDecimal(info['volume_24h']).to_f
      volume_tier = classify_volume_tier(volume)
      parts << "Daily trading volume stands at $#{format_large_number(volume)}, indicating '#{volume_tier[:tier]}' market activity (#{volume_tier[:description]})."
    end
    
    if info['circulating_market_cap']
      market_cap = BigDecimal(info['circulating_market_cap']).to_f
      cap_tier = classify_market_cap_tier(market_cap)
      parts << "With a circulating market capitalization of $#{format_large_number(market_cap)}, it ranks as a '#{cap_tier[:tier]}' asset (#{cap_tier[:description]})."
    end
    
    # --- Part 2: Transfer Activity and Network Effects ---
    transfers = data.fetch('transfers', {})
    transfer_items = transfers.is_a?(Hash) ? transfers.fetch('items', []) : transfers
    transfer_items ||= []
    
    if counters['transfers_count']
      transfer_count = counters['transfers_count'].to_i
      activity_level = classify_transfer_activity(transfer_count)
      parts << "The token has recorded #{transfer_count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} total transfers, demonstrating '#{activity_level[:level]}' network activity (#{activity_level[:description]})."
    end
    
    # Analyze recent transfer patterns
    if transfer_items.any?
      recent_transfers = transfer_items.first(50) # Analyze recent activity
      unique_senders = Set.new
      unique_receivers = Set.new
      large_transfers = 0
      total_transfer_value = BigDecimal("0")
      decimals = info['decimals']&.to_i || 18
      
      recent_transfers.each do |transfer|
        next unless transfer.is_a?(Hash)
        
        # Track unique participants
        from_hash = transfer.dig('from', 'hash')
        to_hash = transfer.dig('to', 'hash')
        unique_senders.add(from_hash) if from_hash
        unique_receivers.add(to_hash) if to_hash
        
        # Identify large transfers (simplified analysis)
        if transfer['value']
          transfer_value = BigDecimal(transfer['value']) / (10**decimals)
          total_transfer_value += transfer_value
          large_transfers += 1 if transfer_value > 1000 # Threshold for "large" transfers
        end
      end
      
      network_diversity = classify_network_diversity(unique_senders.size + unique_receivers.size)
      parts << "Recent transfer patterns show involvement of #{unique_senders.size + unique_receivers.size} unique addresses, indicating '#{network_diversity[:level]}' network diversity (#{network_diversity[:description]})."
      
      if large_transfers > 0
        parts << "Analysis reveals #{large_transfers} significant transfers among recent activity, suggesting institutional or whale participation."
      end
    end
    
    # --- Part 3: Ecosystem Integration and Protocol Interactions ---
    # Analyze transfer counterparties for protocol identification
    if transfer_items.any?
      protocol_interactions = Set.new
      exchange_interactions = Set.new
      defi_protocols = Set.new
      
      transfer_items.first(100).each do |transfer|
        next unless transfer.is_a?(Hash)
        
        # Analyze 'from' addresses for protocol names
        from_name = transfer.dig('from', 'name')
        if from_name && from_name.length > 1
          case from_name.downcase
          when /uniswap|sushiswap|pancakeswap|1inch|0x|kyber|curve|balancer/
            defi_protocols.add(from_name)
          when /binance|coinbase|kraken|okex|huobi|bitfinex|gate|ftx/
            exchange_interactions.add(from_name)
          else
            protocol_interactions.add(from_name) if from_name.length < 50 # Filter out very long names
          end
        end
        
        # Analyze 'to' addresses for protocol names
        to_name = transfer.dig('to', 'name')
        if to_name && to_name.length > 1
          case to_name.downcase
          when /uniswap|sushiswap|pancakeswap|1inch|0x|kyber|curve|balancer/
            defi_protocols.add(to_name)
          when /binance|coinbase|kraken|okex|huobi|bitfinex|gate|ftx/
            exchange_interactions.add(to_name)
          else
            protocol_interactions.add(to_name) if to_name.length < 50
          end
        end
        
        # Analyze metadata tags for additional context
        [transfer.dig('from', 'metadata', 'tags'), transfer.dig('to', 'metadata', 'tags')].compact.each do |tags|
          next unless tags.is_a?(Array)
          tags.each do |tag|
            next unless tag.is_a?(Hash)
            tag_name = tag['name']
            if tag_name
              case tag_name.downcase
              when /exchange|trading|cex/
                exchange_interactions.add(tag_name)
              when /defi|dex|liquidity|yield|farming|staking|protocol/
                defi_protocols.add(tag_name)
              end
            end
          end
        end
      end
      
      if defi_protocols.any?
        parts << "The token demonstrates significant DeFi ecosystem integration, with active interactions across protocols including #{defi_protocols.to_a.first(8).join(', ')}."
      end
      
      if exchange_interactions.any?
        parts << "Centralized exchange activity is evident through platforms such as #{exchange_interactions.to_a.first(6).join(', ')}, indicating institutional trading support."
      end
      
      if protocol_interactions.any?
        parts << "Additional protocol interactions include #{protocol_interactions.to_a.first(8).join(', ')}, showcasing broader ecosystem utility."
      end
    end
    
    # --- Part 4: Risk Assessment and Notable Patterns ---
    risk_factors = []
    
    # Analyze transfer patterns for potential risk indicators
    if transfer_items.any?
      suspicious_patterns = 0
      blocked_addresses = 0
      
      transfer_items.first(50).each do |transfer|
        next unless transfer.is_a?(Hash)
        
        # Check for metadata indicating blocked or flagged addresses
        [transfer.dig('from', 'metadata'), transfer.dig('to', 'metadata')].compact.each do |metadata|
          next unless metadata.is_a?(Hash)
          tags = metadata['tags']
          next unless tags.is_a?(Array)
          
          tags.each do |tag|
            next unless tag.is_a?(Hash)
            tag_name = tag['name']&.downcase || ''
            tag_type = tag['tagType']&.downcase || ''
            
            if tag_name.include?('blocked') || tag_name.include?('phish') || tag_name.include?('hack') || tag_name.include?('exploit')
              suspicious_patterns += 1
            end
            
            if tag_name.include?('blocked')
              blocked_addresses += 1
            end
          end
        end
      end
      
      if suspicious_patterns > 0
        risk_factors << "#{suspicious_patterns} transfers involve addresses flagged for suspicious activity"
      end
      
      if blocked_addresses > 0
        risk_factors << "#{blocked_addresses} transfers involve blocked addresses"
      end
    end
    
    if risk_factors.any?
      parts << "Risk assessment reveals: #{risk_factors.join(', ')}."
    else
      parts << "Risk analysis shows no immediate red flags in recent transfer patterns."
    end
    
    # --- Part 5: Token Instance and Metadata (for NFTs/special tokens) ---
    instances = data.fetch('instances', {})
    instance_items = instances.is_a?(Hash) ? instances.fetch('items', []) : instances
    
    if instance_items&.any?
      parts << "The token collection includes #{instance_items.size} unique instances, indicating NFT or collectible functionality."
    end
    
    parts.join(' ')
  end

  # Helper method to format large numbers in human-readable format
  def format_large_number(number)
    case number
    when 0...1_000
      number.round(2).to_s
    when 1_000...1_000_000
      "#{(number / 1_000).round(1)}K"
    when 1_000_000...1_000_000_000
      "#{(number / 1_000_000).round(1)}M"
    when 1_000_000_000...1_000_000_000_000
      "#{(number / 1_000_000_000).round(1)}B"
    else
      "#{(number / 1_000_000_000_000).round(1)}T"
    end
  end

  # Classify holder count into meaningful tiers
  def classify_holder_tier(holder_count)
    case holder_count
    when 0...100
      { tier: "Niche Token", description: "Limited distribution, experimental or new project" }
    when 100...1_000
      { tier: "Emerging Token", description: "Growing community, early adoption phase" }
    when 1_000...10_000
      { tier: "Established Token", description: "Solid user base, proven utility" }
    when 10_000...100_000
      { tier: "Popular Token", description: "Widespread adoption, strong community" }
    when 100_000...1_000_000
      { tier: "Major Token", description: "Large-scale adoption, institutional presence" }
    else
      { tier: "Blue Chip Token", description: "Dominant market position, ecosystem cornerstone" }
    end
  end

  # Classify supply scale for tokenomics analysis
  def classify_supply_scale(supply)
    case supply.to_f
    when 0...1_000
      { scale: "Ultra-Low Supply", description: "Scarcity-based economics, potential store of value" }
    when 1_000...1_000_000
      { scale: "Low Supply", description: "Limited inflation, moderate scarcity" }
    when 1_000_000...1_000_000_000
      { scale: "Medium Supply", description: "Balanced tokenomics, utility-focused" }
    when 1_000_000_000...1_000_000_000_000
      { scale: "High Supply", description: "Abundant liquidity, microtransaction suitable" }
    else
      { scale: "Ultra-High Supply", description: "Inflationary model, potential yield token" }
    end
  end

  # Classify trading volume for liquidity assessment
  def classify_volume_tier(volume)
    case volume
    when 0...10_000
      { tier: "Low Liquidity", description: "Limited trading activity, higher slippage risk" }
    when 10_000...100_000
      { tier: "Moderate Liquidity", description: "Regular trading, suitable for small-medium trades" }
    when 100_000...1_000_000
      { tier: "Good Liquidity", description: "Active trading, low slippage for most trades" }
    when 1_000_000...10_000_000
      { tier: "High Liquidity", description: "Institutional-grade liquidity, tight spreads" }
    else
      { tier: "Ultra-High Liquidity", description: "Market-leading volume, minimal price impact" }
    end
  end

  # Classify market capitalization for size assessment
  def classify_market_cap_tier(market_cap)
    case market_cap
    when 0...1_000_000
      { tier: "Micro Cap", description: "High risk/reward, early stage project" }
    when 1_000_000...10_000_000
      { tier: "Small Cap", description: "Growing project, moderate risk" }
    when 10_000_000...100_000_000
      { tier: "Mid Cap", description: "Established project, balanced risk/reward" }
    when 100_000_000...1_000_000_000
      { tier: "Large Cap", description: "Major project, lower volatility" }
    else
      { tier: "Mega Cap", description: "Market leader, institutional-grade asset" }
    end
  end

  # Classify transfer activity level
  def classify_transfer_activity(transfer_count)
    case transfer_count
    when 0...1_000
      { level: "Low Activity", description: "Limited usage, possibly new or niche token" }
    when 1_000...10_000
      { level: "Moderate Activity", description: "Regular usage, growing adoption" }
    when 10_000...100_000
      { level: "High Activity", description: "Active ecosystem, widespread usage" }
    when 100_000...1_000_000
      { level: "Very High Activity", description: "Major token, extensive network effects" }
    else
      { level: "Ultra High Activity", description: "Dominant usage, ecosystem cornerstone" }
    end
  end

  # Classify network diversity based on unique addresses
  def classify_network_diversity(unique_addresses)
    case unique_addresses
    when 0...10
      { level: "Limited Diversity", description: "Concentrated activity, potential centralization" }
    when 10...50
      { level: "Moderate Diversity", description: "Balanced distribution, healthy ecosystem" }
    when 50...200
      { level: "High Diversity", description: "Broad participation, decentralized usage" }
    else
      { level: "Ultra High Diversity", description: "Extensive network effects, viral adoption" }
    end
  end
end