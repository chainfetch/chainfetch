class CreateEthereumTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :ethereum_tokens do |t|
      t.string :address_hash, null: false
      t.jsonb :data

      t.timestamps
    end
    add_index :ethereum_tokens, :address_hash, unique: true
    add_index :ethereum_tokens, :data, using: :gin
  end
end
