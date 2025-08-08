class CreateApiSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :api_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent
      t.string :endpoint
      t.jsonb :request_params
      t.float :cost

      t.timestamps
    end
  end
end
