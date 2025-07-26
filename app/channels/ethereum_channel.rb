class EthereumChannel < ApplicationCable::Channel
  def subscribed
    stream_from "ethereum_data"
    Rails.logger.info "👤 User subscribed to Ethereum channel"
  end

  def unsubscribed
    Rails.logger.info "👤 User unsubscribed from Ethereum channel"
    
    # Optionally stop the service if no more subscribers
    # Uncomment the next line if you want to stop when no users are connected
  end

  private

end 