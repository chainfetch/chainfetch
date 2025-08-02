class Api::V1::Ethereum::TokensController < Api::V1::Ethereum::BaseController
  # @summary Get token info
  # @parameter token(path) [!String] The token address to get info for
  # @response success(200) [Hash{info: Hash, transfers: Hash, holders: Hash, counters: Hash, instances: Hash}]
  def show
    token = params[:token]
    Sync do
      tasks = {
        info: Async { get_token_info(token) },
        transfers: Async { get_token_transfers(token) },
        holders: Async { get_token_holders(token) },
        counters: Async { get_token_counters(token) },
        instances: Async { get_token_instances(token) }
      }
      render json: tasks.transform_values(&:wait)
    end
  end

  private

  def get_token_info(token)
    blockscout_api_get("/tokens/#{token}")
  end

  def get_token_transfers(token)
    blockscout_api_get("/tokens/#{token}/transfers")
  end

  def get_token_holders(token)
    blockscout_api_get("/tokens/#{token}/holders")
  end

  def get_token_counters(token)
    blockscout_api_get("/tokens/#{token}/counters")
  end

  def get_token_instances(token)
    blockscout_api_get("/tokens/#{token}/instances")
  end

end





