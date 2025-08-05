require 'async'
require 'async/websocket/client'
require 'async/http/endpoint'
require 'async/http/protocol'
require 'json'
require 'singleton'

class EthereumAddressEmbeddingService
  include Singleton

  def initialize
    @task = nil
    @ws = nil
    @running = false
    @total_transactions = 0
    @total_pending_transactions = 0
  end

  def start
    return if @running

    @running = true
    puts "🚀 Starting Ethereum Address Embedding Service..."
    
    @task = Async do |task|
      begin
        # Connect to Ethereum WebSocket
        # endpoint = Async::HTTP::Endpoint.parse('wss://ethereum-ws.chainfetch.app', alpn_protocols: ['http/1.1'])
        endpoint = Async::HTTP::Endpoint.parse('wss://ethereum-rpc.publicnode.com', alpn_protocols: ['http/1.1'])
       
        Async::WebSocket::Client.connect(endpoint) do |ws|
          @ws = ws
          puts "✅ Connected to Ethereum WebSocket"
          
          # Subscribe to new blocks
          subscribe_to_pending_transactions
          
          # Handle incoming messages
          while @running && (message = ws.read)
            message_text = message.respond_to?(:buffer) ? message.buffer : message.to_s
            handle_message(JSON.parse(message_text))
          end
        end
      rescue => e
        puts "❌ WebSocket error: #{e.message}"
        puts "🔄 Retrying in 5 seconds..."
        task.sleep(5)
        retry if @running
      end
    end
  end

  def stop
    @running = false
    @ws&.close
    @task&.stop
    puts "🛑 Ethereum Address Embedding Service stopped"
  end

  private

  def subscribe_to_pending_transactions
    # Subscribe to new pending transactions
    subscription_request = {
      id: 1,
      method: "eth_subscribe",
      params: ["newPendingTransactions"]
    }
    
    @ws.write(subscription_request.to_json)
    puts "📡 Subscribed to new pending transactions"
  end

  def handle_message(data)
    return unless data.is_a?(Hash)

    # Handle subscription confirmation
    if data['id'] == 1 && data['result']
      puts "✅ Pending transaction subscription confirmed: #{data['result']}"
      return
    end

    # Handle new pending transaction notifications
    if data['method'] == 'eth_subscription' && data['params']
      tx_hash = data.dig('params', 'result')
      if tx_hash && tx_hash.is_a?(String)
        process_pending_transaction(tx_hash)
      end
      return
    end

    # Handle transaction data responses
    if data['result'] && data['result'].is_a?(Hash) && data['result']['from']
      transaction = data['result']
      process_single_transaction(transaction)
      return
    end
  end

  def process_pending_transaction(tx_hash)
    @last_requests ||= []
  
    # Clean up requests older than 1 second
    now = Time.now
    @last_requests.reject! { |t| now - t >= 1.0 }
  
    if @last_requests.size < 10
      @last_requests << now
      get_transaction_details(tx_hash)
    else
      # Skipped due to rate limit
      puts "⚠️ Skipping #{tx_hash[0..10]} due to rate limit"
    end
  end
  

  def get_transaction_details(tx_hash)
    # Request full transaction data
    tx_request = {
      id: rand(1000..9999),
      method: "eth_getTransactionByHash",
      params: [tx_hash]
    }

    @ws.write(tx_request.to_json)
  end

  def process_single_transaction(transaction)
    return unless transaction.is_a?(Hash)

    from_address = transaction['from']
    return unless from_address

    @total_pending_transactions += 1
    @total_transactions += 1
    
    # Process this single address (keep original format)
    process_addresses([from_address])
  end

  def process_addresses(addresses)
    # puts "🔍 Processing #{addresses.size} unique addresses from pending transaction..."

    addresses.each do |address_hash|
      begin
        puts "🔍 Processing address #{address_hash}..."
        Address.find_or_create_by(address_hash: address_hash)
        # Generate text summary for the address
        #summary = Ethereum::AddressTextGeneratorService.call(address_hash)
        
        if nil# summary && !summary.empty?
          # Generate embedding for the summary
          #embedding = EmbeddingService.new(summary).call
          
          if nil# embedding
            puts "✅ Generated embedding for address #{address_hash[0..8]}... (#{summary.length} chars)"
            
            # Optional: Store or use the embedding
            store_address_embedding(address_hash, summary, embedding)
          else
            puts "⚠️  Failed to generate embedding for address #{address_hash[0..8]}..."
          end
        else
          # puts "⚠️  No summary generated for address #{address_hash[0..8]}..."
        end
        
      rescue => e
        puts "❌ Error processing address #{address_hash[0..8]}...: #{e.message}"
      end
    end

    # puts "📊 Stats: #{@total_pending_transactions} pending transactions, #{@total_transactions} unique addresses processed"
  end

  def store_address_embedding(address_hash, summary, embedding)
    # Optional: Store the embedding in database, cache, or file
    # For now, just log the result
    puts "💾 Stored embedding for #{address_hash}: #{embedding.size} dimensions"
    
    # Example: Save to database
    # AddressEmbedding.create!(
    #   address: address_hash,
    #   summary: summary,
    #   embedding: embedding,
    #   created_at: Time.current
    # )
  end
end

# Usage:
# service = EthereumAddressEmbeddingService.instance
# service.start
# 
# # To stop:
# service.stop 