require 'async'
require 'async/websocket/client'
require 'async/http/endpoint'
require 'async/http/protocol'
require 'json'
require 'net/http'

class EthereumStreamService
  include Singleton

  def initialize
    @task = nil
    @ws = nil
    @running = false
    @block_count = 0
    @previous_block_timestamp = nil
  end

  def start
    return if @running

    @running = true
    Rails.logger.info "🚀 Starting Ethereum stream service..."
    
    @task = Async do |task|
      begin
        # Force HTTP/1.1 for WebSocket compatibility (discovered via debugging)
        endpoint = Async::HTTP::Endpoint.parse('wss://ethereum-ws.chainfetch.app', alpn_protocols: ['http/1.1'])
        # endpoint = Async::HTTP::Endpoint.parse('wss://ethereum-rpc.publicnode.com', alpn_protocols: ['http/1.1'])
        
        # Connect using the working configuration: basic connection, no special protocols
        Async::WebSocket::Client.connect(endpoint) do |ws|
          @ws = ws
          Rails.logger.info "✅ Connected to Ethereum WebSocket (async-websocket working!)"
          
          # Setup subscriptions
          setup_subscriptions
          
          # Handle incoming messages
          while @running && (message = ws.read)
            # Parse WebSocket message properly
            message_text = message.respond_to?(:buffer) ? message.buffer : message.to_s
            handle_message(JSON.parse(message_text))
          end
        end
        
      rescue => e
        Rails.logger.error "❌ Ethereum WebSocket error: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
        @running = false
        
        # Retry after 5 seconds
        if @running
          Rails.logger.info "🔄 Retrying connection in 5 seconds..."
          task.sleep(5)
          start
        end
      ensure
        @running = false
        Rails.logger.info "🔌 Ethereum WebSocket closed"
      end
    end
  end

  def stop
    Rails.logger.info "🛑 Stopping Ethereum stream service..."
    @running = false
    @ws&.close
    @task&.stop
  end

  def running?
    @running
  end

  private

  def setup_subscriptions
    # Get current block number (same as Node.js)
    send_message({
      jsonrpc: '2.0',
      method: 'eth_blockNumber',
      params: [],
      id: 1
    })
    
    # Subscribe to new blocks (same as Node.js)
    send_message({
      jsonrpc: '2.0',
      method: 'eth_subscribe',
      params: ['newHeads'],
      id: 2
    })
  end

  def send_message(data)
    if @ws && @running
      @ws.write(data.to_json)
      Rails.logger.debug "📤 Sent: #{data}"
    end
  rescue => e
    Rails.logger.error "❌ Error sending message: #{e.message}"
  end

  def handle_message(data)
    Rails.logger.debug "📥 Received: #{data}"
    
    case data['id']
    when 1
      # Current block number response (same as Node.js id: 1)
      if data['result']
        current_block = data['result'].to_i(16)
        Rails.logger.info "🎯 Current block: #{current_block}"
        
        # Broadcast via Turbo Stream
        Turbo::StreamsChannel.broadcast_update_to(
          "ethereum_data",
          target: "current-block-number",
          html: current_block.to_s
        )
      end
      
    when 2
      # New blocks subscription confirmation (same as Node.js id: 2)
      Rails.logger.info "🔔 New blocks subscription: #{data['result']}"
    end

    # Handle subscription data (same logic as Node.js)
    if data['method'] == 'eth_subscription'
      result = data.dig('params', 'result')
      
      # New block notification (same as Node.js checking result.number)
      if result&.key?('number')
        handle_new_block(result)
      end
    end

    # Handle block details response (same as Node.js block_ ID check)
    if data['id']&.to_s&.start_with?('block_') && data['result']&.key?('transactions')
      handle_block_details(data['result'])
    end

    # Handle errors
    if data['error']
      Rails.logger.error "❌ Ethereum RPC error: #{data['error']['message']}"
    end
  rescue => e
    Rails.logger.error "❌ Error handling message: #{e.message}"
    Rails.logger.debug "Message was: #{data.inspect}"
  end

  def handle_new_block(block_data)
    @block_count += 1
    block_num = block_data['number'].to_i(16)
    timestamp = Time.at(block_data['timestamp'].to_i(16))
    
    Rails.logger.info "🟢 NEW BLOCK: #{block_num}"
    
    # Get full block details with transactions (same as Node.js)
    send_message({
      jsonrpc: '2.0',
      method: 'eth_getBlockByNumber',
      params: [block_data['number'], true], # true = include full transaction objects
      id: "block_#{block_num}"
    })

    # Update block count via Turbo Stream
    Turbo::StreamsChannel.broadcast_update_to(
      "ethereum_data",
      target: "blocks-processed",
      html: @block_count.to_s
    )
    
    # Update current block number via Turbo Stream
    Turbo::StreamsChannel.broadcast_update_to(
      "ethereum_data",
      target: "current-block-number",
      html: block_num.to_s
    )
  rescue => e
    Rails.logger.error "❌ Error handling new block: #{e.message}"
  end

  def handle_block_details(block_data)
    block_num = block_data['number'].to_i(16)
    tx_count = block_data['transactions'].length
    
    # Convert hex timestamp to UTC time
    timestamp_hex = block_data['timestamp']
    timestamp_decimal = timestamp_hex.to_i(16)
    timestamp_utc = Time.at(timestamp_decimal).utc
    
    # Calculate block interval
    block_interval = nil
    if @previous_block_timestamp
      block_interval = timestamp_decimal - @previous_block_timestamp
    end
    @previous_block_timestamp = timestamp_decimal
    
    # Calculate gas usage and block fullness
    gas_used = block_data['gasUsed'].to_i(16)
    gas_limit = block_data['gasLimit'].to_i(16)
    gas_usage_percentage = (gas_used.to_f / gas_limit * 100).round(1)
    
    # Extract base fee (post-EIP-1559) and convert Wei to Gwei
    base_fee_wei = block_data['baseFeePerGas']&.to_i(16) || 0
    base_fee_gwei = (base_fee_wei / 1e9).round(2)
    
    # Extract miner/validator address (post-Merge this is the validator)
    miner_validator = block_data['miner']&.downcase
    validator_short = miner_validator ? "#{miner_validator[0..5]}...#{miner_validator[-4..-1]}" : "Unknown"
    
    # Get decoder instance for categorizing activities
    decoder = ContractDecoderService.instance
    
    # Calculate total ETH value and transaction stats (same as Node.js)
    total_value = 0.0
    large_transactions = 0
    max_transaction = 0.0
    
    block_data['transactions'].each do |tx|
      tx_value = tx['value'].to_i(16) / 1e18  # Convert Wei to ETH (same as Node.js)
      total_value += tx_value
      large_transactions += 1 if tx_value > 1.0
      max_transaction = [max_transaction, tx_value].max
    end

    # Decode DeFi and NFT activities
    activities = decoder.categorize_block_activities(block_data['transactions'])
    
    # Analyze smart contract events for interesting transactions
    event_insights = analyze_transaction_events(block_data['transactions'], block_num)

    # Update latest block ETH via Turbo Stream
    Turbo::StreamsChannel.broadcast_update_to(
      "ethereum_data",
      target: "latest-block-eth",
      html: "#{total_value.round(4)} ETH"
    )

    # Update activity statistics
    Turbo::StreamsChannel.broadcast_update_to(
      "ethereum_data",
      target: "defi-activities",
      html: activities[:defi_count].to_s
    )

    Turbo::StreamsChannel.broadcast_update_to(
      "ethereum_data",
      target: "nft-activities", 
      html: activities[:nft_count].to_s
    )

    Turbo::StreamsChannel.broadcast_update_to(
      "ethereum_data",
      target: "token-activities",
      html: activities[:token_count].to_s
    )

    # Add new block summary to the feed via Turbo Stream
    block_card_html = render_block_card(block_num, tx_count, total_value, large_transactions, max_transaction, timestamp_utc, activities, block_interval, gas_usage_percentage, base_fee_gwei, validator_short, event_insights)
    
    Turbo::StreamsChannel.broadcast_prepend_to(
      "ethereum_data",
      target: "block-summaries",
      html: block_card_html
    )

    # Enhanced logging with timestamp, gas usage, base fee, validator, and event analysis
    interval_info = block_interval ? " | #{sprintf('%.2f', block_interval)}s interval" : ""
    gas_info = " | #{gas_usage_percentage}% full"
    fee_info = " | #{base_fee_gwei}G base"
    validator_info = " | #{validator_short}"
    events_info = event_insights[:total_events] > 0 ? " | #{event_insights[:total_events]} events" : ""
    Rails.logger.info "💎 BLOCK #{block_num}: #{tx_count} txs | #{total_value.round(2)} ETH total | DeFi: #{activities[:defi_count]} | NFT: #{activities[:nft_count]}#{interval_info}#{gas_info}#{fee_info}#{validator_info}#{events_info} | UTC: #{timestamp_utc.strftime('%H:%M:%S')}"
  rescue => e
    Rails.logger.error "❌ Error handling block details: #{e.message}"
  end

  def render_block_card(block_num, tx_count, total_value, large_transactions, max_transaction, timestamp_utc, activities, block_interval = nil, gas_usage_percentage = nil, base_fee_gwei = nil, validator_short = nil, event_insights = nil)
    Rails.logger.debug "🔍 Rendering block card with #{activities[:top_activities].length} activities: #{activities[:top_activities].map { |a| a[:contract] }.join(', ')}"
    
    top_activities_html = activities[:top_activities].map do |activity|
      category_emoji = case activity[:category]
                      when 'DeFi' then '🔄'
                      when 'NFT' then '🖼️'  
                      when 'Token' then '🪙'
                      else '⚙️'
                      end
      
      Rails.logger.debug "🔍 Rendering activity: #{activity[:contract]} (#{activity[:type]}) - #{activity[:value]} ETH"
      
      "<div class=\"activity-item\">
        <span class=\"activity-type\">#{category_emoji} #{activity[:type]}</span>
        <span class=\"activity-contract\">#{activity[:contract]}</span>
        <span class=\"activity-value\">#{activity[:value]} ETH</span>
      </div>"
    end.join

    # Format timestamp with interval analysis
    timestamp_display = timestamp_utc.strftime("%H:%M:%S UTC")
    interval_html = ""
    if block_interval
      interval_color = case block_interval
                      when 0..8 then "fast"      # Faster than normal
                      when 9..15 then "normal"   # Normal Ethereum block time
                      when 16..30 then "slow"    # Slower than normal
                      else "very-slow"           # Very slow
                      end
      interval_html = "<div class=\"block-interval #{interval_color}\">⏱️ #{sprintf('%.2f', block_interval)}s interval</div>"
    end

    gas_info_html = ""
    if gas_usage_percentage
      gas_color = gas_usage_percentage > 90 ? "high-congestion" : (gas_usage_percentage > 70 ? "moderate-congestion" : "low-congestion")
      gas_info_html = "<div class=\"block-gas-info #{gas_color}\">⚡ #{gas_usage_percentage}% full</div>"
    end

    fee_info_html = ""
    if base_fee_gwei
      fee_color = base_fee_gwei > 5 ? "high-fee" : (base_fee_gwei > 2 ? "moderate-fee" : "low-fee")
      fee_info_html = "<div class=\"block-fee-info #{fee_color}\">💰 #{base_fee_gwei}G base fee</div>"
    end

    validator_info_html = ""
    if validator_short && validator_short != "Unknown"
      validator_info_html = "<div class=\"block-validator-info\">👑 Validator: #{validator_short}</div>"
    end

    events_info_html = ""
    if event_insights && event_insights[:total_events] > 0
      events_info_html = "<div class=\"block-events-info\">🔗 #{event_insights[:total_events]} events"
      if event_insights[:defi_events] > 0
        events_info_html += " (#{event_insights[:defi_events]} DeFi)"
      end
      events_info_html += "</div>"
    end

    notable_events_html = ""
    if event_insights && event_insights[:notable_events] && event_insights[:notable_events].any?
      notable_events_list = event_insights[:notable_events].map do |event|
        "<div class=\"notable-event\">🎯 #{event[:type]} on #{event[:contract]}</div>"
      end.join
      notable_events_html = "<div class=\"notable-events\"><h4>🔗 Notable Events</h4>#{notable_events_list}</div>"
    end

    <<~HTML
      <div class="block-card">
        <h3>💎 Block #{block_num}</h3>
        <div class="block-stats">
          <div class="block-stat">
            <div class="label">Transactions</div>
            <div class="value">#{tx_count}</div>
          </div>
          <div class="block-stat">
            <div class="label">Total ETH</div>
            <div class="value">#{total_value.round(4)}</div>
          </div>
          <div class="block-stat">
            <div class="label">Gas Usage</div>
            <div class="value gas-usage #{gas_usage_percentage > 90 ? 'high' : (gas_usage_percentage > 70 ? 'moderate' : 'low')}">#{gas_usage_percentage}%</div>
          </div>
          <div class="block-stat">
            <div class="label">Base Fee</div>
            <div class="value base-fee #{base_fee_gwei > 5 ? 'high' : (base_fee_gwei > 2 ? 'moderate' : 'low')}">#{base_fee_gwei}G</div>
          </div>
          <div class="block-stat">
            <div class="label">DeFi</div>
            <div class="value defi">#{activities[:defi_count]}</div>
          </div>
          <div class="block-stat">
            <div class="label">NFT</div>
            <div class="value nft">#{activities[:nft_count]}</div>
          </div>
          <div class="block-stat">
            <div class="label">Tokens</div>
            <div class="value token">#{activities[:token_count]}</div>
          </div>
          <div class="block-stat">
            <div class="label">Max TX</div>
            <div class="value">#{max_transaction.round(4)} ETH</div>
          </div>
        </div>
        #{activities[:top_activities].any? ? "<div class=\"top-activities\"><h4>🎯 Notable Activities</h4>#{top_activities_html}</div>" : ""}
        #{notable_events_html}
        <div class="timestamp-info">
          <div class="timestamp">🕐 #{timestamp_display}</div>
          #{interval_html}
          #{gas_info_html}
          #{fee_info_html}
          #{validator_info_html}
          #{events_info_html}
        </div>
      </div>
    HTML
  end
    
  def analyze_transaction_events(transactions, block_num)
    return { total_events: 0, defi_events: 0, token_transfers: 0, notable_events: [] } if transactions.empty?
    
    # Filter and prioritize interesting transactions to avoid too many RPC calls
    interesting_txs = select_interesting_transactions(transactions).first(12) # Limit to 12 receipts per block
    
    total_events = 0
    defi_events = 0
    token_transfers = 0
    notable_events = []
    
    Rails.logger.debug "🔗 Analyzing events for #{interesting_txs.length} interesting transactions in block #{block_num}"
    
    interesting_txs.each do |tx|
      begin
        receipt = fetch_transaction_receipt(tx['hash'])
        next unless receipt && receipt['logs']
        
        tx_events = receipt['logs'].length
        total_events += tx_events
        
        receipt['logs'].each do |log|
          next unless log['topics'] && log['topics'].any?
          
          event_signature = log['topics'][0]
          event_info = analyze_event_signature(event_signature, log, tx)
          
          if event_info
            case event_info[:category]
            when 'defi'
              defi_events += 1
            when 'token_transfer'
              token_transfers += 1
            end
            
            notable_events << event_info if event_info[:notable]
          end
        end
        
      rescue => e
        Rails.logger.debug "❌ Error analyzing events for tx #{tx['hash'][0..9]}: #{e.message}"
      end
    end
    
    Rails.logger.debug "🔗 Event analysis complete: #{total_events} total, #{defi_events} DeFi, #{token_transfers} transfers"
    
    {
      total_events: total_events,
      defi_events: defi_events,
      token_transfers: token_transfers,
      notable_events: notable_events.first(5) # Limit notable events
    }
  end
    
  def select_interesting_transactions(transactions)
    # Prioritize transactions that are likely to have interesting events
    interesting = []
    
    transactions.each do |tx|
      next unless tx['to'] && tx['input'] && tx['input'] != '0x'
      
      tx_value = tx['value'].to_i(16) / 1e18
      is_high_value = tx_value > 0.1
      is_known_contract = ContractDecoderService::CONTRACTS.key?(tx['to'].downcase)
      has_significant_input = tx['input'].length > 10
      
      # Score transactions to prioritize the most interesting ones
      score = 0
      score += 10 if is_high_value
      score += 8 if is_known_contract
      score += 3 if has_significant_input
      score += 2 if tx['input'].length > 100  # Complex transactions likely have events
      
      if score > 5
        interesting << { tx: tx, score: score }
      end
    end
    
    # Sort by score and return transactions
    interesting.sort_by { |item| -item[:score] }.map { |item| item[:tx] }
  end
    
  def fetch_transaction_receipt(tx_hash)
    request_data = {
      jsonrpc: '2.0',
      method: 'eth_getTransactionReceipt',
      params: [tx_hash],
      id: rand(1000..9999)
    }
    
    # Use a shorter timeout for receipt fetching to avoid blocking
    uri = URI('https://ethereum-rpc.publicnode.com')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 2
    http.open_timeout = 1
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = request_data.to_json
    
    response = http.request(request)
    
    if response.code == '200'
      data = JSON.parse(response.body)
      return data['result']
    end
    
    nil
  rescue => e
    Rails.logger.debug "❌ Receipt fetch failed for #{tx_hash[0..9]}: #{e.message}"
    nil
  end
    
  def analyze_event_signature(signature, log, tx)
    case signature.downcase
    when '0xd78ad95fa46c994b6551d0da85fc275fe613ce37657fb8d5e3d130840159d822' # Uniswap V2 Swap
      return {
        type: 'Uniswap V2 Swap',
        category: 'defi',
        notable: true,
        contract: log['address'][0..5] + '...' + log['address'][-4..-1]
      }
      
    when '0x1c411e9a96e071241c2f21f7726b17ae89e3cab4c78be50e062b03a9fffbbad1' # Uniswap V3 Swap
      return {
        type: 'Uniswap V3 Swap',
        category: 'defi',
        notable: true,
        contract: log['address'][0..5] + '...' + log['address'][-4..-1]
      }
      
    when '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef' # ERC-20/721 Transfer
      return {
        type: 'Token Transfer',
        category: 'token_transfer',
        notable: false,  # Too common to be notable unless high value
        contract: log['address'][0..5] + '...' + log['address'][-4..-1]
      }
      
    when '0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925' # ERC-20 Approval
      return {
        type: 'Token Approval',
        category: 'token_transfer',
        notable: false,
        contract: log['address'][0..5] + '...' + log['address'][-4..-1]
      }
      
    when '0xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c' # Aave Deposit
      return {
        type: 'Aave Deposit',
        category: 'defi',
        notable: true,
        contract: log['address'][0..5] + '...' + log['address'][-4..-1]
      }
      
    when '0x3115d1449a7b732c986cba18244e897a450f61e1bb8d589cd2e69e6c8924f9f7' # Aave Withdraw
      return {
        type: 'Aave Withdraw',
        category: 'defi',
        notable: true,
        contract: log['address'][0..5] + '...' + log['address'][-4..-1]
      }
      
    else
      # Unknown event, still count it but not notable
      return {
        type: 'Unknown Event',
        category: 'other',
        notable: false,
        contract: log['address'][0..5] + '...' + log['address'][-4..-1]
      }
    end
  end
end 