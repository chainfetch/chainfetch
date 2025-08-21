class TokenDataJob < ApplicationJob
  queue_as :default
  retry_on Net::ReadTimeout, wait: 3.seconds, attempts: 3
  retry_on Ethereum::BaseService::ApiError, wait: 5.seconds, attempts: 3

  def perform(token_id)
    token = EthereumToken.find(token_id)
    
    token_data = Ethereum::TokenDataService.new(token.address_hash).call
    token.update!(data: token_data)

    if rand(15) == 0
      summary = Ethereum::TokenSummaryService.new(token_data).call
      embedding = Embedding::GeminiService.new(summary).embed_document
      QdrantService.new.upsert_point(collection: "tokens", id: token_id.to_i, vector: embedding, payload: { token_summary: summary })
    end
  rescue Ethereum::BaseService::ApiError => e
    Rails.logger.error "API error for token #{token&.address_hash}: #{e.message}"
    raise # Re-raise to trigger retry mechanism
  rescue => e
    Rails.logger.error "Unexpected error in TokenDataJob for token #{token&.address_hash}: #{e.class.name}: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n") if e.backtrace
    raise
  end
end