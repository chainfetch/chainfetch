class App::Ethereum::TransactionsController < App::BaseController
  def search
    @results = TransactionDataSearchService.new(params[:query], full_json: true).call
    Current.user.decrement!(:api_credit, 1)
  end

  def summary
    transaction_hash = params[:transaction_hash]
    ethereum_transaction = EthereumTransaction.find_by(transaction_hash: transaction_hash)
    
    if ethereum_transaction&.data.present?
      @summary = Ethereum::TransactionSummaryService.new(ethereum_transaction.data).call
      @transaction_hash = transaction_hash
      render partial: 'transaction_summary', locals: { transaction_hash: @transaction_hash, summary: @summary }
    else
      # If transaction doesn't exist or data is not available, show loading state
      render partial: 'transaction_summary', locals: { transaction_hash: transaction_hash, summary: nil }
    end
  end

  def detail
    transaction_hash = params[:transaction_hash]
    ethereum_transaction = EthereumTransaction.find_by(transaction_hash: transaction_hash)
    
    if ethereum_transaction&.data.present?
      # Format it to match the structure expected by the _transaction partial
      @transaction = {
        'transaction_hash' => transaction_hash,
        'data' => ethereum_transaction.data
      }
      render partial: 'transaction', locals: { transaction: @transaction }
    else
      # If transaction doesn't exist in DB, create a simple error message with the same styling
      render partial: 'transaction_error', locals: { transaction_hash: transaction_hash, error_message: "Transaction data not yet indexed in our database" }
    end
  end
end
