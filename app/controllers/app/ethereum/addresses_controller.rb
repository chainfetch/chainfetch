class App::Ethereum::AddressesController < App::BaseController
  def search
    @results = AddressDataSearchService.new(params[:query], full_json: true).call
    Current.user.decrement!(:api_credit, 1)
  end

  def summary
    address_hash = params[:address_hash]
    ethereum_address = EthereumAddress.find_by(address_hash: address_hash)
    
    if ethereum_address&.data.present?
      @summary = Ethereum::AddressSummaryService.new(ethereum_address.data).call
      @address_hash = address_hash
      render partial: 'address_summary', locals: { address_hash: @address_hash, summary: @summary }
    else
      # If address doesn't exist or data is not available, show loading state
      render partial: 'address_summary', locals: { address_hash: address_hash, summary: nil }
    end
  end

  def detail
    address_hash = params[:address_hash]
    ethereum_address = EthereumAddress.find_by(address_hash: address_hash)
    
    if ethereum_address&.data.present?
      # Format it to match the structure expected by the _address partial
      @address = {
        'address_hash' => address_hash,
        'data' => ethereum_address.data
      }
      render partial: 'address', locals: { address: @address }
    else
      # If address doesn't exist in DB, create a simple error message with the same styling
      render partial: 'address_error', locals: { address_hash: address_hash, error_message: "Address data not yet indexed in our database" }
    end
  end
end