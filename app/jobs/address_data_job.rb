class AddressDataJob < ApplicationJob
  queue_as :default
  retry_on Net::ReadTimeout, wait: 3.seconds, attempts: 3
  retry_on Ethereum::BaseService::ApiError, wait: 5.seconds, attempts: 3

  def perform(address_id)
    address = EthereumAddress.find(address_id)
    
    address_data = Ethereum::AddressDataService.new(address.address_hash).call
    address.update!(data: address_data)

    if address_data['info']['is_contract']
      smart_contract = EthereumSmartContract.find_or_create_by!(address_hash: address.address_hash)
      SmartContractDataJob.perform_later(smart_contract.id)
    end

    if rand(15) == 0
      summary = Ethereum::AddressSummaryService.new(address_data).call
      embedding = EmbeddingService.new(summary).call
      QdrantService.new.upsert_point(collection: "addresses", id: address_id.to_i, vector: embedding, payload: { summary: summary })
    end
  rescue Ethereum::BaseService::ApiError => e
    Rails.logger.error "API error for address #{address&.address_hash}: #{e.message}"
    raise # Re-raise to trigger retry mechanism
  rescue => e
    Rails.logger.error "Unexpected error in AddressDataJob for address #{address&.address_hash}: #{e.class.name}: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n") if e.backtrace
    raise
  end
end