class AddEthereumBlockIdToEthereumTransactions < ActiveRecord::Migration[8.0]
  def change
    add_reference :ethereum_transactions, :ethereum_block, null: false, foreign_key: true
  end
end
