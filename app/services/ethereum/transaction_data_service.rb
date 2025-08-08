require 'net/http'
require 'uri'
require 'json'

class Ethereum::TransactionDataService < Ethereum::BaseService

  def initialize(transaction_hash)
    @transaction_hash = transaction_hash.downcase
    raise "Invalid Ethereum transaction format" unless @transaction_hash.match?(/\A0x[a-f0-9]{64}\z/)
  end

  def call
    uri = URI("#{BASE_URL}/api/v1/ethereum/transactions/#{@transaction_hash}")
    http = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == 'https'
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    end
    
    request = Net::HTTP::Get.new(uri.request_uri)
    request['Authorization'] = "Bearer #{BEARER_TOKEN}"
    response = http.request(request)
    
    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      return data if data && data.dig('info', 'message') != "Not found"
    end
    nil
  end
end