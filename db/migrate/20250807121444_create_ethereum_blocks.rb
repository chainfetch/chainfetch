class CreateEthereumBlocks < ActiveRecord::Migration[8.0]
  def change
    create_table :ethereum_blocks do |t|
      t.integer :block_number, null: false
      t.jsonb :data

      t.timestamps
    end
    
    add_index :ethereum_blocks, :block_number, unique: true
    add_index :ethereum_blocks, :data, using: :gin
  end
end
