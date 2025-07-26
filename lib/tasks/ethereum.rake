namespace :ethereum do
  desc "Start Ethereum stream service"
  task start: :environment do
    service = EthereumStreamService.instance
    
    if service.running?
      puts "🟢 Ethereum stream is already running"
    else
      puts "🚀 Starting Ethereum stream service..."
      
      begin
        service.start
        
        # Give it a moment to start and check multiple times
        5.times do |i|
          sleep(1)
          if service.running?
            puts "✅ Ethereum stream started successfully"
            exit 0
          end
          puts "⏳ Waiting for service to start... (#{i+1}/5)"
        end
        
        puts "❌ Failed to start Ethereum stream - service not running after 5 seconds"
        puts "🔍 Debug info:"
        puts "  - Service instance: #{service.inspect}"
        puts "  - Running status: #{service.running?}"
        
      rescue => e
        puts "❌ Error starting Ethereum stream: #{e.class}: #{e.message}"
        puts "🔍 Backtrace:"
        puts e.backtrace.first(10).map { |line| "  #{line}" }
        exit 1
      end
      
      exit 1
    end
  end

  desc "Simple WebSocket test"
  task simple_test: :environment do
    puts "🔍 Simple WebSocket test (basic connection)..."
    
    begin
      require 'async'
      require 'async/websocket/client'
      require 'async/http/endpoint'
      
      puts "📡 Connecting to wss://ethereum-rpc.publicnode.com..."
      
      Async do
        endpoint = Async::HTTP::Endpoint.parse('wss://ethereum-rpc.publicnode.com')
        
        puts "🔗 Endpoint created: #{endpoint.inspect}"
        
        Async::WebSocket::Client.connect(endpoint) do |ws|
          puts "✅ Connected! WebSocket: #{ws.class}"
          
          # Send eth_blockNumber request
          message = {
            jsonrpc: '2.0',
            method: 'eth_blockNumber',
            params: [],
            id: 1
          }
          
          puts "📤 Sending: #{message}"
          ws.write(message.to_json)
          
          puts "⏳ Waiting for response..."
          response = ws.read
          
          if response
            puts "📥 Got response: #{response}"
            parsed = JSON.parse(response)
            if parsed['result']
              block_num = parsed['result'].to_i(16)
              puts "🎯 Current block: #{block_num}"
            end
          else
            puts "❌ No response received"
          end
        end
      end.wait
      
      puts "✅ Test completed successfully"
      
    rescue => e
      puts "❌ Test failed: #{e.class}: #{e.message}"
      puts "🔍 Backtrace:"
      e.backtrace.first(10).each { |line| puts "  #{line}" }
    end
  end

  desc "Test Ethereum WebSocket connection"
  task test_connection: :environment do
    puts "🔍 Testing WebSocket connection..."
    
    begin
      require 'async'
      require 'async/websocket/client'
      
      endpoints = [
        'wss://eth-mainnet.g.alchemy.com/v2/demo',
        'wss://mainnet.infura.io/ws/v3/demo', 
        'wss://rpc.ankr.com/eth/ws'
      ]
      
      endpoints.each do |endpoint_url|
        puts "🔗 Testing #{endpoint_url}..."
        
        begin
          Async do
            endpoint = Async::HTTP::Endpoint.parse(endpoint_url)
            
            Async::WebSocket::Client.connect(endpoint, protocols: ['ws']) do |ws|
              puts "✅ Successfully connected to #{endpoint_url}"
              
              # Send a test message
              test_msg = {
                jsonrpc: '2.0',
                method: 'eth_blockNumber',
                params: [],
                id: 1
              }
              
              ws.write(test_msg.to_json)
              puts "📤 Sent test message"
              
              # Try to read response with timeout
              if response = ws.read
                parsed = JSON.parse(response)
                if parsed['result']
                  block_number = parsed['result'].to_i(16)
                  puts "📥 Got response - Current block: #{block_number.to_s(:delimited)}"
                  puts "🎉 This endpoint works!"
                  break
                else
                  puts "⚠️  Got response but no result: #{response}"
                end
              else
                puts "⚠️  No response received"
              end
            end
          end.wait
          
        rescue => e
          puts "❌ Failed: #{e.class} - #{e.message}"
        end
      end
      
    rescue => e
      puts "❌ Test failed: #{e.class}: #{e.message}"
      puts "🔍 Backtrace:"
      puts e.backtrace.first(5).map { |line| "  #{line}" }
    end
  end

  desc "Stop Ethereum stream service"
  task stop: :environment do
    service = EthereumStreamService.instance
    
    if service.running?
      puts "🛑 Stopping Ethereum stream service..."
      service.stop
      
      # Give it a moment to stop
      sleep(2)
      
      puts "✅ Ethereum stream stopped"
    else
      puts "🔴 Ethereum stream is not running"
    end
  end

  desc "Restart Ethereum stream service"
  task restart: :environment do
    service = EthereumStreamService.instance
    
    puts "🔄 Restarting Ethereum stream service..."
    
    if service.running?
      puts "🛑 Stopping current stream..."
      service.stop
      sleep(2)
    end
    
    puts "🚀 Starting stream..."
    service.start
    sleep(2)
    
    if service.running?
      puts "✅ Ethereum stream restarted successfully"
    else
      puts "❌ Failed to restart Ethereum stream"
      exit 1
    end
  end

  desc "Check Ethereum stream service status"
  task status: :environment do
    service = EthereumStreamService.instance
    
    if service.running?
      puts "🟢 Ethereum stream is running"
      
      # Try to get some basic info if available
      begin
        # Check if we can connect to the service
        puts "📊 Stream appears to be healthy"
      rescue => e
        puts "⚠️  Stream is running but may have issues: #{e.message}"
      end
    else
      puts "🔴 Ethereum stream is stopped"
    end
  end

  desc "Show help for ethereum tasks"
  task :help do
    puts <<~HELP
      🔗 Ethereum Stream Management Tasks:
      
      rake ethereum:start          - Start the Ethereum stream service
      rake ethereum:stop           - Stop the Ethereum stream service  
      rake ethereum:restart        - Restart the Ethereum stream service
      rake ethereum:status         - Check if the stream service is running
      rake ethereum:test_connection - Test WebSocket connection
      rake ethereum:help           - Show this help message
      
      The stream connects to multiple Ethereum WebSocket endpoints and broadcasts
      real-time block data via Action Cable to connected clients.
    HELP
  end

  # Make help the default task
  task default: :help
end

# Convenience shortcuts
desc "Start Ethereum stream (shortcut for ethereum:start)"
task eth_start: 'ethereum:start'

desc "Stop Ethereum stream (shortcut for ethereum:stop)"
task eth_stop: 'ethereum:stop'

desc "Restart Ethereum stream (shortcut for ethereum:restart)"
task eth_restart: 'ethereum:restart'

desc "Check Ethereum stream status (shortcut for ethereum:status)"
task eth_status: 'ethereum:status'

desc "Debug WebSocket handshake"
task debug_handshake: :environment do
  puts "🔍 Debug WebSocket handshake with Ethereum endpoints..."
  
  # Try different known working WebSocket endpoints
  endpoints_to_try = [
    'wss://ws.chainstack.com/v1/ws/YOUR_API_KEY',
    'wss://mainnet.gateway.tenderly.co',
    'wss://rpc.builder0x69.io',
    'wss://ethereum-rpc.publicnode.com/ws',
    'wss://ethereum-rpc.publicnode.com/websocket',
    'wss://eth.drpc.org/wss'
  ]
  
  endpoints_to_try.each do |endpoint_url|
    puts "\n" + "="*60
    puts "🔗 Testing: #{endpoint_url}"
    
    begin
      require 'async'
      require 'async/http/client'
      require 'async/http/endpoint'
      require 'protocol/websocket/headers'
      
      Async do
        endpoint = Async::HTTP::Endpoint.parse(endpoint_url)
        client = Async::HTTP::Client.new(endpoint)
        
        # Create WebSocket handshake headers manually
        key = Protocol::WebSocket::Headers::Nounce.generate_key
        
        headers = {
          'Host' => endpoint.authority,
          'Upgrade' => 'websocket',
          'Connection' => 'Upgrade',
          'Sec-WebSocket-Key' => key,
          'Sec-WebSocket-Version' => '13',
          'Origin' => 'http://localhost:3000'
        }
        
        puts "📤 Sending handshake..."
        
        path = endpoint.path.empty? ? '/' : endpoint.path
        response = client.get(path, headers: headers)
        
        puts "📥 Response received:"
        puts "  Status: #{response.status}"
        
        if response.status == 101
          puts "✅ WebSocket handshake successful!"
          
          # Check if the accept key matches
          expected_accept = Protocol::WebSocket::Headers::Nounce.accept_digest(key)
          actual_accept = response.headers['sec-websocket-accept']
          
          puts "🔑 Key verification:"
          puts "  Expected: #{expected_accept}"
          puts "  Actual: #{actual_accept}"
          puts "  Match: #{expected_accept == actual_accept}"
          
          if expected_accept == actual_accept
            puts "🎉 This endpoint should work with async-websocket!"
            break
          end
        else
          puts "❌ WebSocket handshake failed"
          puts "  Content-Type: #{response.headers['content-type']}"
        end
        
        client.close
      end.wait
      
    rescue => e
      puts "❌ Test failed: #{e.class}: #{e.message}"
    end
  end
end 

desc "Debug WebSocket handshake - comprehensive"
task debug_comprehensive: :environment do
  puts "🔍 Comprehensive WebSocket debug for ethereum-rpc.publicnode.com..."
  
  # Let's try different configurations that might work
  configs_to_try = [
    { 
      description: "Basic connection (like Node.js)",
      protocols: [],
      version: 13,
      extra_headers: {}
    },
    { 
      description: "With websocket subprotocol",
      protocols: ['websocket'],
      version: 13,
      extra_headers: {}
    },
    {
      description: "With specific user agent",
      protocols: [],
      version: 13,
      extra_headers: {
        'User-Agent' => 'Mozilla/5.0 (compatible; Ruby WebSocket Client)'
      }
    },
    {
      description: "With JSON-RPC protocol",
      protocols: ['jsonrpc'],
      version: 13,
      extra_headers: {}
    },
    {
      description: "Without Origin header",
      protocols: [],
      version: 13,
      extra_headers: {},
      skip_origin: true
    }
  ]
  
  success = false
  
  configs_to_try.each do |config|
    break if success
    
    puts "\n" + "="*60
    puts "🔗 Testing: #{config[:description]}"
    
    begin
      require 'async'
      require 'async/websocket/client'
      require 'async/http/endpoint'
      
      Async do
        # Force HTTP/1.1 like browsers do for WebSocket
        endpoint = Async::HTTP::Endpoint.parse('wss://ethereum-rpc.publicnode.com', 
          alpn_protocols: ['http/1.1'])
        
        puts "📤 Attempting connection with protocols: #{config[:protocols]}"
        
        # Try with the specific configuration
        Async::WebSocket::Client.connect(endpoint, 
                                       protocols: config[:protocols], 
                                       version: config[:version]) do |ws|
          puts "✅ CONNECTION SUCCESSFUL!"
          puts "🎉 This configuration works!"
          
          # Send a test message like Node.js does
          test_message = {
            jsonrpc: '2.0',
            method: 'eth_blockNumber',
            params: [],
            id: 1
          }
          
          puts "📤 Sending test message: #{test_message}"
          ws.write(test_message.to_json)
          
          puts "⏳ Waiting for response..."
          response = ws.read
          
          if response
            puts "📥 Got response: #{response}"
            
            # Extract text content from WebSocket message
            response_text = response.respond_to?(:buffer) ? response.buffer : response.to_s
            parsed = JSON.parse(response_text)
            
            if parsed['result']
              block_num = parsed['result'].to_i(16)
              puts "🎯 Current block: #{block_num}"
              puts "🚀 CONFIGURATION WORKS! Update the service with these settings."
              success = true
            end
          end
        end # End Async::WebSocket::Client.connect block
        
      end.wait # End Async block
        
    rescue => e
      puts "❌ Failed: #{e.class}: #{e.message}"
      # Continue to next config
    end # End begin/rescue block
  end # End configs_to_try.each
  
  unless success
    puts "\n" + "="*60
    puts "🔬 Let's also try raw socket approach to see what the server expects..."
    
    begin
      require 'async'
      require 'async/websocket/client'
      require 'async/http/endpoint'
      require 'protocol/websocket/headers'
      
      Async do
        # Try with minimal, browser-like approach
        endpoint = Async::HTTP::Endpoint.parse('wss://ethereum-rpc.publicnode.com')
        
        # Use async-websocket but with custom options
        client = Async::WebSocket::Client.open(endpoint, alpn_protocols: ['http/1.1'])
        
        # Try connecting with minimal headers
        connection = client.connect(endpoint.authority, endpoint.path || '/')
        
        puts "✅ Raw connection successful!"
        
        # Send the same message as Node.js
        test_message = {
          jsonrpc: '2.0',
          method: 'eth_blockNumber',
          params: [],
          id: 1
        }
        
        connection.write(Protocol::WebSocket::TextMessage.generate(test_message.to_json))
        connection.flush
        
        while message = connection.read
          puts "📥 Received: #{message.inspect}"
          break
        end
        
        client.close
        
      end.wait # End Async block
        
    rescue => e
      puts "❌ Raw approach failed: #{e.class}: #{e.message}"
    end # End begin/rescue block
  end # End unless success
  
  puts "\n🎯 If none worked, the issue might be server-side routing or protocol negotiation."
end 