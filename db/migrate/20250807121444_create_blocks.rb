class CreateBlocks < ActiveRecord::Migration[8.0]
  def change
    create_table :blocks do |t|
      t.integer :block_number, null: false
      t.jsonb :data

      t.timestamps
    end
    
    add_index :blocks, :block_number, unique: true
    add_index :blocks, :data, using: :gin
  end
end
