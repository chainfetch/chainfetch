class Api::V1::Ethereum::BaseController < Api::V1::BaseController
  def blockscout_api_get(endpoint)
    blockscout_api_url = "https://eth.blockscout.com/api/v2"
    uri = URI("#{blockscout_api_url}#{endpoint}")
    response = Net::HTTP.get_response(uri)
    JSON.parse(response.body)
  rescue JSON::ParserError
    { error: "Failed to parse response from Block explorer API" }
  rescue => e
    { error: e.message }
  end
end