class AddRoleToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :role, :integer, default: 0
    add_column :users, :api_token, :string
    add_column :users, :api_credit, :float, default: 0
    add_column :users, :email_confirmed, :boolean, default: false
    add_column :users, :email_confirmation_token, :string
    add_column :users, :email_confirmation_sent_at, :datetime
  end
end
