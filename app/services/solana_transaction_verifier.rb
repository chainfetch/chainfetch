# frozen_string_literal: true

require 'net/http'
require 'json'

class SolanaTransactionVerifier
  # RPC endpoint chosen by environment. Allows overriding via ENV.
  RPC_URL = if Rails.env.production?
              ENV.fetch('SOLANA_MAINNET_RPC', 'https://mainnet.helius-rpc.com/?api-key=3de2b170-2a42-4523-937c-2979613ebf59')
            else
              ENV.fetch('SOLANA_DEVNET_RPC',  'https://api.devnet.solana.com')
            end

  Result = Struct.new(:valid?, :error_message, keyword_init: true)

  def initialize(signature:)
    @signature = signature
  end

  # ------------------------------------------------------------------
  # Public API
  # ------------------------------------------------------------------
  # A transaction is considered valid when:
  #   • getSignatureStatuses returns a record for the signature
  #   • confirmationStatus is "confirmed" or "finalized"
  #   • err is nil
  # We poll for up to 20s (20 attempts) to give RPC nodes time to index.
  # ------------------------------------------------------------------
  def call
    20.times do
      status = fetch_signature_status
      if status
        return Result.new(valid?: true) if status['err'].nil? && %w[confirmed finalized].include?(status['confirmationStatus'])
        return Result.new(valid?: false, error_message: 'Transaction failed on chain') if status['err']
      end
      sleep 1
    end

    Result.new(valid?: false, error_message: 'Transaction not found after waiting')
  rescue StandardError => e
    Rails.logger.error "Solana verifier error: #{e.message}"
    Result.new(valid?: false, error_message: 'Verifier exception')
  end

  private

  def fetch_signature_status
    body = {
      jsonrpc: '2.0',
      id:      1,
      method:  'getSignatureStatuses',
      params:  [[@signature], { searchTransactionHistory: true }]
    }

    res = Net::HTTP.post(URI(RPC_URL), body.to_json,
                        'Content-Type' => 'application/json',
                        'User-Agent'   => 'FetchSERP/1.0')
    json = JSON.parse(res.body)
    json.dig('result', 'value', 0)
  end
end 