class CreateEthereumSmartContracts < ActiveRecord::Migration[8.0]
  def change
    create_table :ethereum_smart_contracts do |t|
      t.string :address_hash, null: false
      t.jsonb :data

      t.timestamps
    end
    add_index :ethereum_smart_contracts, :address_hash, unique: true
    add_index :ethereum_smart_contracts, :data, using: :gin
  end
end
