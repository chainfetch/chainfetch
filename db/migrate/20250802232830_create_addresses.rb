class CreateAddresses < ActiveRecord::Migration[8.0]
  def change
    create_table :addresses do |t|
      t.string :address_hash, null: false, index: { unique: true }
      t.text :summary
      t.vector :summary_embedding, limit: 4096

      t.timestamps
    end
  end
end
