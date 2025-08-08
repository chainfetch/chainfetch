class AddSolanaPublicKeyToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :solana_public_key, :string
  end
end
