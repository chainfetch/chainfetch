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
    count = 0
    loop do
      uri = URI("#{BASE_URL}/api/v1/ethereum/blocks/#{block_number}")
      response = Net::HTTP.get_response(uri)
      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)
        return data if data && data.dig('info', 'message') != "Not found"
      end
      sleep(1)
      count += 1
      break if count > 100
    end
  end
end