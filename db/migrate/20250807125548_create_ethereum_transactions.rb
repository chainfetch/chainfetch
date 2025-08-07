class CreateEthereumTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :ethereum_transactions do |t|
      t.string :transaction_hash, null: false
      t.jsonb :data

      t.timestamps
    end

    add_index :ethereum_transactions, :transaction_hash, unique: true
    add_index :ethereum_transactions, :data, using: :gin
  end
end
