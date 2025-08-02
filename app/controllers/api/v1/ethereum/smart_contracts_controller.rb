class Api::V1::Ethereum::SmartContractsController < Api::V1::Ethereum::BaseController
  # @summary Get smart contract info
  # @parameter address(path) [!String] The smart contract address
  # @response success(200) [Hash{smart_contract: Hash}]
  def show
    address = params[:address]
    render json: get_smart_contract(address)
  end

  private

  def get_smart_contract(address)
    blockscout_api_get("/smart-contracts/#{address}")
  end
end






