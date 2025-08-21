class TransactionDataJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(transaction_id)
    transaction = EthereumTransaction.find(transaction_id)
    transaction_data = Ethereum::TransactionDataService.new(transaction.transaction_hash).call
    raise "Transaction data is nil" if transaction_data.nil?
    
    # Sanitize data to remove null characters that PostgreSQL cannot handle
    sanitized_data = sanitize_unicode_data(transaction_data)
    transaction.update!(data: sanitized_data)
    
    from_address_hash = sanitized_data.dig('info', 'from', 'hash')
    to_address_hash = sanitized_data.dig('info', 'to', 'hash')
    
    if from_address_hash.present?
      from_address = EthereumAddress.find_or_create_by!(address_hash: from_address_hash)
      EthereumAddressTransaction.find_or_create_by!(
        ethereum_address: from_address,
        ethereum_transaction: transaction
      )
      AddressDataJob.perform_later(from_address.id)
    end
    
    if to_address_hash.present?
      to_address = EthereumAddress.find_or_create_by!(address_hash: to_address_hash)
      EthereumAddressTransaction.find_or_create_by!(
        ethereum_address: to_address,
        ethereum_transaction: transaction
      )
      AddressDataJob.perform_later(to_address.id)
    end

    if rand(20) == 0
      summary = Ethereum::TransactionSummaryService.new(transaction_data).call
      embedding = Embedding::GeminiService.new(summary).embed_document
      QdrantService.new.upsert_point(collection: "transactions", id: transaction_id.to_i, vector: embedding, payload: { summary: summary })
    end
  end

  private

  def sanitize_unicode_data(data)
    case data
    when Hash
      data.transform_values { |value| sanitize_unicode_data(value) }
    when Array
      data.map { |item| sanitize_unicode_data(item) }
    when String
      # Remove null characters and other problematic Unicode sequences
      data.gsub(/\u0000/, '').gsub(/\\u0000/, '')
    else
      data
    end
  end
end