# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_08_13_201127) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "api_sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.string "endpoint"
    t.jsonb "request_params"
    t.float "cost"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_api_sessions_on_user_id"
  end

  create_table "channel_subscriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "channel_name"
    t.string "connection_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["channel_name", "connection_id"], name: "index_channel_subscriptions_on_channel_name_and_connection_id", unique: true
    t.index ["user_id"], name: "index_channel_subscriptions_on_user_id"
  end

  create_table "ethereum_address_transactions", force: :cascade do |t|
    t.bigint "ethereum_address_id", null: false
    t.bigint "ethereum_transaction_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ethereum_address_id", "ethereum_transaction_id"], name: "idx_on_ethereum_address_id_ethereum_transaction_id_56e9ca97fb", unique: true
    t.index ["ethereum_address_id"], name: "index_ethereum_address_transactions_on_ethereum_address_id"
    t.index ["ethereum_transaction_id"], name: "index_ethereum_address_transactions_on_ethereum_transaction_id"
  end

  create_table "ethereum_addresses", force: :cascade do |t|
    t.string "address_hash", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "data"
    t.index ["address_hash"], name: "index_ethereum_addresses_on_address_hash", unique: true
    t.index ["data"], name: "index_ethereum_addresses_on_data", using: :gin
  end

  create_table "ethereum_blocks", force: :cascade do |t|
    t.integer "block_number", null: false
    t.jsonb "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "summary"
    t.index ["block_number"], name: "index_ethereum_blocks_on_block_number", unique: true
    t.index ["data"], name: "index_ethereum_blocks_on_data", using: :gin
  end

  create_table "ethereum_smart_contracts", force: :cascade do |t|
    t.string "address_hash", null: false
    t.jsonb "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["address_hash"], name: "index_ethereum_smart_contracts_on_address_hash", unique: true
    t.index ["data"], name: "index_ethereum_smart_contracts_on_data", using: :gin
  end

  create_table "ethereum_tokens", force: :cascade do |t|
    t.string "address_hash", null: false
    t.jsonb "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["address_hash"], name: "index_ethereum_tokens_on_address_hash", unique: true
    t.index ["data"], name: "index_ethereum_tokens_on_data", using: :gin
  end

  create_table "ethereum_transactions", force: :cascade do |t|
    t.string "transaction_hash", null: false
    t.jsonb "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "ethereum_block_id", null: false
    t.index ["data"], name: "index_ethereum_transactions_on_data", using: :gin
    t.index ["ethereum_block_id"], name: "index_ethereum_transactions_on_ethereum_block_id"
    t.index ["transaction_hash"], name: "index_ethereum_transactions_on_transaction_hash", unique: true
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "payment_intent_id", null: false
    t.integer "amount_cents", null: false
    t.integer "credits", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payment_intent_id"], name: "index_payments_on_payment_intent_id", unique: true
    t.index ["user_id", "status"], name: "index_payments_on_user_id_and_status"
    t.index ["user_id"], name: "index_payments_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "role", default: 0
    t.string "api_token"
    t.float "api_credit", default: 0.0
    t.boolean "email_confirmed", default: false
    t.string "email_confirmation_token"
    t.datetime "email_confirmation_sent_at"
    t.string "solana_public_key"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "api_sessions", "users"
  add_foreign_key "channel_subscriptions", "users"
  add_foreign_key "ethereum_address_transactions", "ethereum_addresses"
  add_foreign_key "ethereum_address_transactions", "ethereum_transactions"
  add_foreign_key "ethereum_transactions", "ethereum_blocks"
  add_foreign_key "payments", "users"
  add_foreign_key "sessions", "users"
end
