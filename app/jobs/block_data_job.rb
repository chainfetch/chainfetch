require 'net/http'
require 'json'
require 'openssl'
require 'async'

class BlockDataJob < ApplicationJob
  queue_as :default

  def perform(block_id)
    block = EthereumBlock.find(block_id)
    block_data = fetch_block(block.block_number)
    return if block_data.nil?
    block.update(data: block_data)
    summary = Ethereum::BlockSummaryService.new(block_data).call
    embedding = EmbeddingService.new(summary).call
    QdrantService.new.upsert_point(collection: "blocks", id: block_id.to_i, vector: embedding, payload: { summary: summary })
    block_data.dig('transactions', 'items').each do |transaction_data|
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
    100.times do
      block_data = Ethereum::BlockDataService.new(block_number).call
      return block_data if block_data
      sleep(1)
    end
    nil
  end
end