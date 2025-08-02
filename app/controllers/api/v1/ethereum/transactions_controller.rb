class Api::V1::Ethereum::TransactionsController < Api::V1::Ethereum::BaseController
  # @summary Get transaction info 
  # @parameter transaction(path) [!String] The transaction hash to get info for
  # @response success(200) [Hash{info: Hash, token_transfers: Hash, internal_transactions: Hash, logs: Hash, raw_trace: Hash, state_changes: Hash, summary: Hash}]
  def show
    transaction = params[:transaction]
    Sync do
      tasks = {
        info: Async { get_transaction_info(transaction) },
        token_transfers: Async { get_transaction_token_transfers(transaction) },
        internal_transactions: Async { get_transaction_internal_transactions(transaction) },
        logs: Async { get_transaction_logs(transaction) },
        raw_trace: Async { get_transaction_raw_trace(transaction) },
        state_changes: Async { get_transaction_state_changes(transaction) },
        summary: Async { get_transaction_summary(transaction) },
      }

      render json: tasks.transform_values(&:wait)
    end
  end

  private

  def get_transaction_info(transaction)
    blockscout_api_get("/transactions/#{transaction}")
  end

  def get_transaction_token_transfers(transaction)
    blockscout_api_get("/transactions/#{transaction}/token-transfers")
  end

  def get_transaction_internal_transactions(transaction)
    blockscout_api_get("/transactions/#{transaction}/internal-transactions")
  end

  def get_transaction_logs(transaction)
    blockscout_api_get("/transactions/#{transaction}/logs")
  end

  def get_transaction_raw_trace(transaction)
    blockscout_api_get("/transactions/#{transaction}/raw-trace")
  end

  def get_transaction_state_changes(transaction)
    blockscout_api_get("/transactions/#{transaction}/state-changes")
  end

  def get_transaction_summary(transaction)
    blockscout_api_get("/transactions/#{transaction}/summary")
  end

end



