require 'net/http'
require 'uri'
require 'json'

class Ethereum::AddressDataService < Ethereum::BaseService

  def initialize(address_hash)
    @address_hash = address_hash.downcase
    raise "Invalid Ethereum address format" unless @address_hash.match?(/\A0x[a-f0-9]{40}\z/)
  end

  def call
    uri = URI("#{BASE_URL}/api/v1/ethereum/addresses/#{@address_hash}")
    http = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == 'https'
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    end
    response = http.get(uri.request_uri)
    JSON.parse(response.body)
  end
end