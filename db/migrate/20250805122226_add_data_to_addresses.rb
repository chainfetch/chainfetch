class AddDataToAddresses < ActiveRecord::Migration[8.0]
  def change
    add_column :addresses, :data, :jsonb
    add_index :addresses, :data, using: :gin
  end
end
