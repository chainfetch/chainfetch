class CreateChannelSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :channel_subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :channel_name
      t.string :connection_id

      t.timestamps
    end
    add_index :channel_subscriptions, [:channel_name, :connection_id], unique: true
  end
end
