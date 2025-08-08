class Ethereum::BlockDataService < Ethereum::BaseService
  def initialize(block_number)
    @block_number = block_number
  end

  def call
    uri = URI("#{BASE_URL}/api/v1/ethereum/blocks/#{@block_number}")
    response = Net::HTTP.get_response(uri)
    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      return data if data && data.dig('info', 'message') != "Not found"
    end
    nil
  end
end