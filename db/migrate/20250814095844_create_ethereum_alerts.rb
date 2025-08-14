class CreateEthereumAlerts < ActiveRecord::Migration[8.0]
  def change
    create_table :ethereum_alerts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :address_hash
      t.string :webhook_url
      t.integer :status, default: 0
      t.datetime :last_triggered_at

      t.timestamps
    end

    add_index :ethereum_alerts, [:user_id, :address_hash], unique: true
  end
end
