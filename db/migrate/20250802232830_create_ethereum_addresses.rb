class CreateEthereumAddresses < ActiveRecord::Migration[8.0]
  def change
    create_table :ethereum_addresses do |t|
      t.string :address_hash, null: false, index: { unique: true }

      t.timestamps
    end
  end
end
