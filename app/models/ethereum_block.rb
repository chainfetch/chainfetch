class EthereumBlock < ApplicationRecord
  validates :block_number, presence: true, uniqueness: true
  after_create_commit :fetch_data
  has_many :ethereum_transactions, dependent: :destroy

  def fetch_data
    BlockDataJob.perform_later(self.id)
  end
end
