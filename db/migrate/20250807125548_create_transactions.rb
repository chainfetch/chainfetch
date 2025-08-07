class CreateTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :transactions do |t|
      t.string :transaction_hash, null: false
      t.jsonb :data

      t.timestamps
    end

    add_index :transactions, :transaction_hash, unique: true
    add_index :transactions, :data, using: :gin
  end
end
