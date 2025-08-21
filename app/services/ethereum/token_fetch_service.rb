require 'net/http'
require 'uri'
require 'json'

class Ethereum::TokenFetchService < Ethereum::BaseService

  def initialize(options = {})
    @page_token = options[:page_token]
    @limit = options[:limit] || 50
    @types = options[:types] || "ERC-20,ERC-721,ERC-1155"
  end

  def call
    fetch_tokens_from_blockscout
  end

  def fetch_and_create_tokens
    tokens_data = fetch_tokens_from_blockscout
    created_tokens = []
    
    return { tokens: [], errors: [], total_processed: 0 } unless tokens_data.dig("items")
    
    tokens_data["items"].each do |token_data|
      begin
        address_hash = token_data["address_hash"]
        next unless address_hash.present?
        
        token = EthereumToken.find_or_create_by!(address_hash: address_hash.downcase)
        TokenDataJob.perform_later(token.id) if token.data.blank?
        created_tokens << token
        Rails.logger.info "Created token: #{token.address_hash} (#{token_data['name']})"
        
      rescue => e
        Rails.logger.error "Failed to create token #{token_data['address_hash']}: #{e.message}"
      end
    end
    
    {
      tokens: created_tokens,
      next_page_token: tokens_data.dig("next_page_params", "items_count"),
      total_processed: tokens_data["items"].size,
      created_count: created_tokens.size
    }
  end

  private

  def fetch_tokens_from_blockscout
    uri = build_uri
    http = Net::HTTP.new(uri.host, uri.port)
    
    if uri.scheme == 'https'
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    end
    
    request = Net::HTTP::Get.new(uri.request_uri)
    request['Accept'] = 'application/json'
    
    response = http.request(request)
    
    # Check if response is successful
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "HTTP error fetching tokens: #{response.code} #{response.message}"
      Rails.logger.error "Response body: #{response.body[0..500]}" # Log first 500 chars
      raise ApiError, "HTTP #{response.code}: #{response.message}"
    end
    
    # Validate content type
    content_type = response['content-type']
    unless content_type&.include?('application/json')
      Rails.logger.error "Invalid content type: #{content_type}"
      Rails.logger.error "Response body: #{response.body[0..500]}" # Log first 500 chars
      raise ApiError, "Expected JSON response, got: #{content_type}"
    end
    
    JSON.parse(response.body)
  rescue JSON::ParserError => e
    Rails.logger.error "JSON parsing error: #{e.message}"
    Rails.logger.error "Response body: #{response&.body&.[](0..500)}" # Log first 500 chars
    raise ApiError, "Failed to parse JSON response: #{e.message}"
  rescue Net::ReadTimeout, Net::OpenTimeout => e
    Rails.logger.error "Timeout error: #{e.message}"
    raise ApiError, "Request timeout: #{e.message}"
  rescue => e
    Rails.logger.error "Unexpected error: #{e.class.name}: #{e.message}"
    raise ApiError, "Service error: #{e.message}"
  end

  def build_uri
    base_url = "https://eth.blockscout.com/api/v2/tokens"
    params = {
      "type" => @types
    }
    
    params["items_count"] = @page_token if @page_token.present?
    params["limit"] = @limit if @limit.present?
    
    query_string = URI.encode_www_form(params)
    URI("#{base_url}?#{query_string}")
  end
end