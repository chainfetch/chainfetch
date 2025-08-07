require 'net/http'
require 'json'
require 'openssl'
require 'async'

class BlockDataJob < ApplicationJob
  queue_as :default

  def perform(block_id)
    block = EthereumBlock.find(block_id)
    block_data = fetch_block(block.block_number)
    block.update(data: block_data)
    block_data['transactions']['items'].each do |transaction_data|
      block.ethereum_transactions.create!(transaction_hash: transaction_data['hash'])
    rescue => e
      Rails.logger.error "Error creating transaction #{transaction_data['hash']}: #{e.message}"
    end
  rescue => e
    Rails.logger.error "Job failed: #{e.message}"
    raise e
  end

  private

  def fetch_block(block_number)
    uri = URI("#{BASE_URL}/api/v1/ethereum/blocks/#{block_number}")
    http = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == 'https'
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    end
    response = http.get(uri.request_uri)
    JSON.parse(response.body)
  end
end