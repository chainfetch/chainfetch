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

ActiveRecord::Schema[8.0].define(version: 2025_08_07_161304) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

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
    t.index ["block_number"], name: "index_ethereum_blocks_on_block_number", unique: true
    t.index ["data"], name: "index_ethereum_blocks_on_data", using: :gin
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

  add_foreign_key "ethereum_address_transactions", "ethereum_addresses"
  add_foreign_key "ethereum_address_transactions", "ethereum_transactions"
  add_foreign_key "ethereum_transactions", "ethereum_blocks"
end
