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

ActiveRecord::Schema[8.0].define(version: 2025_08_02_145814) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "address_transactions", force: :cascade do |t|
    t.bigint "address_id", null: false
    t.string "tx_hash"
    t.integer "internal_tx_index", default: 0
    t.string "tx_type"
    t.string "method"
    t.bigint "block_number"
    t.datetime "timestamp"
    t.string "from_address"
    t.string "to_address"
    t.decimal "value", precision: 36, scale: 18
    t.decimal "fee", precision: 36, scale: 18
    t.boolean "success"
    t.jsonb "raw_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["address_id"], name: "index_address_transactions_on_address_id"
    t.index ["tx_hash", "internal_tx_index"], name: "index_address_transactions_on_tx_hash_and_internal_tx_index", unique: true
  end

  create_table "addresses", force: :cascade do |t|
    t.string "address", null: false
    t.integer "nonce"
    t.boolean "is_contract", default: false, null: false
    t.boolean "is_smart_wallet", default: false
    t.string "entry_point_address"
    t.string "paymaster_address"
    t.string "bundler_address"
    t.boolean "supports_eip7702", default: false
    t.string "creator_address"
    t.string "creation_transaction_hash"
    t.string "creation_method"
    t.string "init_code_hash"
    t.decimal "eth_balance", precision: 36, scale: 18, default: "0.0"
    t.decimal "staked_eth_balance", precision: 36, scale: 18, default: "0.0"
    t.decimal "total_eth_value_usd", precision: 20, scale: 4
    t.jsonb "historical_balances", default: {}
    t.jsonb "historical_token_balances", default: {}
    t.bigint "eth_balance_updated_at_block"
    t.bigint "staked_balance_updated_at_block"
    t.decimal "total_eth_spent_on_fees", precision: 36, scale: 18, default: "0.0"
    t.decimal "total_eth_received", precision: 36, scale: 18, default: "0.0"
    t.decimal "total_eth_sent", precision: 36, scale: 18, default: "0.0"
    t.bigint "mined_blocks_count", default: 0
    t.bigint "beacon_deposits_count", default: 0
    t.bigint "beacon_withdrawals_count", default: 0
    t.bigint "validator_index"
    t.string "validator_status"
    t.jsonb "fungible_token_holdings", default: {}
    t.jsonb "non_fungible_token_holdings", default: {}
    t.jsonb "specialized_token_data", default: {}
    t.bigint "transaction_count", default: 0
    t.bigint "user_operations_count", default: 0
    t.bigint "failed_transaction_count", default: 0
    t.bigint "internal_transaction_count", default: 0
    t.bigint "token_transfers_count", default: 0
    t.bigint "erc20_transaction_count", default: 0
    t.bigint "erc721_transaction_count", default: 0
    t.bigint "erc1155_transaction_count", default: 0
    t.datetime "first_transaction_at"
    t.datetime "last_transaction_at"
    t.bigint "first_seen_block_number"
    t.bigint "last_seen_block_number"
    t.bigint "total_gas_used", default: 0
    t.jsonb "multichain_balances", default: {}
    t.bigint "bridge_deposits_count", default: 0
    t.bigint "bridge_withdrawals_count", default: 0
    t.string "ens_name"
    t.string "ens_avatar_url"
    t.jsonb "ens_records", default: {}
    t.string "labels", default: [], array: true
    t.integer "risk_score"
    t.string "sanctioned_by", default: [], array: true
    t.boolean "is_scam", default: false
    t.boolean "has_beacon_chain_withdrawals"
    t.boolean "has_logs"
    t.boolean "has_token_transfers"
    t.boolean "has_tokens"
    t.jsonb "private_tags", default: {}
    t.decimal "exchange_rate", precision: 20, scale: 4
    t.string "watchlist_address_id"
    t.string "watchlist_names", default: [], array: true
    t.string "sync_status", default: "pending"
    t.string "error_last_sync"
    t.datetime "last_synced_at"
    t.datetime "last_seen_at"
    t.bigint "updated_at_block"
    t.boolean "fusaka_compatible", default: false
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["address"], name: "index_addresses_on_address", unique: true
    t.index ["creator_address"], name: "index_addresses_on_creator_address"
    t.index ["ens_name"], name: "index_addresses_on_ens_name", unique: true, where: "(ens_name IS NOT NULL)"
    t.index ["ens_records"], name: "index_addresses_on_ens_records", using: :gin
    t.index ["first_seen_block_number"], name: "index_addresses_on_first_seen_block_number"
    t.index ["is_contract"], name: "index_addresses_on_is_contract"
    t.index ["is_scam"], name: "index_addresses_on_is_scam"
    t.index ["is_smart_wallet"], name: "index_addresses_on_is_smart_wallet"
    t.index ["labels"], name: "index_addresses_on_labels", using: :gin
    t.index ["last_seen_block_number"], name: "index_addresses_on_last_seen_block_number"
    t.index ["mined_blocks_count"], name: "index_addresses_on_mined_blocks_count"
    t.index ["nonce"], name: "index_addresses_on_nonce"
    t.index ["paymaster_address"], name: "index_addresses_on_paymaster_address"
    t.index ["risk_score"], name: "index_addresses_on_risk_score"
    t.index ["supports_eip7702"], name: "index_addresses_on_supports_eip7702"
    t.index ["token_transfers_count"], name: "index_addresses_on_token_transfers_count"
    t.index ["validator_index"], name: "index_addresses_on_validator_index"
  end

  create_table "contract_details", force: :cascade do |t|
    t.bigint "address_id", null: false
    t.string "name"
    t.string "token_name"
    t.string "token_symbol"
    t.integer "token_decimals"
    t.decimal "token_total_supply", precision: 36, scale: 18
    t.boolean "is_self_destructed", default: false
    t.jsonb "abi", default: {}
    t.text "bytecode"
    t.text "creation_bytecode"
    t.integer "code_size"
    t.string "contract_code_md5"
    t.bigint "creation_block_number"
    t.string "deployer_bytecode_hash"
    t.boolean "is_verified", default: false
    t.boolean "is_partially_verified", default: false
    t.boolean "is_verified_via_sourcify", default: false
    t.boolean "is_verified_via_eth_bytecode_db", default: false
    t.boolean "autodetect_constructor_args", default: false
    t.datetime "verified_at"
    t.integer "verification_attempts", default: 0
    t.text "source_code"
    t.text "flattened_source_code"
    t.jsonb "source_code_files", default: {}
    t.jsonb "secondary_sources", default: {}
    t.string "file_path"
    t.string "compilation_target_file_name"
    t.string "license_type"
    t.jsonb "verification_metadata", default: {}
    t.string "compiler_version"
    t.boolean "is_vyper_contract", default: false
    t.boolean "is_yul_contract", default: false
    t.boolean "is_optimization_enabled"
    t.integer "optimization_runs"
    t.string "evm_version"
    t.string "precompiles_supported", default: [], array: true
    t.text "constructor_arguments"
    t.jsonb "external_libraries", default: {}
    t.jsonb "compiler_settings", default: {}
    t.boolean "is_proxy", default: false
    t.boolean "is_minimal_proxy", default: false
    t.string "proxy_type"
    t.string "implementation_address"
    t.string "implementation_name"
    t.string "implementation_slot"
    t.string "admin_address"
    t.string "beacon_address"
    t.integer "upgrade_count", default: 0
    t.datetime "implementation_fetched_at"
    t.string "supported_erc_standards", default: [], array: true
    t.boolean "is_erc20", default: false
    t.boolean "is_erc223", default: false
    t.boolean "is_erc721", default: false
    t.boolean "is_erc777", default: false
    t.boolean "is_erc1155", default: false
    t.boolean "is_erc2981", default: false
    t.boolean "is_erc3643", default: false
    t.boolean "is_erc404", default: false
    t.boolean "is_erc6551", default: false
    t.boolean "is_erc6900", default: false
    t.boolean "is_erc7828", default: false
    t.boolean "is_erc7861", default: false
    t.boolean "is_erc7878", default: false
    t.boolean "is_erc7902", default: false
    t.boolean "is_erc7920", default: false
    t.boolean "is_erc7930", default: false
    t.boolean "is_erc7943", default: false
    t.boolean "is_changed_bytecode", default: false
    t.datetime "bytecode_checked_at"
    t.boolean "is_decompiled", default: false
    t.text "decompiled_code"
    t.integer "security_audit_score"
    t.decimal "circulating_market_cap", precision: 30, scale: 4
    t.string "icon_url"
    t.bigint "holders_count"
    t.string "website"
    t.string "token_type"
    t.decimal "volume_24h", precision: 30, scale: 4
    t.string "verified_twin_address_hash"
    t.string "sourcify_repo_url"
    t.jsonb "decoded_constructor_args", default: {}
    t.boolean "is_verified_via_verifier_alliance", default: false
    t.boolean "is_blueprint", default: false
    t.boolean "is_fully_verified", default: false
    t.boolean "can_be_visualized_via_sol2uml", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["abi"], name: "index_contract_details_on_abi", using: :gin
    t.index ["address_id"], name: "index_contract_details_on_address_id", unique: true
    t.index ["admin_address"], name: "index_contract_details_on_admin_address"
    t.index ["creation_block_number"], name: "index_contract_details_on_creation_block_number"
    t.index ["implementation_address"], name: "index_contract_details_on_implementation_address"
    t.index ["is_erc1155"], name: "index_contract_details_on_is_erc1155"
    t.index ["is_erc20"], name: "index_contract_details_on_is_erc20"
    t.index ["is_erc223"], name: "index_contract_details_on_is_erc223"
    t.index ["is_erc2981"], name: "index_contract_details_on_is_erc2981"
    t.index ["is_erc3643"], name: "index_contract_details_on_is_erc3643"
    t.index ["is_erc404"], name: "index_contract_details_on_is_erc404"
    t.index ["is_erc6551"], name: "index_contract_details_on_is_erc6551"
    t.index ["is_erc6900"], name: "index_contract_details_on_is_erc6900"
    t.index ["is_erc721"], name: "index_contract_details_on_is_erc721"
    t.index ["is_erc777"], name: "index_contract_details_on_is_erc777"
    t.index ["is_erc7828"], name: "index_contract_details_on_is_erc7828"
    t.index ["is_erc7861"], name: "index_contract_details_on_is_erc7861"
    t.index ["is_erc7878"], name: "index_contract_details_on_is_erc7878"
    t.index ["is_erc7902"], name: "index_contract_details_on_is_erc7902"
    t.index ["is_erc7920"], name: "index_contract_details_on_is_erc7920"
    t.index ["is_erc7930"], name: "index_contract_details_on_is_erc7930"
    t.index ["is_erc7943"], name: "index_contract_details_on_is_erc7943"
    t.index ["is_proxy"], name: "index_contract_details_on_is_proxy"
    t.index ["is_verified"], name: "index_contract_details_on_is_verified"
    t.index ["name"], name: "index_contract_details_on_name"
    t.index ["precompiles_supported"], name: "index_contract_details_on_precompiles_supported", using: :gin
    t.index ["supported_erc_standards"], name: "index_contract_details_on_supported_erc_standards", using: :gin
    t.index ["token_symbol"], name: "index_contract_details_on_token_symbol"
  end

  add_foreign_key "address_transactions", "addresses"
  add_foreign_key "contract_details", "addresses"
end
