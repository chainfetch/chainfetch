class EthereumToken < ApplicationRecord

  def self.semantic_search(query, limit = 10)
    embedding = EmbeddingService.new(query).call
    qdrant_objects = qdrant_query(embedding, limit)
    qdrant_objects.dig("result", "points").map do |obj|
      {
        id: obj.dig("id"),
        token_summary: obj.dig("payload", "token_summary")
      }
    end
  end



  def self.qdrant_query(query, limit = 10)
    QdrantService.new.query_points(collection: "tokens", query: query, limit: limit)
  end

  def qdrant_data
    QdrantService.new.retrieve_point(collection: "tokens", id: self.id)
  end

  def summary
    token_data = Ethereum::TokenDataService.new(self.address_hash).call
    Ethereum::TokenSummaryService.new(token_data).call
  end

  def embedding
    EmbeddingService.new(summary).call
  end

  def fetch_data
    TokenDataJob.perform_later(self.id)
  end

end