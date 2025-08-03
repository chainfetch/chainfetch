class Address < ApplicationRecord
  has_neighbors :summary_embedding
  after_create_commit :generate_summary_and_embedding

  private

  def generate_summary_and_embedding
    summary = Ethereum::AddressTextGeneratorService.call(address_hash)
    embedding = EmbeddingService.new(summary).call
    update(summary: summary, summary_embedding: embedding)
  end
end
