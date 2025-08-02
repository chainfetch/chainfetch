# db/migrate/20250802120157_create_addresses.rb
class CreateAddresses < ActiveRecord::Migration[8.0]
  def change
    create_table :addresses do |t|
      # === Core Identity & Type ===
      # The unique, 42-character hexadecimal string representing the Ethereum address.
      t.string :address, null: false
      # The transaction count for an Externally Owned Account (EOA), used to prevent replay attacks. Null for contracts.
      t.integer :nonce
      # A simple boolean flag to quickly differentiate between an EOA (false) and a Smart Contract (true).
      t.boolean :is_contract, null: false, default: false

      # === Account Abstraction & EIP-7702 (Pectra Upgrade) ===
      # Flags whether this address is a smart contract wallet that supports ERC-4337 for Account Abstraction.
      t.boolean :is_smart_wallet, default: false
      # For smart wallets, this is the address of the global EntryPoint contract that processes its UserOperations.
      t.string :entry_point_address
      # The address of the Paymaster contract sponsoring gas fees for this wallet's UserOperations.
      t.string :paymaster_address
      # The address of the Bundler service that submitted this wallet's recent UserOperations.
      t.string :bundler_address
      # Flags if the address has used EIP-7702 features, allowing it to act as a smart contract for a single transaction. Relevant post-Pectra upgrade (May 2025).
      t.boolean :supports_eip7702, default: false

      # === Creation & Origin ===
      # For contracts, this is the EOA or contract address that deployed this contract.
      t.string :creator_address
      # The unique hash of the transaction in which this address was created (for contracts) or first seen.
      t.string :creation_transaction_hash
      # The EVM opcode used for creation, e.g., 'CREATE' or 'CREATE2' (for predictable address deployments).
      t.string :creation_method
      # For CREATE2 deployments, this is the hash of the contract's initialization code.
      t.string :init_code_hash

      # === Balance, Staking & Historicals ===
      # The balance of the native currency (ETH), stored with high precision to handle values in Wei (10^18).
      t.decimal :eth_balance, precision: 36, scale: 18, default: 0.0
      # The amount of ETH this address has staked on the Beacon Chain (if a validator).
      t.decimal :staked_eth_balance, precision: 36, scale: 18, default: 0.0
      # A cached USD value of the liquid ETH balance, updated periodically via an external price oracle.
      t.decimal :total_eth_value_usd, precision: 20, scale: 4
      # A JSONB field storing snapshots of ETH balances at key historical blocks (e.g., The Merge).
      t.jsonb :historical_balances, default: {}
      # A JSONB field extending historical snapshots to token balances.
      t.jsonb :historical_token_balances, default: {}
      # The block number at which the liquid ETH balance was last fetched, crucial for data freshness checks.
      t.bigint :eth_balance_updated_at_block
      # The block number at which the staked ETH balance was last fetched.
      t.bigint :staked_balance_updated_at_block

      # === Fund Flow & Validator Analytics ===
      # The cumulative amount of ETH this address has spent on transaction fees (gas), calculated from its transactions.
      t.decimal :total_eth_spent_on_fees, precision: 36, scale: 18, default: 0.0
      # The cumulative amount of ETH this address has received from external transactions.
      t.decimal :total_eth_received, precision: 36, scale: 18, default: 0.0
      # The cumulative amount of ETH this address has sent to external addresses.
      t.decimal :total_eth_sent, precision: 36, scale: 18, default: 0.0
      # The total number of blocks this address has successfully mined (pre-Merge) or validated (post-Merge).
      t.bigint :mined_blocks_count, default: 0
      # The total count of deposits made from this address to the Beacon Chain.
      t.bigint :beacon_deposits_count, default: 0
      # The total count of Beacon Chain withdrawals made to this address.
      t.bigint :beacon_withdrawals_count, default: 0
      # The unique index of this address on the Beacon Chain consensus layer, if it is a validator.
      t.bigint :validator_index
      # The current status of the validator (e.g., 'active', 'exited', 'slashed').
      t.string :validator_status

      # === Holdings (Fungible, NFT, & Specialized) ===
      # A flexible JSONB field to store balances of all fungible tokens (e.g., ERC-20, ERC-777).
      t.jsonb :fungible_token_holdings, default: {}
      # A JSONB field to store ownership details of all non-fungible tokens (e.g., ERC-721, ERC-1155).
      t.jsonb :non_fungible_token_holdings, default: {}
      # A JSONB field for holdings of more niche or complex standards (e.g., ERC-4626 Vaults, ERC-1400 Securities).
      t.jsonb :specialized_token_data, default: {}

      # === Transaction & Activity Analytics ===
      # The total count of standard outgoing transactions initiated by this address.
      t.bigint :transaction_count, default: 0
      # For smart wallets, the total count of ERC-4337 UserOperations this address has initiated.
      t.bigint :user_operations_count, default: 0
      # The total count of transactions sent from this address that failed (reverted).
      t.bigint :failed_transaction_count, default: 0
      # The total count of internal transactions (ETH transfers initiated by other contracts) involving this address.
      t.bigint :internal_transaction_count, default: 0
      # The total count of all token transfers (ERC-20, 721, 1155) where this address was the sender or receiver.
      t.bigint :token_transfers_count, default: 0
      # A more granular count of only ERC-20 token transfers.
      t.bigint :erc20_transaction_count, default: 0
      # A more granular count of only ERC-721 (NFT) token transfers.
      t.bigint :erc721_transaction_count, default: 0
      # A more granular count of only ERC-1155 token transfers.
      t.bigint :erc1155_transaction_count, default: 0
      # The timestamp of the very first transaction involving this address.
      t.datetime :first_transaction_at
      # The timestamp of the most recent transaction involving this address.
      t.datetime :last_transaction_at
      # The block number of the first transaction involving this address.
      t.bigint :first_seen_block_number
      # The block number of the most recent transaction involving this address.
      t.bigint :last_seen_block_number
      # The cumulative amount of gas units consumed by all transactions sent from this address.
      t.bigint :total_gas_used, default: 0

      # === Cross-Chain & Interoperability ===
      # A JSONB field to store cached balances of this address on other blockchains (e.g., Polygon, Arbitrum).
      t.jsonb :multichain_balances, default: {}
      # The count of transactions where this address sent funds to a known bridge contract.
      t.bigint :bridge_deposits_count, default: 0
      # The count of transactions where this address received funds from a known bridge contract.
      t.bigint :bridge_withdrawals_count, default: 0

      # === ENS & Off-Chain Identity ===
      # The primary, human-readable Ethereum Name Service (ENS) name pointing to this address (e.g., "vitalik.eth").
      t.string :ens_name
      # The URL of the avatar image associated with the ENS name.
      t.string :ens_avatar_url
      # A JSONB field to store all other text records from ENS (e.g., twitter, github, url).
      t.jsonb :ens_records, default: {}
      # An array for public tags (e.g., "Uniswap Router", "Known Scammer") or internal application labels.
      t.string :labels, array: true, default: []

      # === Risk & Compliance ===
      # A computed score (e.g., 0-100) from a chain analysis provider indicating risk level.
      t.integer :risk_score
      # An array listing the authorities (e.g., 'OFAC') that have sanctioned this address, providing granular compliance data.
      t.string :sanctioned_by, array: true, default: []
      # A flag indicating if the address is a known scam address.
      t.boolean :is_scam, default: false
      # Flags indicating the presence of specific transaction types.
      t.boolean :has_beacon_chain_withdrawals
      t.boolean :has_logs
      t.boolean :has_token_transfers
      t.boolean :has_tokens
      # A JSONB field for private tags from Blockscout.
      t.jsonb :private_tags, default: {}
      # The ETH price at the time of the request.
      t.decimal :exchange_rate, precision: 20, scale: 4
      # Watchlist details from Blockscout
      t.string :watchlist_address_id
      t.string :watchlist_names, array: true, default: []

      # === System: Syncing, Metadata & Future-Proofing ===
      # The current data indexing status for this address (e.g., 'pending', 'synced', 'failed').
      t.string :sync_status, default: 'pending'
      # If the last sync failed, this field stores the error message for debugging.
      t.string :error_last_sync
      # The timestamp of the last successful or failed attempt to sync this address's data.
      t.datetime :last_synced_at
      # The timestamp when this address was last observed to be active on the network.
      t.datetime :last_seen_at
      # The block number at which any field in this record was last updated.
      t.bigint :updated_at_block
      # A forward-looking flag for compatibility with the Fusaka upgrade (late 2025), to be used once its features are live.
      t.boolean :fusaka_compatible, default: false
      # A flexible JSONB field for any other application-specific or miscellaneous data.
      t.jsonb :metadata, default: {}

      # Standard Rails timestamps for record creation and updates.
      t.timestamps
    end

    # === Indexes for High-Performance Queries ===
    add_index :addresses, :address, unique: true
    add_index :addresses, :is_contract
    add_index :addresses, :is_smart_wallet
    add_index :addresses, :supports_eip7702
    add_index :addresses, :nonce
    add_index :addresses, :creator_address
    add_index :addresses, :paymaster_address
    add_index :addresses, :mined_blocks_count
    add_index :addresses, :validator_index
    add_index :addresses, :ens_name, unique: true, where: "ens_name IS NOT NULL"
    add_index :addresses, :labels, using: 'gin'
    add_index :addresses, :ens_records, using: 'gin'
    add_index :addresses, :first_seen_block_number
    add_index :addresses, :last_seen_block_number
    add_index :addresses, :token_transfers_count
    add_index :addresses, :risk_score
    add_index :addresses, :is_scam
  end
end