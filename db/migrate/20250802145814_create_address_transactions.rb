class CreateAddressTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :address_transactions do |t|
      t.references :address, null: false, foreign_key: true
      t.string :tx_hash
      t.integer :internal_tx_index, default: 0 # To uniquely identify internal transfers
      t.string :tx_type
      t.string :method
      t.bigint :block_number
      t.datetime :timestamp
      t.string :from_address
      t.string :to_address
      t.decimal :value, precision: 36, scale: 18
      t.decimal :fee, precision: 36, scale: 18
      t.boolean :success
      t.jsonb :raw_data

      t.timestamps
    end
    # The combination of a transaction hash and an internal index must be unique.
    add_index :address_transactions, [:tx_hash, :internal_tx_index], unique: true
  end
end
