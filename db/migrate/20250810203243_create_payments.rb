class CreatePayments < ActiveRecord::Migration[8.0]
  def change
    create_table :payments do |t|
      t.references :user, null: false, foreign_key: true
      t.string :payment_intent_id, null: false
      t.integer :amount_cents, null: false
      t.integer :credits, null: false
      t.integer :status, default: 0, null: false

      t.timestamps
    end

    add_index :payments, [:user_id, :status]
    add_index :payments, :payment_intent_id, unique: true
  end
end
