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
    
    # Check if response is successful
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "HTTP error for address #{@address_hash}: #{response.code} #{response.message}"
      Rails.logger.error "Response body: #{response.body[0..500]}" # Log first 500 chars
      raise ApiError, "HTTP #{response.code}: #{response.message}"
    end
    
    # Validate content type
    content_type = response['content-type']
    unless content_type&.include?('application/json')
      Rails.logger.error "Invalid content type for address #{@address_hash}: #{content_type}"
      Rails.logger.error "Response body: #{response.body[0..500]}" # Log first 500 chars
      raise ApiError, "Expected JSON response, got: #{content_type}"
    end
    
    JSON.parse(response.body)
  rescue JSON::ParserError => e
    Rails.logger.error "JSON parsing error for address #{@address_hash}: #{e.message}"
    Rails.logger.error "Response body: #{response&.body&.[](0..500)}" # Log first 500 chars
    raise ApiError, "Failed to parse JSON response: #{e.message}"
  rescue Net::TimeoutError, Net::ReadTimeout => e
    Rails.logger.error "Timeout error for address #{@address_hash}: #{e.message}"
    raise ApiError, "Request timeout: #{e.message}"
  rescue => e
    Rails.logger.error "Unexpected error for address #{@address_hash}: #{e.class.name}: #{e.message}"
    raise ApiError, "Service error: #{e.message}"
  end
end