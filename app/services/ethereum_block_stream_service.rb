require 'async'
require 'async/websocket/client'
require 'async/http/endpoint'
require 'async/http/protocol'
require 'json'
require 'singleton'

class EthereumBlockStreamService
  include Singleton

  def initialize
    @task = nil
    @ws = nil
    @running = false
  end

  def start
    return if @running

    @running = true
    puts "🚀 Starting Ethereum Block Stream Service..."
    
    @task = Async do |task|
      begin
        endpoint = Async::HTTP::Endpoint.parse('wss://ethereum-rpc.publicnode.com', alpn_protocols: ['http/1.1'])
       
        Async::WebSocket::Client.connect(endpoint) do |ws|
          @ws = ws
          puts "✅ Connected to Ethereum WebSocket"
          
          subscribe_to_new_blocks
          
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
    puts "🛑 Ethereum Block Stream Service stopped"
  end

  private

  def subscribe_to_new_blocks
    subscription_request = {
      id: 1,
      method: "eth_subscribe",
      params: ["newHeads"]
    }
    
    @ws.write(subscription_request.to_json)
    puts "📡 Subscribed to new blocks"
  end

  def handle_message(data)
    return unless data.is_a?(Hash)

    # Handle subscription confirmation
    if data['id'] == 1 && data['result']
      puts "✅ Block subscription confirmed: #{data['result']}"
      return
    end

    # Handle new block notifications
    if data['method'] == 'eth_subscription' && data['params']
      block_data = data.dig('params', 'result')
      if block_data && block_data.is_a?(Hash)
        process_block(block_data)
      end
      return
    end
  end

  def process_block(block_data)
    return unless block_data.is_a?(Hash)

    block_number = block_data['number']
    return unless block_number

    # Convert hex to integer
    block_number_int = block_number.to_i(16)
    
    begin
      puts "🧱 Processing block #{block_number_int}..."
      EthereumBlock.find_or_create_by(block_number: block_number_int)
      puts "✅ Created block #{block_number_int}"
    rescue => e
      puts "❌ Error processing block #{block_number_int}: #{e.message}"
    end
  end
end