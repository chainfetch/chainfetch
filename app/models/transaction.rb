class Transaction < ApplicationRecord
  validates :transaction_hash, presence: true, uniqueness: true
end
