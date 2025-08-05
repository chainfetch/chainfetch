class SummaryEmbeddingJob < ApplicationJob
  queue_as :default

  def perform(address_id, address_hash)
    address_data = Ethereum::AddressDataService.new(address_hash).call
    raise "Address data is empty" if address_data.empty?
    address = Address.find(address_id)
    address.update(data: address_data.except("transactions", "token_transfers", "internal_transactions", "coin_balance_history", "coin_balance_history_by_day"))
    summary = Ethereum::AddressSummaryService.new(address_data).call
    embedding = EmbeddingService.new(summary).call
    QdrantService.new.upsert_point(collection: "addresses", id: address_id.to_i, vector: embedding, payload: { address_summary: summary })
  end
end