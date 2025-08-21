class SmartContractDataJob < ApplicationJob
  queue_as :default

  def perform(smart_contract_id)
    smart_contract = EthereumSmartContract.find(smart_contract_id)
    smart_contract_data = Ethereum::SmartContractDataService.new(smart_contract.address_hash).call
    smart_contract.update!(data: smart_contract_data)
    if rand(5) == 0
      summary = Ethereum::SmartContractSummaryService.new(smart_contract_data, smart_contract.address_hash).call
      embedding = Embedding::GeminiService.new(summary).embed_document
      QdrantService.new.upsert_point(collection: "smart_contracts", id: smart_contract_id.to_i, vector: embedding, payload: { summary: summary })
    end
  end
end