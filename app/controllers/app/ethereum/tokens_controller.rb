class App::Ethereum::TokensController < App::BaseController
  def search
    @results = TokenDataSearchService.new(params[:query], full_json: true).call
    Current.user.decrement!(:api_credit, 1)
  end

  def summary
    token_address = params[:token_address]
    ethereum_token = EthereumToken.find_by(address_hash: token_address)
    
    if ethereum_token&.data.present?
      @summary = Ethereum::TokenSummaryService.new(ethereum_token.data).call
      @token_address = token_address
      render partial: 'token_summary', locals: { token_address: @token_address, summary: @summary }
    else
      render partial: 'token_summary', locals: { token_address: token_address, summary: nil }
    end
  end

  def detail
    token_address = params[:token_address]
    ethereum_token = EthereumToken.find_by(address_hash: token_address)
    
    if ethereum_token&.data.present?
      @token = {
        'address_hash' => token_address,
        'data' => ethereum_token.data
      }
      render partial: 'token', locals: { token: @token }
    else
      render partial: 'token_error', locals: { token_address: token_address, error_message: "Token data not yet indexed in our database" }
    end
  end
end
