# db/migrate/YYYYMMDDHHMMSS_create_contract_details.rb
class CreateContractDetails < ActiveRecord::Migration[8.0]
  def change
    create_table :contract_details do |t|
      # === Foreign Key to the Address ===
      # A direct, one-to-one link to the corresponding record in the `addresses` table.
      t.references :address, null: false, foreign_key: true, index: { unique: true }

      # === Core Contract & Token Info ===
      # The user-friendly name of the contract, often from its source code (e.g., "UniswapV3Router").
      t.string :name
      # If the contract is a token, this is its full name (e.g., "Wrapped Ether").
      t.string :token_name
      # If the contract is a token, this is its ticker symbol (e.g., "WETH").
      t.string :token_symbol
      # For ERC-20 tokens, the number of decimal places for its value.
      t.integer :token_decimals
      # For token contracts, the total circulating supply.
      t.decimal :token_total_supply, precision: 36, scale: 18
      # A flag indicating if the contract has called the SELFDESTRUCT opcode, rendering it inactive.
      t.boolean :is_self_destructed, default: false

      # === ABI and Bytecode ===
      # The Application Binary Interface (ABI) as JSON, which defines how to interact with the contract's functions.
      t.jsonb :abi, default: {}
      # The compiled EVM bytecode that is currently stored and executed on the blockchain.
      t.text :bytecode
      # The full bytecode used for deployment, which includes the constructor logic that is not stored on-chain.
      t.text :creation_bytecode
      # The size of the contract's runtime bytecode in bytes. Relevant for EIP-7825 checks post-Fusaka upgrade.
      t.integer :code_size
      # An MD5 hash of the runtime bytecode for quick comparisons and change detection.
      t.string :contract_code_md5

      # === Creation & Deployment ===
      # The block number in which this contract was created.
      t.bigint :creation_block_number
      # For contracts deployed by a factory, this is the hash of the factory's bytecode, used to identify similar contracts.
      t.string :deployer_bytecode_hash

      # === Verification & Source Code ===
      # A boolean flag indicating if the contract's source code has been successfully verified against its on-chain bytecode.
      t.boolean :is_verified, default: false
      # A flag for when verification is successful but with minor discrepancies (e.g., different metadata hash).
      t.boolean :is_partially_verified, default: false
      # A flag indicating verification was done via the decentralized Sourcify repository.
      t.boolean :is_verified_via_sourcify, default: false
      # A flag indicating verification was done via the public Ethereum Bytecode Database.
      t.boolean :is_verified_via_eth_bytecode_db, default: false
      # A flag indicating if constructor arguments were auto-detected, adding nuance to the verification status.
      t.boolean :autodetect_constructor_args, default: false
      # The timestamp when the contract was successfully verified.
      t.datetime :verified_at
      # The number of verification attempts (successful or failed) for this contract, useful for auditing.
      t.integer :verification_attempts, default: 0
      # The verified Solidity or Vyper source code.
      t.text :source_code
      # A single-file, "flattened" version of the source code, often required by verification tools.
      t.text :flattened_source_code
      # For multi-file projects, a JSONB field storing the content of all primary source files.
      t.jsonb :source_code_files, default: {}
      # JSONB field for additional verified source files (e.g., imported contracts) for complex verifications.
      t.jsonb :secondary_sources, default: {}
      # The path to the main source file within a multi-file project.
      t.string :file_path
      # The main file targeted during compilation (for precise rebuilds).
      t.string :compilation_target_file_name
      # The software license of the source code (e.g., 'MIT', 'GPL-3.0').
      t.string :license_type
      # A JSONB field for storing any extra metadata returned by the verification service.
      t.jsonb :verification_metadata, default: {}

      # === Compiler & EVM Details ===
      # The exact version of the compiler (e.g., "v0.8.20+commit.a1b79de6") used to compile the contract.
      t.string :compiler_version
      # A flag to indicate if the contract was written in Vyper instead of Solidity.
      t.boolean :is_vyper_contract, default: false
      # A flag to indicate if the contract uses Yul (low-level intermediate language) for optimization.
      t.boolean :is_yul_contract, default: false
      # A boolean indicating if compiler optimization was enabled during compilation.
      t.boolean :is_optimization_enabled
      # If optimization was enabled, this specifies the number of optimization runs.
      t.integer :optimization_runs
      # The target Ethereum Virtual Machine (EVM) version (e.g., "paris", "london").
      t.string :evm_version
      # An array of supported precompiles, preparing for network upgrades like Fusaka (EIP-2537 BLS precompile).
      t.string :precompiles_supported, array: true, default: []
      # The ABI-encoded arguments that were passed to the constructor during deployment.
      t.text :constructor_arguments
      # A JSONB field listing the names and addresses of any external libraries the contract was linked against.
      t.jsonb :external_libraries, default: {}
      # The full JSON object of compiler settings used.
      t.jsonb :compiler_settings, default: {}

      # === Proxy and Upgradability ===
      # A flag indicating if this contract is a proxy that delegates calls to another contract.
      t.boolean :is_proxy, default: false
      # A flag for gas-efficient EIP-1167 minimal proxy clones.
      t.boolean :is_minimal_proxy, default: false
      # The specific proxy pattern used (e.g., 'EIP-1967', 'UUPS', 'Diamond').
      t.string :proxy_type
      # The address of the implementation (logic) contract that this proxy delegates calls to.
      t.string :implementation_address
      # The cached name of the implementation contract for faster lookups.
      t.string :implementation_name
      # The specific storage slot where the implementation address is stored, per EIP-1967.
      t.string :implementation_slot
      # For upgradable proxies, this is the address that has permission to change the implementation address.
      t.string :admin_address
      # For beacon proxies, this is the address of the beacon contract which holds the implementation address.
      t.string :beacon_address
      # The number of times the implementation address for this proxy has been changed.
      t.integer :upgrade_count, default: 0
      # The timestamp when the implementation address was last fetched and confirmed.
      t.datetime :implementation_fetched_at

      # === Contract Standards and Behavior (2025-Era Included) ===
      # An array of all ERC standards this contract is known to support (e.g., ['ERC20', 'ERC721', 'ERC2981']).
      t.string :supported_erc_standards, array: true, default: []
      t.boolean :is_erc20, default: false # Standard fungible token.
      t.boolean :is_erc223, default: false # Safer fungible token with `tokenFallback`.
      t.boolean :is_erc721, default: false # Standard non-fungible token (NFT).
      t.boolean :is_erc777, default: false # Advanced fungible token with hooks.
      t.boolean :is_erc1155, default: false # Multi-token standard (fungible & NFT).
      t.boolean :is_erc2981, default: false # On-chain royalty standard for NFTs.
      t.boolean :is_erc3643, default: false # Permissioned, compliance-focused security token.
      t.boolean :is_erc404, default: false # Hybrid fungible/NFT token.
      t.boolean :is_erc6551, default: false # Token-bound accounts (NFTs as wallets).
      t.boolean :is_erc6900, default: false # Modular smart contract accounts.
      t.boolean :is_erc7828, default: false # Multichain address consistency standard.
      t.boolean :is_erc7861, default: false # Verifiable credentials for NFTs.
      t.boolean :is_erc7878, default: false # Bequeathable/inheritable contracts.
      t.boolean :is_erc7902, default: false # Wallet capabilities discovery for AA.
      t.boolean :is_erc7920, default: false # Composite EIP-712 signatures.
      t.boolean :is_erc7930, default: false # Simplified cross-chain transactions.
      t.boolean :is_erc7943, default: false # Universal interface for Real-World Assets (RWAs).

      # === Analysis & Debugging ===
      # A flag indicating if the on-chain bytecode has changed since it was last verified.
      t.boolean :is_changed_bytecode, default: false
      # The timestamp when the on-chain bytecode was last checked for changes.
      t.datetime :bytecode_checked_at
      # A flag indicating if a decompilation has been performed and stored.
      t.boolean :is_decompiled, default: false
      # The human-readable source code generated by a decompiler tool.
      t.text :decompiled_code
      # A score from an external security audit tool (e.g., Slither, Mythril).
      t.integer :security_audit_score
      # Fields from the token object in the API response
      t.decimal :circulating_market_cap, precision: 30, scale: 4
      t.string :icon_url
      t.bigint :holders_count
      t.string :website
      t.string :token_type
      t.decimal :volume_24h, precision: 30, scale: 4
      # Fields from the smart-contracts endpoint
      t.string :verified_twin_address_hash
      t.string :sourcify_repo_url
      t.jsonb :decoded_constructor_args, default: {}
      t.boolean :is_verified_via_verifier_alliance, default: false
      t.boolean :is_blueprint, default: false
      t.boolean :is_fully_verified, default: false
      t.boolean :can_be_visualized_via_sol2uml, default: false

      # Standard Rails timestamps.
      t.timestamps
    end

    # === Indexes for High-Performance Queries ===
    add_index :contract_details, :name
    add_index :contract_details, :token_symbol
    add_index :contract_details, :is_verified
    add_index :contract_details, :is_proxy
    add_index :contract_details, :implementation_address
    add_index :contract_details, :admin_address
    add_index :contract_details, :creation_block_number
    add_index :contract_details, :abi, using: 'gin'
    add_index :contract_details, :supported_erc_standards, using: 'gin'
    add_index :contract_details, :precompiles_supported, using: 'gin'
    # Indexing all boolean flags for fast filtering by standard
    add_index :contract_details, :is_erc20
    add_index :contract_details, :is_erc223
    add_index :contract_details, :is_erc721
    add_index :contract_details, :is_erc777
    add_index :contract_details, :is_erc1155
    add_index :contract_details, :is_erc2981
    add_index :contract_details, :is_erc3643
    add_index :contract_details, :is_erc404
    add_index :contract_details, :is_erc6551
    add_index :contract_details, :is_erc6900
    add_index :contract_details, :is_erc7828
    add_index :contract_details, :is_erc7861
    add_index :contract_details, :is_erc7878
    add_index :contract_details, :is_erc7902
    add_index :contract_details, :is_erc7920
    add_index :contract_details, :is_erc7930
    add_index :contract_details, :is_erc7943
  end
end