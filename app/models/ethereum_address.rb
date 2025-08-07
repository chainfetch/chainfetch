class EthereumAddress < ApplicationRecord
  has_many :ethereum_address_transactions, dependent: :destroy
  has_many :ethereum_transactions, through: :ethereum_address_transactions
  after_create_commit :fetch_data

  def self.semantic_search(query, limit = 10)
    embedding = EmbeddingService.new(query).call
    qdrant_objects = qdrant_query(embedding, limit)
    qdrant_objects.dig("result", "points").map do |obj|
      {
        id: obj.dig("id"),
        address_summary: obj.dig("payload", "address_summary")
      }
    end
  end

  def self.json_search(query)
    addresses = AddressDataSearchService.new(query).call
    ids = addresses[:addresses].map { |address| address[:id] }
    
    # Use Async to fetch qdrant data for each address in parallel
    Async do |task|
      # Create concurrent tasks for each ID
      tasks = ids.map do |id|
        task.async do
          begin
            QdrantService.new.retrieve_point(collection: "addresses", id: id)
          rescue => e
            Rails.logger.error "Error fetching qdrant data for address #{id}: #{e.message}"
            nil
          end
        end
      end
      
      qdrant_objects = tasks.map(&:wait)
      results = qdrant_objects.compact.map do |obj|
        {
          id: obj.dig("result", "id"),
          address_summary: obj.dig("result", "payload", "address_summary")
        }
      end
      {
        sql_query: addresses[:sql_query],
        results: results
      }
    end.wait
  rescue => e
    Rails.logger.error "Error in json_search: #{e.message}"
    []
  end

  def self.qdrant_query(query, limit = 10)
    QdrantService.new.query_points(collection: "addresses", query: query, limit: limit)
  end

  def qdrant_data
    QdrantService.new.retrieve_point(collection: "addresses", id: self.id)
  end

  def summary
    address_data = Ethereum::AddressDataService.new(self.address_hash).call
    Ethereum::AddressSummaryService.new(address_data).call
  end

  def embedding
    EmbeddingService.new(summary).call
  end

  def fetch_data
    AddressDataJob.perform_later(self.id)
  end

end
