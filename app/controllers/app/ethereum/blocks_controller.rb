class App::Ethereum::BlocksController < App::BaseController
  def search
    @results = BlockDataSearchService.new(params[:query], full_json: true).call
    Current.user.decrement!(:api_credit, 1)
  end

  def summary
    block_number = params[:block_number]
    ethereum_block = EthereumBlock.find_by(block_number: block_number)
    
    if ethereum_block&.data.present?
      @summary = Ethereum::BlockSummaryService.new(ethereum_block.data).call
      @block_number = block_number
      render partial: 'block_summary', locals: { block_number: @block_number, summary: @summary }
    else
      # If block doesn't exist or data is not available, show loading state
      render partial: 'block_summary', locals: { block_number: block_number, summary: nil }
    end
  end

  def detail
    block_number = params[:block_number]
    ethereum_block = EthereumBlock.find_by(block_number: block_number)
    
    if ethereum_block&.data.present?
      # Format it to match the structure expected by the _block partial
      @block = {
        'block_number' => block_number,
        'data' => ethereum_block.data
      }
      render partial: 'block', locals: { block: @block }
    else
      # If block doesn't exist in DB, create a simple error message with the same styling
      render partial: 'block_error', locals: { block_number: block_number, error_message: "Block data not yet indexed in our database" }
    end
  end
end