class EthereumAlertWebhookJob < ApplicationJob
  queue_as :default

  def perform(ethereum_alert_id, transaction_hash)
    ethereum_alert = EthereumAlert.find(ethereum_alert_id)
    transaction_data = Ethereum::TransactionDataService.new(transaction_hash).call
    summary = Ethereum::TransactionSummaryService.new(transaction_data).call
    begin
      payload = {
        address_hash: ethereum_alert.address_hash,
        transaction_data: transaction_data,
        summary: summary
      }
      Net::HTTP.post(URI(ethereum_alert.webhook_url), payload.to_json, { "Content-Type" => "application/json" })
    rescue => e
      Rails.logger.error("Failed to send webhook for EthereumAlert #{ethereum_alert_id}: #{e.message}")
    end
    ethereum_alert.update!(last_triggered_at: Time.current)
    ethereum_alert.user.decrement!(:api_credit, 5)
  end
end