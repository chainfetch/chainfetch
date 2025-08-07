class EthereumTransaction < ApplicationRecord
  has_many :ethereum_address_transactions, dependent: :destroy
  has_many :ethereum_addresses, through: :ethereum_address_transactions
  validates :transaction_hash, presence: true, uniqueness: true
  belongs_to :ethereum_block
  after_create_commit :fetch_data

  private

  def fetch_data
    TransactionDataJob.perform_later(self.id)
  end
end
