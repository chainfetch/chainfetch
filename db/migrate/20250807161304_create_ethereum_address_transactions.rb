class CreateEthereumAddressTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :ethereum_address_transactions do |t|
      t.references :ethereum_address, null: false, foreign_key: true
      t.references :ethereum_transaction, null: false, foreign_key: true

      t.timestamps
    end
    add_index :ethereum_address_transactions, [:ethereum_address_id, :ethereum_transaction_id], unique: true
  end
end
