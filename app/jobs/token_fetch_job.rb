class TokenFetchJob < ApplicationJob
  queue_as :default
  retry_on Net::ReadTimeout, wait: 3.seconds, attempts: 3
  retry_on Ethereum::BaseService::ApiError, wait: 5.seconds, attempts: 3

  def perform(options = {})
    service = Ethereum::TokenFetchService.new(options)
    result = service.fetch_and_create_tokens
    
    Rails.logger.info "Token fetch job completed: #{result[:created_count]} tokens created out of #{result[:total_processed]} processed"
    
    # If there's a next page and we created some tokens, schedule the next batch
    if result[:next_page_token] && result[:created_count] > 0
      Rails.logger.info "Scheduling next batch with page token: #{result[:next_page_token]}"
      TokenFetchJob.perform_later(options.merge(page_token: result[:next_page_token]))
    end
    
    result
  rescue Ethereum::BaseService::ApiError => e
    Rails.logger.error "API error in TokenFetchJob: #{e.message}"
    raise # Re-raise to trigger retry mechanism
  rescue => e
    Rails.logger.error "Unexpected error in TokenFetchJob: #{e.class.name}: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n") if e.backtrace
    raise
  end
end