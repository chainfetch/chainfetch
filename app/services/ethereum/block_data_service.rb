class Ethereum::BlockDataService < Ethereum::BaseService
  def initialize(block_number)
    @block_number = block_number
  end

  def call
    uri = URI("#{BASE_URL}/api/v1/ethereum/blocks/#{@block_number}")
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