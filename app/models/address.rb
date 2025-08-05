class Address < ApplicationRecord
  after_create_commit :generate_summary_and_embedding

  def self.search(query, limit = 10)
    embedding = EmbeddingService.new(query).call
    qdrant_query(embedding, limit)
  end

  def self.qdrant_query(query, limit = 10)
    QdrantService.new.query_points(collection: "addresses", query: query, limit: limit)
  end

  def generate_summary_and_embedding
    SummaryEmbeddingJob.perform_later(self.id, self.address_hash)
  end

  def qdrant_data
    QdrantService.new.retrieve_point(collection: "addresses", id: self.id)
  end

  def summary
    Ethereum::AddressTextGeneratorService.call(self.address_hash)
  end

  def embedding
    EmbeddingService.new(summary).call
  end

end
