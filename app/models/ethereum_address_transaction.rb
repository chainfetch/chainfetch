class EthereumAddressTransaction < ApplicationRecord
  belongs_to :ethereum_address
  belongs_to :ethereum_transaction
end
