class AddressDataJob < ApplicationJob
  queue_as :default

  def perform(address_id)
    address = EthereumAddress.find(address_id)
    address_data = Ethereum::AddressDataService.new(address.address_hash).call
    address.update!(data: address_data)

    if rand(30) == 0
      summary = Ethereum::AddressSummaryService.new(address_data).call
      embedding = EmbeddingService.new(summary).call
      QdrantService.new.upsert_point(collection: "addresses", id: address_id.to_i, vector: embedding, payload: { address_summary: summary })
    end
  end
end