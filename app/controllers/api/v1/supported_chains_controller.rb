class Api::V1::SupportedChainsController < Api::V1::BaseController
  # @summary Get supported chains
  # @response success(200) [Array<Hash{id: String, symbol: String}>]
  def index
    render json: [
      {id: "bitcoin", symbol: "BTC"},
      {id: "ethereum", symbol: "ETH"}
    ]
  end
end