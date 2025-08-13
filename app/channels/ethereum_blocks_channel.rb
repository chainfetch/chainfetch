class EthereumBlocksChannel < ApplicationCable::Channel
  def subscribed
    stream_from "ethereum_blocks_channel_#{current_user.id}"
    Rails.logger.info "👤 User subscribed to Ethereum blocks channel"

    ChannelSubscription.create!(
      user: current_user,
      channel_name: "ethereum_blocks_channel",
      connection_id: connection.connection_identifier
    )
  end

  def unsubscribed
    Rails.logger.info "👤 User unsubscribed from Ethereum blocks channel"

    ChannelSubscription.where(
      user: current_user,
      channel_name: "ethereum_blocks_channel",
      connection_id: connection.connection_identifier
    ).destroy_all
  end
end