class Api::V1::Ethereum::TokenInstancesController < Api::V1::Ethereum::BaseController
  # @summary Get NFT instance info
  # @parameter token(path) [!String] The token address
  # @parameter id(path) [!String] The instance ID
  # @response success(200) [Hash{instance: Hash, transfers: Hash, holders: Hash, transfers_count: Hash, refetch_metadata: Hash}]
  def show
    token = params[:token]
    instance_id = params[:instance_id]
    Sync do
      tasks = {
        instance: Async { get_token_instance(token, instance_id) },
        transfers: Async { get_token_instance_transfers(token, instance_id) },
        holders: Async { get_token_instance_holders(token, instance_id) },
        transfers_count: Async { get_token_instance_transfers_count(token, instance_id) }
      }
      render json: tasks.transform_values(&:wait)
    end
  end

  private

  def get_token_instance(token, instance_id)
    blockscout_api_get("/tokens/#{token}/instances/#{instance_id}")
  end

  def get_token_instance_transfers(token, instance_id)
    blockscout_api_get("/tokens/#{token}/instances/#{instance_id}/transfers")
  end

  def get_token_instance_holders(token, instance_id)
    blockscout_api_get("/tokens/#{token}/instances/#{instance_id}/holders")
  end

  def get_token_instance_transfers_count(token, instance_id)
    blockscout_api_get("/tokens/#{token}/instances/#{instance_id}/transfers-count")
  end

end


