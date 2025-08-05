require 'net/http'
require 'uri'
require 'json'

class Ethereum::AddressDataService < Ethereum::BaseService
  BASE_URL = Rails.env.production? ? "https://www.chainfetch.com/api/v1" : "http://localhost:3000/api/v1"

  def initialize(address_hash)
    @address_hash = address_hash.downcase
    raise "Invalid Ethereum address format" unless @address_hash.match?(/\A0x[a-f0-9]{40}\z/)
  end

  def call
    fetch_full_address_data
  end

  private

  def make_request(uri_string)
    uri = URI.parse(uri_string)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    
    request = Net::HTTP::Get.new(uri.request_uri)
    # Add authorization headers if needed
    
    response = http.request(request)
    
    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      Rails.logger.error "API request failed for #{uri_string}: #{response.code} #{response.message}"
      {}
    end
  rescue => e
    Rails.logger.error "Error during API request to #{uri_string}: #{e.class.name} - #{e.message}"
    {} # Return empty hash on failure
  end

  # Fetches all necessary data points from the single, correct API endpoint.
  def fetch_full_address_data
    uri_string = "#{BASE_URL}/ethereum/addresses/#{@address_hash}"
    make_request(uri_string)
  end
end