class Api::V1::Ethereum::BlocksController < Api::V1::Ethereum::BaseController
  # @summary Get block info
  # @parameter block(path) [!String] The block number to get info for
  # @response success(200) [Hash{info: Hash, transactions: Hash, withdrawals: Hash}]
  def show
    block = params[:block]
    Sync do
      tasks = {
        info: Async { get_block_info(block) },
        transactions: Async { get_block_transactions(block) },
        withdrawals: Async { get_block_withdrawals(block) },
      }

      render json: tasks.transform_values(&:wait)
    end
  end

  private

  def get_block_info(block)
    blockscout_api_get("/blocks/#{block}")
  end

  def get_block_transactions(block)
    blockscout_api_get("/blocks/#{block}/transactions")
  end

  def get_block_withdrawals(block)
    blockscout_api_get("/blocks/#{block}/withdrawals")
  end

end


