class App::Ethereum::SmartContractsController < App::BaseController
  def search
    @results = SmartContractDataSearchService.new(params[:query], full_json: true).call
    Current.user.decrement!(:api_credit, 1)
  end

  def summary
    address_hash = params[:address_hash]
    ethereum_smart_contract = EthereumSmartContract.find_by(address_hash: address_hash)
    
    if ethereum_smart_contract&.data.present?
      @summary = Ethereum::SmartContractSummaryService.new(ethereum_smart_contract.data, address_hash).call
      @address_hash = address_hash
      render partial: 'smart_contract_summary', locals: { address_hash: @address_hash, summary: @summary }
    else
      render partial: 'smart_contract_summary', locals: { address_hash: address_hash, summary: nil }
    end
  end

  def detail
    address_hash = params[:address_hash]
    ethereum_smart_contract = EthereumSmartContract.find_by(address_hash: address_hash)
    
    if ethereum_smart_contract&.data.present?
      @smart_contract = {
        'address_hash' => address_hash,
        'data' => ethereum_smart_contract.data
      }
      render partial: 'smart_contract', locals: { smart_contract: @smart_contract }
    else
      render partial: 'smart_contract_error', locals: { address_hash: address_hash, error_message: "Smart contract data not yet indexed in our database" }
    end
  end
end
