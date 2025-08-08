class TransactionDataJob < ApplicationJob
  queue_as :default

  def perform(transaction_id)
    transaction = EthereumTransaction.find(transaction_id)
    transaction_data = fetch_transaction(transaction.transaction_hash)
    # Sanitize data to remove null characters that PostgreSQL cannot handle
    sanitized_data = sanitize_unicode_data(transaction_data)
    transaction.update!(data: sanitized_data)
    
    # Find or create addresses first, then associate them with the transaction
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
  end

  def fetch_transaction(transaction_hash)
    uri = URI("#{BASE_URL}/api/v1/ethereum/transactions/#{transaction_hash}")
    http = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == 'https'
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    end
    response = http.get(uri.request_uri)
    JSON.parse(response.body)
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