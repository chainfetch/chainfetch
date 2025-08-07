class AddDataToEthereumAddresses < ActiveRecord::Migration[8.0]
  def change
    add_column :ethereum_addresses, :data, :jsonb
    add_index :ethereum_addresses, :data, using: :gin
  end
end
