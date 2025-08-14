# File: ethereum_transaction_stream_service.rb

require "async"
require "async/websocket/client"
require "async/http/endpoint"
require "async/http/protocol"
require "json"
require "singleton"

class EthereumTransactionStreamService
  include Singleton

  def initialize
    @task = nil
    @ws = nil
    @running = false
  end

  def start
    return if @running

    @running = true
    log_message "🚀 Starting Ethereum Transaction Stream Service..."

    @task = Async do |task|
      begin
        endpoint = Async::HTTP::Endpoint.parse("wss://ethereum-rpc.publicnode.com", alpn_protocols: [ "http/1.1" ])

        Async::WebSocket::Client.connect(endpoint) do |ws|
          @ws = ws
          log_message "✅ Connected to Ethereum WebSocket"

          subscribe_to_new_transactions

          while @running && (message = ws.read)
            message_text = message.respond_to?(:buffer) ? message.buffer : message.to_s
            handle_message(JSON.parse(message_text))
          end
        end
      rescue => e
        log_message "❌ WebSocket error: #{e.message}"
        log_message "🔄 Retrying in 5 seconds..."
        task.sleep(5)
        retry if @running
      end
    end
  end

  def stop
    @running = false
    @ws&.close
    @task&.stop
    log_message "🛑 Ethereum Transaction Stream Service stopped"
  end

  private

  def log_message(message)
    # Output to both console and Rails logger
    puts message
    Rails.logger.info("[EthereumTransactionStream] #{message}")

    # Force flush stdout for better background logging
    STDOUT.flush
  end

  def subscribe_to_new_transactions
    subscription_request = {
      id: 1,
      method: "eth_subscribe",
      params: [ "newPendingTransactions" ]
    }

    @ws.write(subscription_request.to_json)
    log_message "📡 Subscribed to new transactions"
  end

  def handle_message(data)
    return unless data.is_a?(Hash)

    # Handle subscription confirmation
    if data["id"] == 1 && data["result"]
      log_message "✅ Transaction subscription confirmed: #{data['result']}"
      return
    end

    # Handle new transaction notifications
    if data["method"] == "eth_subscription" && data["params"]
      transaction_data = data.dig("params", "result")
      if transaction_data && transaction_data.is_a?(Hash)
        process_transaction(transaction_data)
      end
      nil
    end
  end

  def process_transaction(transaction_data)
    return unless transaction_data.is_a?(Hash)

    transaction_hash = transaction_data["hash"]
    return unless transaction_hash

    # Convert hex to integer
    transaction_hash_int = transaction_hash.to_i(16)
    from_address = transaction_data["from"]
    to_address = transaction_data["to"]

    begin
      alerts = Rails.cache.fetch("ethereum_alerts", expires_in: 1.minute) do
        EthereumAlert.where(status: :active).to_a
      end
      alerts.select { |a| [from_address, to_address].include?(a.address_hash) }.each { |alert| alert.trigger_webhook(transaction_hash) }
    rescue => e
      log_message "❌ Error processing transaction #{transaction_hash_int}: #{e.message}"
    end
  end
end
