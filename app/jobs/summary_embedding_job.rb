class SummaryEmbeddingJob < ApplicationJob
  queue_as :default

  def perform(address_id, address_hash)
    summary = Ethereum::AddressTextGeneratorService.call(address_hash)
    embedding = EmbeddingService.new(summary).call
    QdrantService.new.upsert_point(collection: "addresses", id: address_id.to_i, vector: embedding, payload: { address_summary: summary })
  end
end