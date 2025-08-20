class AddEthBalanceToEthereumAddresses < ActiveRecord::Migration[8.0]
  def change
    add_column :ethereum_addresses, :eth_balance, :decimal, precision: 36, scale: 18
    add_index :ethereum_addresses, :eth_balance
  end
end
