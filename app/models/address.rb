class Address < ApplicationRecord
  has_one :contract_detail, dependent: :destroy
  has_many :address_transactions, dependent: :destroy
end
