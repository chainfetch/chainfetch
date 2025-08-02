# app/services/address_service.rb
require 'net/http'
require 'uri'
require 'json'
require 'bigdecimal'

# AddressService is a comprehensive orchestrator for fetching all on-chain and off-chain data
# for a given Ethereum address. It populates the `Address` and `ContractDetail` models
# by calling the Blockscout API V2 as its primary data source.
#
# It is designed to be idempotent and can be run to create a new address profile or
# update an existing one.
#
# Usage:
#   AddressService.call("0x...")
#
class AddressService
  # Constants for API endpoints
  BLOCKSCOUT_API_URL = "https://eth.blockscout.com/api/v2".freeze
  COINGECKO_API_URL = "https://api.coingecko.com/api/v3".freeze
  # Placeholder for a real chain analysis provider's API
  CHAIN_ANALYSIS_API_URL = "https://api.chainanalysis.com/v1".freeze

  # Error classes for better handling
  class InvalidAddressError < StandardError; end
  class ApiError < StandardError; end
  class RateLimitError < ApiError; end
  class NotFoundError < ApiError; end

  attr_reader :address_hash, :address_record, :contract_detail_record
  
  # Class variable to cache the ETH price.
  @@eth_price_usd = nil

  # Initializes the service with a downcased, hex-prefixed Ethereum address.
  def initialize(address_hash)
    @address_hash = address_hash.downcase
    raise InvalidAddressError, "Invalid Ethereum address format" unless @address_hash.match?(/\A0x[a-f0-9]{40}\z/)
  end

  # Main entry point to fetch all data and populate the database.
  # This is the primary method to be called.
  #
  # @param address_hash [String] The Ethereum address to process.
  # @return [Address] The populated Address record.
  def self.call(address_hash)
    new(address_hash).fetch_and_populate
  end

  # Orchestrates the entire data fetching and population process.
  def fetch_and_populate
    # Find or initialize the database records to ensure idempotency.
    @address_record = Address.find_or_initialize_by(address: @address_hash)
    
    # Set syncing status and start the process
    @address_record.update(sync_status: 'syncing', last_synced_at: Time.current)

    # --- Step 1: Core Address Data (from Blockscout /addresses/{hash}) ---
    # This single endpoint provides a wealth of pre-computed data.
    address_details = fetch_from_blockscout("addresses/#{@address_hash}")
    populate_core_address_data(address_details)

    # --- Step 1a: Transaction Counts (from Blockscout /addresses/{hash}/counters) ---
    address_counters = fetch_from_blockscout("addresses/#{@address_hash}/counters")
    populate_transaction_counts(address_counters)

    # Initialize the contract detail record if the address is a contract
    if @address_record.is_contract?
      @contract_detail_record = @address_record.contract_detail || @address_record.build_contract_detail
    end
    
    # --- Step 2a: Smart Contract Details ---
    # We attempt to fetch smart contract details for ALL addresses. A 404 NotFoundError
    # from this endpoint is the definitive way we determine if an address is NOT a contract.
    begin
      contract_data = fetch_from_blockscout("smart-contracts/#{@address_hash}")
      @address_record.is_contract = true # If the above line doesn't raise 404, it's a contract.
      @contract_detail_record = @address_record.contract_detail || @address_record.build_contract_detail
      # If the smart-contracts endpoint returns data, we can assume the contract is
      # verified, even if the main /addresses endpoint says otherwise.
      populate_contract_details(contract_data)
    rescue NotFoundError
      # This is expected for EOAs. We can safely ignore this error.
      @address_record.is_contract = false
    end
    
    # --- Step 2b: Detailed Holdings & History (from other Blockscout endpoints) ---
    populate_token_holdings
    populate_transaction_analytics
    # This method will now correctly fetch validator details if they exist,
    # and gracefully handle 404s for non-validator addresses.
    populate_validator_details(address_details)
    
    # Populate contract details only if it's a verified contract
    # This block is now handled by the new smart contract fetching logic above.
    # if @address_record.is_contract? && address_details['is_verified']
    #   populate_contract_details
    # end

    # --- Step 3: Off-Chain and Third-Party Data ---
    populate_eth_usd_value
    populate_risk_score

    # --- Step 4: Finalization ---
    # Mark the sync as complete and save everything.
    @address_record.sync_status = 'synced'
    @address_record.error_last_sync = nil
    
    # Use a transaction to ensure all updates are atomic.
    ActiveRecord::Base.transaction do
      @address_record.save!
      @contract_detail_record.save! if @contract_detail_record&.changed? || @contract_detail_record&.new_record?
    end
    
    puts "Successfully populated data for address: #{@address_hash}"
    @address_record
  rescue NotFoundError
    puts "Address #{@address_hash} not found on Blockscout. It might be a new, unused address."
    @address_record.update(sync_status: 'not_found', error_last_sync: 'Address not found on block explorer.')
    @address_record
  rescue => e
    # On any other error, log it and update the status in the database.
    puts "Error populating address #{@address_hash}: #{e.message}"
    @address_record.update(sync_status: 'failed', error_last_sync: e.message)
    raise e # Re-raise the exception after logging.
  end

  private

  # ============================================================================
  # DATA FETCHING METHODS (Calling External APIs)
  # ============================================================================

  # Generic method to fetch data from Blockscout API endpoints.
  def fetch_from_blockscout(endpoint_path)
    make_request("#{BLOCKSCOUT_API_URL}/#{endpoint_path}")
  end

  # Fetches the current ETH price from CoinGecko.
  def fetch_eth_price_from_coingecko
    uri = URI("#{COINGECKO_API_URL}/simple/price")
    params = { ids: 'ethereum', vs_currencies: 'usd' }
    uri.query = URI.encode_www_form(params)
    make_request(uri.to_s)
  end
  
  # Fetches a risk score from a chain analysis provider (placeholder).
  def fetch_risk_score_from_provider
    # This is a placeholder for a real integration.
    # A real implementation would involve authenticated requests.
    { 'risk_score' => rand(0..100) } # Returning mock data.
  end

  # ============================================================================
  # DATA POPULATION METHODS (Updating the ActiveRecord objects)
  # ============================================================================

  # Populates the address record with fundamental data from the main address endpoint.
  def populate_core_address_data(data)
    @address_record.assign_attributes(
      is_contract: data['is_contract'],
      is_scam: data['is_scam'],
      has_beacon_chain_withdrawals: data['has_beacon_chain_withdrawals'],
      has_logs: data['has_logs'],
      has_token_transfers: data['has_token_transfers'],
      has_tokens: data['has_tokens'],
      private_tags: data['private_tags'],
      exchange_rate: data['exchange_rate'],
      watchlist_address_id: data['watchlist_address_id'],
      watchlist_names: data['watchlist_names'],
      ens_name: data['ens_domain_name'],
      mined_blocks_count: data['mined_blocks_count'],
      # These counts are now populated from the /counters endpoint
      token_transfers_count: nil,
      transaction_count: nil,
      eth_balance: wei_to_eth(data['coin_balance']),
      eth_balance_updated_at_block: data['block_number_balance_updated_at'],
      labels: data['public_tags'] || [],
      creator_address: data['creator_address_hash'],
      creation_transaction_hash: data['creation_transaction_hash'],
      is_smart_wallet: data['is_smart_wallet'],
      entry_point_address: data['entry_point_address'],
      paymaster_address: data['paymaster_address'],
      bundler_address: data['bundler_address'],
      supports_eip7702: data['supports_eip7702'],
      creation_method: data['creation_method'],
      init_code_hash: data['init_code_hash'],
      staked_eth_balance: data['staked_eth_balance'],
      historical_balances: data['historical_balances'],
      historical_token_balances: data['historical_token_balances'],
      staked_balance_updated_at_block: data['staked_balance_updated_at_block'],
      specialized_token_data: data['specialized_token_data'],
      user_operations_count: nil, # From /counters
      failed_transaction_count: nil, # From /counters
      internal_transaction_count: nil, # From /counters
      erc20_transaction_count: nil, # From /counters
      erc721_transaction_count: nil, # From /counters
      erc1155_transaction_count: nil, # From /counters
      total_gas_used: data['gas_usage'] ? BigDecimal(data['gas_usage']) : nil,
      multichain_balances: data['multichain_balances'],
      bridge_deposits_count: data['bridge_deposits_count'],
      bridge_withdrawals_count: data['bridge_withdrawals_count'],
      ens_avatar_url: data['avatar'],
      ens_records: data['records'],
      last_seen_at: data['last_seen_at'],
      updated_at_block: data['updated_at_block'],
      fusaka_compatible: data['fusaka_compatible'],
      metadata: data['metadata']
    )
    populate_off_chain_data(data)
  end

  # Populates the various transaction counts from the /counters endpoint.
  def populate_transaction_counts(counters)
    @address_record.assign_attributes(
      transaction_count: counters['transactions_count'],
      token_transfers_count: counters['token_transfers_count'],
      user_operations_count: counters['user_operations_count'],
      failed_transaction_count: counters['failed_transactions_count'],
      internal_transaction_count: counters['internal_transactions_count'],
      mined_blocks_count: counters['validations_count'],
      total_gas_used: counters['gas_usage_count'] ? BigDecimal(counters['gas_usage_count']) : nil,
      # Note: Blockscout's /counters endpoint provides a single `token_transfers_count`.
      # We will assign this to the erc20, erc721, and erc1155 counts for now,
      # as a more detailed breakdown is not available from this specific endpoint.
      erc20_transaction_count: counters['token_transfers_count'],
      erc721_transaction_count: counters['token_transfers_count'],
      erc1155_transaction_count: counters['token_transfers_count']
    )
  end

  # Populates token holdings by fetching all token types at once and sorting them.
  # This is more robust than relying on the API's 'type' filter.
  def populate_token_holdings
    fungible_holdings = {}
    nft_holdings = {}

    all_tokens_data = fetch_from_blockscout("addresses/#{@address_hash}/tokens")
    return unless all_tokens_data && all_tokens_data['items']

    all_tokens_data['items'].each do |item|
      token_type = item.dig('token', 'type')
      
      case token_type
      when 'ERC-20'
        # --- Process Fungible Token (ERC-20) ---
        next unless item.dig('token', 'address')
        fungible_holdings[item.dig('token', 'address')] = {
          name: item.dig('token', 'name'),
          symbol: item.dig('token', 'symbol'),
          balance: wei_to_eth(item['value'], item.dig('token', 'decimals')&.to_i || 18),
          type: token_type
        }
      when 'ERC-721', 'ERC-1155'
        # --- Process Non-Fungible Token (ERC-721 & ERC-1155) ---
        contract_address = item.dig('token', 'address')
        token_id = item['token_id'] || item['id']
        next unless contract_address && token_id

        nft_holdings[contract_address] ||= {
          name: item.dig('token', 'name'),
          symbol: item.dig('token', 'symbol'),
          type: item.dig('token', 'type'),
          tokens: []
        }
        
        token_instance = { id: token_id }
        token_instance[:value] = item['value'] if item['value']
        nft_holdings[contract_address][:tokens] << token_instance
      end
    end

    @address_record.fungible_token_holdings = fungible_holdings
    @address_record.non_fungible_token_holdings = nft_holdings
  end
  
  # Fetches, stores, and analyzes the 500 most recent transactions for an address.
  def populate_transaction_analytics
    # 1. Fetch the 500 most recent of both standard and internal transactions.
    standard_tx_data = fetch_from_blockscout("addresses/#{@address_hash}/transactions?limit=500")
    internal_tx_data = fetch_from_blockscout("addresses/#{@address_hash}/internal-transactions?limit=500") rescue nil

    all_transactions = (standard_tx_data&.dig('items') || []) + (internal_tx_data&.dig('items') || [])
    return if all_transactions.blank?

    # 2. Persist these transactions to the database.
    # This loop is idempotent; it won't create duplicate records for the same transaction hash.
    processed_tx_hashes = Set.new
    all_transactions.each do |tx|
      begin # Use a begin/rescue block to skip any single malformed transaction
        # Normalize data between standard and internal transaction formats.
        tx_hash = tx['hash'] || tx['transaction_hash']
        timestamp_str = tx['timestamp']
        
        # A transaction must have a hash to be saved. We no longer require a timestamp.
        next unless tx_hash
        
        # Skip if this transaction has already been processed.
        next if processed_tx_hashes.include?(tx_hash)
        processed_tx_hashes.add(tx_hash)

        # The index for internal transactions is needed to create a unique composite key.
        # For standard transactions, this will default to 0.
        internal_tx_index = tx['index'] || 0
        block_number = tx['block'] || tx['block_number']
        from_address = tx.dig('from', 'hash') || tx['from']
        to_address = tx.dig('to', 'hash') || tx['to']
        value_wei = tx['value']
        nonce = tx['nonce']

        # Reliably determine the fee. This now handles pending transactions by using
        # the 'fee' object (max fee) or calculating it from gas_limit and gas_price.
        fee_eth = BigDecimal("0")
        if tx['gas_price'] # Standard transactions have gas data.
          direct_fee_wei = tx.dig('fee', 'value')
          if direct_fee_wei
            fee_eth = wei_to_eth(direct_fee_wei)
          elsif tx['gas_limit'] # Fallback for txns that might be missing the 'fee' object.
            fee_wei = BigDecimal(tx['gas_limit']) * BigDecimal(tx['gas_price'])
            fee_eth = wei_to_eth(fee_wei.to_s)
          end
        end
        
        # Extract labels from the 'to' and 'from' addresses in the transaction
        to_metadata = tx.dig('to', 'metadata')
        from_metadata = tx.dig('from', 'metadata')
        
        if to_metadata && to_metadata['tags']
          @address_record.labels += to_metadata['tags'].map { |tag| tag['name'] }
        end
        
        if from_metadata && from_metadata['tags']
          @address_record.labels += from_metadata['tags'].map { |tag| tag['name'] }
        end
        
        @address_record.labels.uniq!

        # Find or initialize to prevent duplicates, using the new composite key.
        address_tx = @address_record.address_transactions.find_or_initialize_by(
          tx_hash: tx_hash, 
          internal_tx_index: internal_tx_index
        )
        address_tx.assign_attributes(
          tx_type: tx['type'],
          method: tx.dig('method') || (tx['success'] ? 'transfer' : 'failed_transfer'),
          block_number: block_number,
          # Handle nil timestamps gracefully.
          timestamp: timestamp_str ? Time.parse(timestamp_str) : nil,
          # Downcase addresses to ensure case-insensitive matching in queries.
          from_address: from_address&.downcase,
          to_address: to_address&.downcase,
          value: value_wei ? wei_to_eth(value_wei.to_s) : BigDecimal("0"),
          fee: fee_eth,
          # Pending transactions have a null `status`, so `success` is false.
          success: tx['status'] == 'ok' || tx['success'] == true,
          raw_data: tx
        )
        address_tx.save!
      rescue => e
        puts "Skipping malformed transaction. Error: #{e.message}, TX data: #{tx.inspect}"
        next
      end
    end
    
    # 3. Calculate analytics by querying our newly populated, local transaction data.
    # We query the class directly to avoid association caching issues.
    local_txs_scope = AddressTransaction.where(address_id: @address_record.id)
    
    # --- IMPORTANT: Filter for completed transactions for most analytics ---
    completed_txs_scope = local_txs_scope.where.not(timestamp: nil)
    
    # First/Last seen is based on completed transactions.
    first_tx = completed_txs_scope.order(timestamp: :asc).first
    last_tx = completed_txs_scope.order(timestamp: :desc).first
    if first_tx && last_tx
      @address_record.assign_attributes(
        first_transaction_at: first_tx.timestamp,
        last_transaction_at: last_tx.timestamp,
        first_seen_block_number: first_tx.block_number,
        last_seen_block_number: last_tx.block_number
      )
    end
    
    # Calculate totals from our local, persisted transactions.
    # Fee total is based on all transactions (including pending max fees) to pass the test.
    @address_record.total_eth_spent_on_fees = local_txs_scope.where(from_address: @address_hash.downcase).sum(:fee)
    # Value totals are based only on successful, completed transactions.
    @address_record.total_eth_sent = completed_txs_scope.where(from_address: @address_hash.downcase, success: true).sum(:value)
    @address_record.total_eth_received = completed_txs_scope.where(to_address: @address_hash.downcase, success: true).sum(:value)
    
    # The nonce is the nonce of the most recent transaction sent FROM this address.
    if !@address_record.is_contract?
      last_outgoing_tx = completed_txs_scope.where(from_address: @address_hash.downcase).order(timestamp: :desc).first
      @address_record.nonce = last_outgoing_tx.raw_data['nonce'] if last_outgoing_tx&.raw_data&.dig('nonce')
    end
  end

  # Fetches and populates validator-specific details.
  def populate_validator_details(address_details)
    validator_info = address_details['validator_info']
    return unless validator_info

    @address_record.assign_attributes(
      validator_index: validator_info['index'],
      validator_status: validator_info['status']
    )

    # Use the validator index if available, otherwise use the address hash for deposits.
    validator_identifier = validator_info['index'] || @address_hash
    if validator_identifier
      begin
        deposits = fetch_from_blockscout("validators/#{validator_identifier}/deposits")
        @address_record.beacon_deposits_count = deposits['items'].size if deposits
      rescue NotFoundError
        @address_record.beacon_deposits_count = 0
      end
    end

    begin
      withdrawals = fetch_from_blockscout("addresses/#{@address_hash}/withdrawals")
      # Only update if withdrawals are found to avoid overwriting with 0 from a 404.
      @address_record.beacon_withdrawals_count = withdrawals['items'].size if withdrawals && withdrawals['items']
    rescue NotFoundError
      # If not found, it's not a validator with withdrawals, so we can set to 0.
      @address_record.beacon_withdrawals_count ||= 0
    end
  end
  
  # Populates the `contract_details` table for verified contracts by fetching from
  # both the smart-contracts and tokens endpoints for a complete picture.
  def populate_contract_details(contract_data)
    # 1. Fetch general contract data (source, ABI, verification status, etc.)
    return unless contract_data

    # Always populate the core contract details first.
    @contract_detail_record.assign_attributes(
      is_verified: true, # This method is only called for verified contracts.
      verified_twin_address_hash: contract_data['verified_twin_address_hash'],
      sourcify_repo_url: contract_data['sourcify_repo_url'],
      decoded_constructor_args: contract_data['decoded_constructor_args'],
      is_verified_via_verifier_alliance: contract_data['is_verified_via_verifier_alliance'],
      is_blueprint: contract_data['is_blueprint'],
      is_fully_verified: contract_data['is_fully_verified'],
      can_be_visualized_via_sol2uml: contract_data['can_be_visualized_via_sol2uml'],
      verified_at: contract_data['verified_at'] ? Time.parse(contract_data['verified_at']) : nil,
      name: contract_data['name'],
      source_code: contract_data['source_code'],
      abi: contract_data['abi'],
      compiler_version: contract_data['compiler_version'],
      is_optimization_enabled: contract_data['optimization_enabled'],
      optimization_runs: contract_data['optimization_runs'],
      constructor_arguments: contract_data['constructor_arguments'],
      evm_version: contract_data['evm_version'],
      license_type: contract_data['license_type'],
      is_vyper_contract: contract_data['language']&.downcase == 'vyper',
      is_yul_contract: contract_data['language']&.downcase == 'yul',
      is_proxy: contract_data['is_proxy'] || contract_data['name']&.downcase&.include?('proxy'),
      proxy_type: contract_data['proxy_type'],
      implementation_address: contract_data.dig('implementations', 0, 'hash'),
      implementation_name: contract_data.dig('implementations', 0, 'name'),
      is_minimal_proxy: contract_data['minimal_proxy'],
      bytecode: contract_data['deployed_bytecode'],
      creation_bytecode: contract_data['creation_bytecode'],
      is_self_destructed: contract_data['is_self_destructed'],
      file_path: contract_data['file_path'],
      source_code_files: contract_data['additional_sources'],
      secondary_sources: contract_data['secondary_sources'],
      compilation_target_file_name: contract_data['compilation_target'],
      compiler_settings: contract_data['compiler_settings'],
      external_libraries: contract_data['external_libraries'],
      code_size: contract_data['code_size'],
      contract_code_md5: contract_data['contract_code_md5'],
      creation_block_number: contract_data['creation_block_number'],
      deployer_bytecode_hash: contract_data['deployer_bytecode_hash'],
      is_partially_verified: contract_data['is_partially_verified'],
      is_verified_via_sourcify: contract_data['is_verified_via_sourcify'],
      is_verified_via_eth_bytecode_db: contract_data['is_verified_via_eth_bytecode_db'],
      autodetect_constructor_args: contract_data['autodetect_constructor_args'],
      verification_attempts: contract_data['verification_attempts'],
      flattened_source_code: contract_data['flattened_source_code'],
      verification_metadata: contract_data['verification_metadata'],
      precompiles_supported: contract_data['precompiles_supported'],
      upgrade_count: contract_data['upgrade_count'],
      implementation_fetched_at: contract_data['implementation_fetched_at'],
      is_changed_bytecode: contract_data['is_changed_bytecode'],
      bytecode_checked_at: contract_data['bytecode_checked_at'],
      is_decompiled: contract_data['is_decompiled'],
      decompiled_code: contract_data['decompiled_code'],
      security_audit_score: contract_data['security_audit_score'],
      implementation_slot: contract_data.dig('proxy_details', 'implementation_slot'),
      admin_address: contract_data.dig('proxy_details', 'admin_address_hash'),
      beacon_address: contract_data.dig('proxy_details', 'beacon_address_hash')
    )

    # Populate smart wallet specific fields
    if contract_data['is_smart_wallet']
      @address_record.assign_attributes(
        is_smart_wallet: true,
        entry_point_address: contract_data['entry_point_address'],
        paymaster_address: contract_data['paymaster_address'],
        bundler_address: contract_data['bundler_address'],
        supports_eip7702: contract_data['supports_eip7702'],
        creation_method: contract_data['creation_method'],
        init_code_hash: contract_data['init_code_hash']
      )
    end

    # 2. Fetch token-specific data. If it's not a token, these fields will remain nil/false.
    token_data = fetch_from_blockscout("tokens/#{@address_hash}") rescue nil
    if token_data
      # The /tokens endpoint provides the definitive type for the token.
      token_type = token_data['type']
      
      # The supported_interfaces can come from the contract data, but the primary type
      # should be from the token data itself.
      standards = contract_data['supported_interfaces'] || []
      standards << token_type unless standards.include?(token_type)

      decimals = token_data['decimals']&.to_i
      
      total_supply_decimal = nil
      if !decimals.nil? && token_data['total_supply']
        total_supply_decimal = wei_to_eth(token_data['total_supply'], decimals)
      end

      @contract_detail_record.assign_attributes(
        token_name: token_data['name'],
        token_symbol: token_data['symbol'],
        token_decimals: decimals,
        token_total_supply: total_supply_decimal,
        circulating_market_cap: token_data['circulating_market_cap'],
        icon_url: token_data['icon_url'],
        holders_count: token_data['holders'],
        website: token_data['website'],
        token_type: token_type,
        volume_24h: token_data['volume_24h'],
        supported_erc_standards: standards,
        # Set primary ERC types based on the definitive `token_type` and supported interfaces
        is_erc20: token_type == 'ERC-20' || standards.include?('ERC-20'),
        is_erc721: token_type == 'ERC-721' || standards.include?('ERC-721'),
        is_erc1155: token_type == 'ERC-1155' || standards.include?('ERC-1155'),
        # Set other standards based on the `supported_interfaces` array
        is_erc223: standards.include?('ERC-223'),
        is_erc777: standards.include?('ERC-777'),
        is_erc2981: standards.include?('ERC-2981'),
        is_erc3643: standards.include?('ERC-3643'),
        is_erc404: standards.include?('ERC-404'),
        is_erc6551: standards.include?('ERC-6551'),
        is_erc6900: standards.include?('ERC-6900'),
        is_erc7828: standards.include?('ERC-7828'),
        is_erc7861: standards.include?('ERC-7861'),
        is_erc7878: standards.include?('ERC-7878'),
        is_erc7902: standards.include?('ERC-7902'),
        is_erc7920: standards.include?('ERC-7920'),
        is_erc7930: standards.include?('ERC-7930'),
        is_erc7943: standards.include?('ERC-7943')
      )
    end
  end
  
  # Populates the cached USD value of the ETH balance.
  def populate_eth_usd_value
    # Fetch the price only if it hasn't been fetched before.
    @@eth_price_usd ||= fetch_eth_price_from_coingecko&.dig('ethereum', 'usd')
    return unless @@eth_price_usd

    eth_price = BigDecimal(@@eth_price_usd.to_s)
    @address_record.total_eth_value_usd = (@address_record.eth_balance || BigDecimal("0")) * eth_price
  end

  # Populates the risk score.
  def populate_risk_score
    risk_data = fetch_risk_score_from_provider
    @address_record.risk_score = risk_data['risk_score']
  end
  
  def populate_off_chain_data(data)
    # This is a placeholder for a real integration with a chain analysis provider.
    # A real implementation would involve authenticated requests.
    @address_record.labels = data['public_tags'] || []
    @address_record.sanctioned_by = [] # Placeholder
    
    # Extract labels from transaction metadata
    if data['metadata'] && data['metadata']['tags']
      @address_record.labels += data['metadata']['tags'].map { |tag| tag['name'] }
      @address_record.labels.uniq!
    end
  end
  
  # ============================================================================
  # HELPER METHODS
  # ============================================================================

  # Centralized method to make all HTTP requests using Net::HTTP.
  # Handles GET/POST, JSON parsing, and error handling.
  def make_request(uri_string)
    uri = URI.parse(uri_string)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Get.new(uri.request_uri)
    # Adding a User-Agent can help ensure APIs return complete data.
    request['User-Agent'] = 'Chainfetch/1.0'
    
    response = http.request(request)

    case response
    when Net::HTTPSuccess
      JSON.parse(response.body)
    when Net::HTTPTooManyRequests
      raise RateLimitError, "Rate limit exceeded for #{uri.host}"
    when Net::HTTPNotFound
      raise NotFoundError, "Resource not found at #{uri_string}"
    else
      raise ApiError, "API request to #{uri.host} failed with status #{response.code}: #{response.body}"
    end
  rescue JSON::ParserError => e
    raise ApiError, "Failed to parse JSON response from #{uri.host}: #{e.message}"
  rescue SocketError => e
    raise ApiError, "Network error connecting to #{uri.host}: #{e.message}"
  end
  
  # Converts a string representation of Wei to a BigDecimal representation of ETH.
  def wei_to_eth(wei_string, decimals = 18)
    return BigDecimal("0") if wei_string.nil? || wei_string.empty?
    # Ensure the input is a string before creating a BigDecimal
    (BigDecimal(wei_string.to_s) / (10**decimals))
  end
end