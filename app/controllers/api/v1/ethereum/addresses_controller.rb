class Api::V1::Ethereum::AddressesController < Api::V1::Ethereum::BaseController
  # @summary Get address info
  # @parameter address(path) [!String] The address hash to get info for
  # @response success(200) [Hash{info: Hash, counters: Hash, transactions: Hash, token_transfers: Hash, internal_transactions: Hash, logs: Hash, blocks_validated: Hash, token_balances: Hash, tokens: Hash, coin_balance_history: Hash, coin_balance_history_by_day: Hash, withdrawals: Hash, nft: Hash, nft_collections: Hash}]
  def show
    address = params[:address]
    
    Sync do
      tasks = {
        info: Async { get_address_info(address) },
        counters: Async { get_address_counters(address) },
        transactions: Async { get_address_transactions(address) },
        token_transfers: Async { get_address_token_transfers(address) },
        internal_transactions: Async { get_address_internal_transactions(address) },
        logs: Async { get_address_logs(address) },
        blocks_validated: Async { get_address_blocks_validated(address) },
        token_balances: Async { get_address_token_balances(address) },
        tokens: Async { get_address_tokens(address) },
        coin_balance_history: Async { get_address_coin_balance_history(address) },
        coin_balance_history_by_day: Async { get_address_coin_balance_history_by_day(address) },
        withdrawals: Async { get_address_withdrawals(address) },
        nft: Async { get_address_nft(address) },
        nft_collections: Async { get_address_nft_collections(address) }
      }
      
      render json: tasks.transform_values(&:wait)
    end
  end

  # @summary Search for addresses
  # @parameter query(query) [!String] The query to search for
  # @response success(200) [Hash{results: String}]
  def search
    query = params[:query]
    response = AddressDataSearchService.new(query).call
    render json: response
  end

  # @summary Semantic Search for addresses
  # @parameter query(query) [!String] The query to search for
  # @parameter limit(query) [!Integer] The number of results to return (default: 10)
  # @response success(200) [Hash{result: Hash{points: Array<Hash{id: Integer, version: Integer, score: Float, payload: Hash{address_summary: String}}}>}}]
  
  def semantic_search
    query = params[:query]
    limit = params[:limit] || 10
    embedding = EmbeddingService.new(query).call
    qdrant_objects = QdrantService.new.query_points(collection: "addresses", query: embedding, limit: limit)
    render json: qdrant_objects
  end

  # @summary JSON Search for addresses
  # @parameter eth_balance_min(query) [String] Minimum ETH balance (in ETH, e.g., "1.5")
  # @parameter eth_balance_max(query) [String] Maximum ETH balance (in ETH, e.g., "10.0")
  # @parameter has_logs(query) [Boolean] Whether the address has logs
  # @parameter is_contract(query) [Boolean] Whether the address is a contract
  # @parameter coin_balance_min(query) [String] Minimum coin balance in WEI (e.g., "1500000000000000000")
  # @parameter coin_balance_max(query) [String] Maximum coin balance in WEI (e.g., "10000000000000000000")
  # @parameter has_beacon_chain_withdrawals(query) [Boolean] Whether the address has beacon chain withdrawals
  # @parameter has_token_transfers(query) [Boolean] Whether the address has token transfers
  # @parameter has_tokens(query) [Boolean] Whether the address has tokens
  # @parameter has_validated_blocks(query) [Boolean] Whether the address has validated blocks
  # @parameter is_scam(query) [Boolean] Whether the address is a scam
  # @parameter is_verified(query) [Boolean] Whether the address is verified
  # @parameter ens_domain_name(query) [String] ENS domain name
  # @parameter name(query) [String] Address name
  # @parameter hash(query) [String] Address hash
  # @parameter exchange_rate_min(query) [String] Minimum exchange rate
  # @parameter exchange_rate_max(query) [String] Maximum exchange rate
  # @parameter block_number_balance_updated_at_min(query) [Integer] Minimum block number balance updated at
  # @parameter block_number_balance_updated_at_max(query) [Integer] Maximum block number balance updated at
  # @parameter creation_transaction_hash(query) [String] Creation transaction hash
  # @parameter creator_address_hash(query) [String] Creator address hash
  # @parameter proxy_type(query) [String] Proxy type
  # @parameter watchlist_address_id(query) [String] Watchlist address ID
  # @parameter transactions_count_min(query) [Integer] Minimum transactions count
  # @parameter transactions_count_max(query) [Integer] Maximum transactions count
  # @parameter token_transfers_count_min(query) [Integer] Minimum token transfers count
  # @parameter token_transfers_count_max(query) [Integer] Maximum token transfers count
  # @parameter gas_usage_count_min(query) [Integer] Minimum gas usage count
  # @parameter gas_usage_count_max(query) [Integer] Maximum gas usage count
  # @parameter validations_count_min(query) [Integer] Minimum validations count
  # @parameter validations_count_max(query) [Integer] Maximum validations count
  # @parameter tx_hash(query) [String] Transaction hash
  # @parameter tx_status(query) [String] Transaction status
  # @parameter tx_result(query) [String] Transaction result
  # @parameter tx_method(query) [String] Transaction method
  # @parameter tx_type_min(query) [Integer] Minimum transaction type
  # @parameter tx_type_max(query) [Integer] Maximum transaction type
  # @parameter tx_value_min(query) [String] Minimum transaction value
  # @parameter tx_value_max(query) [String] Maximum transaction value
  # @parameter tx_gas_used_min(query) [String] Minimum gas used
  # @parameter tx_gas_used_max(query) [String] Maximum gas used
  # @parameter tx_gas_limit_min(query) [String] Minimum gas limit
  # @parameter tx_gas_limit_max(query) [String] Maximum gas limit
  # @parameter tx_gas_price_min(query) [String] Minimum gas price
  # @parameter tx_gas_price_max(query) [String] Maximum gas price
  # @parameter tx_from_hash(query) [String] Transaction from hash
  # @parameter tx_to_hash(query) [String] Transaction to hash
  # @parameter tx_block_number_min(query) [Integer] Minimum transaction block number
  # @parameter tx_block_number_max(query) [Integer] Maximum transaction block number
  # @parameter token_address(query) [String] Token address
  # @parameter token_name(query) [String] Token name
  # @parameter token_symbol(query) [String] Token symbol
  # @parameter token_type(query) [String] Token type (ERC-20, ERC-721, ERC-1155)
  # @parameter token_decimals_min(query) [Integer] Minimum token decimals
  # @parameter token_decimals_max(query) [Integer] Maximum token decimals
  # @parameter token_holders_min(query) [Integer] Minimum token holders
  # @parameter token_holders_max(query) [Integer] Maximum token holders
  # @parameter token_total_supply_min(query) [String] Minimum token total supply
  # @parameter token_total_supply_max(query) [String] Maximum token total supply
  # @parameter token_balance_value_min(query) [String] Minimum token balance value
  # @parameter token_balance_value_max(query) [String] Maximum token balance value
  # @parameter token_id(query) [String] Token ID
  # @parameter nft_animation_url(query) [String] NFT animation URL
  # @parameter nft_external_app_url(query) [String] NFT external app URL
  # @parameter nft_image_url(query) [String] NFT image URL
  # @parameter nft_media_url(query) [String] NFT media URL
  # @parameter nft_media_type(query) [String] NFT media type
  # @parameter nft_is_unique(query) [Boolean] Whether NFT is unique
  # @parameter nft_token_type(query) [String] NFT token type
  # @parameter nft_metadata_description(query) [String] NFT metadata description
  # @parameter nft_metadata_name(query) [String] NFT metadata name
  # @parameter coin_balance_history_block_number_min(query) [Integer] Minimum coin balance history block number
  # @parameter coin_balance_history_block_number_max(query) [Integer] Maximum coin balance history block number
  # @parameter coin_balance_history_delta_min(query) [String] Minimum coin balance history delta
  # @parameter coin_balance_history_delta_max(query) [String] Maximum coin balance history delta
  # @parameter coin_balance_history_value_min(query) [String] Minimum coin balance history value
  # @parameter coin_balance_history_value_max(query) [String] Maximum coin balance history value
  # @parameter coin_balance_history_tx_hash(query) [String] Coin balance history transaction hash
  # @parameter coin_balance_history_by_day_days_min(query) [Integer] Minimum days in coin balance history by day
  # @parameter coin_balance_history_by_day_days_max(query) [Integer] Maximum days in coin balance history by day
  # @parameter tx_priority_fee_min(query) [String] Minimum transaction priority fee
  # @parameter tx_priority_fee_max(query) [String] Maximum transaction priority fee
  # @parameter tx_raw_input(query) [String] Transaction raw input
  # @parameter tx_max_fee_per_gas_min(query) [String] Minimum max fee per gas
  # @parameter tx_max_fee_per_gas_max(query) [String] Maximum max fee per gas
  # @parameter tx_revert_reason(query) [String] Transaction revert reason
  # @parameter tx_transaction_burnt_fee_min(query) [String] Minimum transaction burnt fee
  # @parameter tx_transaction_burnt_fee_max(query) [String] Maximum transaction burnt fee
  # @parameter tx_token_transfers_overflow(query) [Boolean] Transaction token transfers overflow
  # @parameter tx_confirmations_min(query) [Integer] Minimum transaction confirmations
  # @parameter tx_confirmations_max(query) [Integer] Maximum transaction confirmations
  # @parameter tx_position_min(query) [Integer] Minimum transaction position
  # @parameter tx_position_max(query) [Integer] Maximum transaction position
  # @parameter tx_max_priority_fee_per_gas_min(query) [String] Minimum max priority fee per gas
  # @parameter tx_max_priority_fee_per_gas_max(query) [String] Maximum max priority fee per gas
  # @parameter tx_transaction_tag(query) [String] Transaction tag
  # @parameter tx_created_contract(query) [String] Transaction created contract
  # @parameter tx_base_fee_per_gas_min(query) [String] Minimum base fee per gas
  # @parameter tx_base_fee_per_gas_max(query) [String] Maximum base fee per gas
  # @parameter tx_timestamp_min(query) [String] Minimum transaction timestamp
  # @parameter tx_timestamp_max(query) [String] Maximum transaction timestamp
  # @parameter tx_nonce_min(query) [Integer] Minimum transaction nonce
  # @parameter tx_nonce_max(query) [Integer] Maximum transaction nonce
  # @parameter tx_historic_exchange_rate_min(query) [String] Minimum historic exchange rate
  # @parameter tx_historic_exchange_rate_max(query) [String] Maximum historic exchange rate
  # @parameter tx_exchange_rate_min(query) [String] Minimum transaction exchange rate
  # @parameter tx_exchange_rate_max(query) [String] Maximum transaction exchange rate
  # @parameter tx_has_error_in_internal_transactions(query) [Boolean] Transaction has error in internal transactions
  # @parameter tx_block_hash(query) [String] Transaction block hash
  # @parameter tx_log_index_min(query) [Integer] Minimum transaction log index
  # @parameter tx_log_index_max(query) [Integer] Maximum transaction log index
  # @parameter tx_decoded_input(query) [String] Transaction decoded input
  # @parameter tx_token_transfers(query) [String] Transaction token transfers
  # @parameter tx_fee_type(query) [String] Transaction fee type
  # @parameter tx_fee_value_min(query) [String] Minimum transaction fee value
  # @parameter tx_fee_value_max(query) [String] Maximum transaction fee value
  # @parameter tx_total_decimals_min(query) [Integer] Minimum transaction total decimals
  # @parameter tx_total_decimals_max(query) [Integer] Maximum transaction total decimals
  # @parameter tx_total_value_min(query) [String] Minimum transaction total value
  # @parameter tx_total_value_max(query) [String] Maximum transaction total value
  # @parameter tx_from_ens_domain_name(query) [String] Transaction from ENS domain name
  # @parameter tx_from_is_contract(query) [Boolean] Transaction from is contract
  # @parameter tx_from_is_scam(query) [Boolean] Transaction from is scam
  # @parameter tx_from_is_verified(query) [Boolean] Transaction from is verified
  # @parameter tx_from_name(query) [String] Transaction from name
  # @parameter tx_from_proxy_type(query) [String] Transaction from proxy type
  # @parameter tx_to_ens_domain_name(query) [String] Transaction to ENS domain name
  # @parameter tx_to_is_contract(query) [Boolean] Transaction to is contract
  # @parameter tx_to_is_scam(query) [Boolean] Transaction to is scam
  # @parameter tx_to_is_verified(query) [Boolean] Transaction to is verified
  # @parameter tx_to_name(query) [String] Transaction to name
  # @parameter tx_to_proxy_type(query) [String] Transaction to proxy type
  # @parameter token_circulating_market_cap_min(query) [String] Minimum token circulating market cap
  # @parameter token_circulating_market_cap_max(query) [String] Maximum token circulating market cap
  # @parameter token_icon_url(query) [String] Token icon URL
  # @parameter token_volume_24h_min(query) [String] Minimum token 24h volume
  # @parameter token_volume_24h_max(query) [String] Maximum token 24h volume
  # @parameter token_instance_animation_url(query) [String] Token instance animation URL
  # @parameter token_instance_external_app_url(query) [String] Token instance external app URL
  # @parameter token_instance_id(query) [String] Token instance ID
  # @parameter token_instance_image_url(query) [String] Token instance image URL
  # @parameter token_instance_is_unique(query) [Boolean] Token instance is unique
  # @parameter token_instance_media_type(query) [String] Token instance media type
  # @parameter token_instance_media_url(query) [String] Token instance media URL
  # @parameter token_instance_owner(query) [String] Token instance owner
  # @parameter token_instance_thumbnails(query) [String] Token instance thumbnails
  # @parameter token_instance_metadata_description(query) [String] Token instance metadata description
  # @parameter token_instance_metadata_image(query) [String] Token instance metadata image
  # @parameter token_instance_metadata_name(query) [String] Token instance metadata name
  # @parameter coin_balance_history_block_timestamp_min(query) [String] Minimum coin balance history block timestamp
  # @parameter coin_balance_history_block_timestamp_max(query) [String] Maximum coin balance history block timestamp
  # @parameter nft_collections_amount_min(query) [Integer] Minimum NFT collections amount
  # @parameter nft_collections_amount_max(query) [Integer] Maximum NFT collections amount
  # @parameter metadata_tags_name(query) [String] Metadata tags name
  # @parameter metadata_tags_slug(query) [String] Metadata tags slug
  # @parameter metadata_tags_tag_type(query) [String] Metadata tags tag type
  # @parameter metadata_tags_ordinal_min(query) [Integer] Minimum metadata tags ordinal
  # @parameter metadata_tags_ordinal_max(query) [Integer] Maximum metadata tags ordinal
  # @parameter metadata_tags_meta_main_entity(query) [String] Metadata tags meta main entity
  # @parameter metadata_tags_meta_tooltip_url(query) [String] Metadata tags meta tooltip URL
  # @parameter limit(query) [Integer] Number of results to return (default: 100, max: 1000)
  # @response success(200) [Hash{results: Array<Hash{id: Integer, address_hash: String, data: Hash}>}}]
  def json_search
    addresses = Address.where(nil)
    
    # ETH Balance search (in ETH units - converted to wei)
    if params[:eth_balance_min].present?
      eth_min_wei = (params[:eth_balance_min].to_f * 1e18).to_s
      addresses = addresses.where("CAST(data->'info'->>'coin_balance' AS NUMERIC) >= ?", eth_min_wei)
    end
    if params[:eth_balance_max].present?
      eth_max_wei = (params[:eth_balance_max].to_f * 1e18).to_s
      addresses = addresses.where("CAST(data->'info'->>'coin_balance' AS NUMERIC) <= ?", eth_max_wei)
    end
    
    # Info fields - Boolean
    addresses = addresses.where("data->'info'->>'has_logs' = ?", params[:has_logs].to_s) if params[:has_logs].present?
    addresses = addresses.where("data->'info'->>'is_contract' = ?", params[:is_contract].to_s) if params[:is_contract].present?
    addresses = addresses.where("data->'info'->>'has_beacon_chain_withdrawals' = ?", params[:has_beacon_chain_withdrawals].to_s) if params[:has_beacon_chain_withdrawals].present?
    addresses = addresses.where("data->'info'->>'has_token_transfers' = ?", params[:has_token_transfers].to_s) if params[:has_token_transfers].present?
    addresses = addresses.where("data->'info'->>'has_tokens' = ?", params[:has_tokens].to_s) if params[:has_tokens].present?
    addresses = addresses.where("data->'info'->>'has_validated_blocks' = ?", params[:has_validated_blocks].to_s) if params[:has_validated_blocks].present?
    addresses = addresses.where("data->'info'->>'is_scam' = ?", params[:is_scam].to_s) if params[:is_scam].present?
    addresses = addresses.where("data->'info'->>'is_verified' = ?", params[:is_verified].to_s) if params[:is_verified].present?
    
    # Info fields - String
    addresses = addresses.where("data->'info'->>'ens_domain_name' = ?", params[:ens_domain_name]) if params[:ens_domain_name].present?
    addresses = addresses.where("data->'info'->>'name' = ?", params[:name]) if params[:name].present?
    addresses = addresses.where("data->'info'->>'hash' = ?", params[:hash]) if params[:hash].present?
    addresses = addresses.where("data->'info'->>'creation_transaction_hash' = ?", params[:creation_transaction_hash]) if params[:creation_transaction_hash].present?
    addresses = addresses.where("data->'info'->>'creator_address_hash' = ?", params[:creator_address_hash]) if params[:creator_address_hash].present?
    addresses = addresses.where("data->'info'->>'proxy_type' = ?", params[:proxy_type]) if params[:proxy_type].present?
    addresses = addresses.where("data->'info'->>'watchlist_address_id' = ?", params[:watchlist_address_id]) if params[:watchlist_address_id].present?
    
    # Info fields - Numeric with min/max
    addresses = addresses.where("CAST(data->'info'->>'coin_balance' AS NUMERIC) >= ?", params[:coin_balance_min]) if params[:coin_balance_min].present?
    addresses = addresses.where("CAST(data->'info'->>'coin_balance' AS NUMERIC) <= ?", params[:coin_balance_max]) if params[:coin_balance_max].present?
    addresses = addresses.where("CAST(data->'info'->>'exchange_rate' AS DECIMAL) >= ?", params[:exchange_rate_min].to_f) if params[:exchange_rate_min].present?
    addresses = addresses.where("CAST(data->'info'->>'exchange_rate' AS DECIMAL) <= ?", params[:exchange_rate_max].to_f) if params[:exchange_rate_max].present?
    addresses = addresses.where("CAST(data->'info'->>'block_number_balance_updated_at' AS INTEGER) >= ?", params[:block_number_balance_updated_at_min].to_i) if params[:block_number_balance_updated_at_min].present?
    addresses = addresses.where("CAST(data->'info'->>'block_number_balance_updated_at' AS INTEGER) <= ?", params[:block_number_balance_updated_at_max].to_i) if params[:block_number_balance_updated_at_max].present?
    
    # Counter fields
    addresses = addresses.where("CAST(data->'counters'->>'transactions_count' AS INTEGER) >= ?", params[:transactions_count_min].to_i) if params[:transactions_count_min].present?
    addresses = addresses.where("CAST(data->'counters'->>'transactions_count' AS INTEGER) <= ?", params[:transactions_count_max].to_i) if params[:transactions_count_max].present?
    addresses = addresses.where("CAST(data->'counters'->>'token_transfers_count' AS INTEGER) >= ?", params[:token_transfers_count_min].to_i) if params[:token_transfers_count_min].present?
    addresses = addresses.where("CAST(data->'counters'->>'token_transfers_count' AS INTEGER) <= ?", params[:token_transfers_count_max].to_i) if params[:token_transfers_count_max].present?
    addresses = addresses.where("CAST(data->'counters'->>'gas_usage_count' AS INTEGER) >= ?", params[:gas_usage_count_min].to_i) if params[:gas_usage_count_min].present?
    addresses = addresses.where("CAST(data->'counters'->>'gas_usage_count' AS INTEGER) <= ?", params[:gas_usage_count_max].to_i) if params[:gas_usage_count_max].present?
    addresses = addresses.where("CAST(data->'counters'->>'validations_count' AS INTEGER) >= ?", params[:validations_count_min].to_i) if params[:validations_count_min].present?
    addresses = addresses.where("CAST(data->'counters'->>'validations_count' AS INTEGER) <= ?", params[:validations_count_max].to_i) if params[:validations_count_max].present?
    
    # Transaction fields (nested in transactions->items array)
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ hash: params[:tx_hash] }].to_json) if params[:tx_hash].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ status: params[:tx_status] }].to_json) if params[:tx_status].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ result: params[:tx_result] }].to_json) if params[:tx_result].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ method: params[:tx_method] }].to_json) if params[:tx_method].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ from: { hash: params[:tx_from_hash] } }].to_json) if params[:tx_from_hash].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ to: { hash: params[:tx_to_hash] } }].to_json) if params[:tx_to_hash].present?
    
    # Token fields (nested in token_balances and tokens arrays)
    addresses = addresses.where("data->'token_balances' @> ?", [{ token: { address: params[:token_address] } }].to_json) if params[:token_address].present?
    addresses = addresses.where("data->'token_balances' @> ?", [{ token: { name: params[:token_name] } }].to_json) if params[:token_name].present?
    addresses = addresses.where("data->'token_balances' @> ?", [{ token: { symbol: params[:token_symbol] } }].to_json) if params[:token_symbol].present?
    addresses = addresses.where("data->'token_balances' @> ?", [{ token: { type: params[:token_type] } }].to_json) if params[:token_type].present?
    addresses = addresses.where("data->'token_balances' @> ?", [{ token_id: params[:token_id] }].to_json) if params[:token_id].present?
    
    # NFT fields (nested in nft->items array)
    addresses = addresses.where("data->'nft'->'items' @> ?", [{ animation_url: params[:nft_animation_url] }].to_json) if params[:nft_animation_url].present?
    addresses = addresses.where("data->'nft'->'items' @> ?", [{ external_app_url: params[:nft_external_app_url] }].to_json) if params[:nft_external_app_url].present?
    addresses = addresses.where("data->'nft'->'items' @> ?", [{ image_url: params[:nft_image_url] }].to_json) if params[:nft_image_url].present?
    addresses = addresses.where("data->'nft'->'items' @> ?", [{ media_url: params[:nft_media_url] }].to_json) if params[:nft_media_url].present?
    addresses = addresses.where("data->'nft'->'items' @> ?", [{ media_type: params[:nft_media_type] }].to_json) if params[:nft_media_type].present?
    addresses = addresses.where("data->'nft'->'items' @> ?", [{ is_unique: params[:nft_is_unique] }].to_json) if params[:nft_is_unique].present?
    addresses = addresses.where("data->'nft'->'items' @> ?", [{ token_type: params[:nft_token_type] }].to_json) if params[:nft_token_type].present?
    addresses = addresses.where("data->'nft'->'items' @> ?", [{ metadata: { description: params[:nft_metadata_description] } }].to_json) if params[:nft_metadata_description].present?
    addresses = addresses.where("data->'nft'->'items' @> ?", [{ metadata: { name: params[:nft_metadata_name] } }].to_json) if params[:nft_metadata_name].present?
    
    # Coin balance history fields (nested in coin_balance_history->items array)
    addresses = addresses.where("data->'coin_balance_history'->'items' @> ?", [{ transaction_hash: params[:coin_balance_history_tx_hash] }].to_json) if params[:coin_balance_history_tx_hash].present?
    addresses = addresses.where("CAST(data->'coin_balance_history_by_day'->>'days' AS INTEGER) >= ?", params[:coin_balance_history_by_day_days_min].to_i) if params[:coin_balance_history_by_day_days_min].present?
    addresses = addresses.where("CAST(data->'coin_balance_history_by_day'->>'days' AS INTEGER) <= ?", params[:coin_balance_history_by_day_days_max].to_i) if params[:coin_balance_history_by_day_days_max].present?
    addresses = addresses.where("data->'coin_balance_history'->'items' @> ?", [{ block_timestamp: params[:coin_balance_history_block_timestamp_min] }].to_json) if params[:coin_balance_history_block_timestamp_min].present?
    addresses = addresses.where("data->'coin_balance_history'->'items' @> ?", [{ block_timestamp: params[:coin_balance_history_block_timestamp_max] }].to_json) if params[:coin_balance_history_block_timestamp_max].present?
    
    # Additional Transaction fields (nested in transactions->items array)
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ priority_fee: params[:tx_priority_fee_min] }].to_json) if params[:tx_priority_fee_min].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ raw_input: params[:tx_raw_input] }].to_json) if params[:tx_raw_input].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ revert_reason: params[:tx_revert_reason] }].to_json) if params[:tx_revert_reason].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ token_transfers_overflow: params[:tx_token_transfers_overflow] }].to_json) if params[:tx_token_transfers_overflow].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ transaction_tag: params[:tx_transaction_tag] }].to_json) if params[:tx_transaction_tag].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ created_contract: params[:tx_created_contract] }].to_json) if params[:tx_created_contract].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ decoded_input: params[:tx_decoded_input] }].to_json) if params[:tx_decoded_input].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ token_transfers: params[:tx_token_transfers] }].to_json) if params[:tx_token_transfers].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ has_error_in_internal_transactions: params[:tx_has_error_in_internal_transactions] }].to_json) if params[:tx_has_error_in_internal_transactions].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ block_hash: params[:tx_block_hash] }].to_json) if params[:tx_block_hash].present?
    
    # Transaction fee fields
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ fee: { type: params[:tx_fee_type] } }].to_json) if params[:tx_fee_type].present?
    
    # Transaction total fields  
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ total: { decimals: params[:tx_total_decimals_min] } }].to_json) if params[:tx_total_decimals_min].present?
    
    # Transaction from/to address fields
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ from: { ens_domain_name: params[:tx_from_ens_domain_name] } }].to_json) if params[:tx_from_ens_domain_name].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ from: { is_contract: params[:tx_from_is_contract] } }].to_json) if params[:tx_from_is_contract].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ from: { is_scam: params[:tx_from_is_scam] } }].to_json) if params[:tx_from_is_scam].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ from: { is_verified: params[:tx_from_is_verified] } }].to_json) if params[:tx_from_is_verified].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ from: { name: params[:tx_from_name] } }].to_json) if params[:tx_from_name].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ from: { proxy_type: params[:tx_from_proxy_type] } }].to_json) if params[:tx_from_proxy_type].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ to: { ens_domain_name: params[:tx_to_ens_domain_name] } }].to_json) if params[:tx_to_ens_domain_name].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ to: { is_contract: params[:tx_to_is_contract] } }].to_json) if params[:tx_to_is_contract].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ to: { is_scam: params[:tx_to_is_scam] } }].to_json) if params[:tx_to_is_scam].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ to: { is_verified: params[:tx_to_is_verified] } }].to_json) if params[:tx_to_is_verified].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ to: { name: params[:tx_to_name] } }].to_json) if params[:tx_to_name].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ to: { proxy_type: params[:tx_to_proxy_type] } }].to_json) if params[:tx_to_proxy_type].present?
    
    # Additional Token fields
    addresses = addresses.where("data->'token_balances' @> ?", [{ token: { icon_url: params[:token_icon_url] } }].to_json) if params[:token_icon_url].present?
    
    # Token instance fields (nested in tokens->items->token_instance)
    addresses = addresses.where("data->'tokens'->'items' @> ?", [{ token_instance: { animation_url: params[:token_instance_animation_url] } }].to_json) if params[:token_instance_animation_url].present?
    addresses = addresses.where("data->'tokens'->'items' @> ?", [{ token_instance: { external_app_url: params[:token_instance_external_app_url] } }].to_json) if params[:token_instance_external_app_url].present?
    addresses = addresses.where("data->'tokens'->'items' @> ?", [{ token_instance: { id: params[:token_instance_id] } }].to_json) if params[:token_instance_id].present?
    addresses = addresses.where("data->'tokens'->'items' @> ?", [{ token_instance: { image_url: params[:token_instance_image_url] } }].to_json) if params[:token_instance_image_url].present?
    addresses = addresses.where("data->'tokens'->'items' @> ?", [{ token_instance: { is_unique: params[:token_instance_is_unique] } }].to_json) if params[:token_instance_is_unique].present?
    addresses = addresses.where("data->'tokens'->'items' @> ?", [{ token_instance: { media_type: params[:token_instance_media_type] } }].to_json) if params[:token_instance_media_type].present?
    addresses = addresses.where("data->'tokens'->'items' @> ?", [{ token_instance: { media_url: params[:token_instance_media_url] } }].to_json) if params[:token_instance_media_url].present?
    addresses = addresses.where("data->'tokens'->'items' @> ?", [{ token_instance: { owner: params[:token_instance_owner] } }].to_json) if params[:token_instance_owner].present?
    addresses = addresses.where("data->'tokens'->'items' @> ?", [{ token_instance: { thumbnails: params[:token_instance_thumbnails] } }].to_json) if params[:token_instance_thumbnails].present?
    addresses = addresses.where("data->'tokens'->'items' @> ?", [{ token_instance: { metadata: { description: params[:token_instance_metadata_description] } } }].to_json) if params[:token_instance_metadata_description].present?
    addresses = addresses.where("data->'tokens'->'items' @> ?", [{ token_instance: { metadata: { image: params[:token_instance_metadata_image] } } }].to_json) if params[:token_instance_metadata_image].present?
    addresses = addresses.where("data->'tokens'->'items' @> ?", [{ token_instance: { metadata: { name: params[:token_instance_metadata_name] } } }].to_json) if params[:token_instance_metadata_name].present?
    
    # NFT collections fields
    addresses = addresses.where("data->'nft_collections'->'items' @> ?", [{ amount: params[:nft_collections_amount_min] }].to_json) if params[:nft_collections_amount_min].present?
    
    # Metadata tags fields (nested in transactions->items->from/to->metadata->tags)
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ from: { metadata: { tags: [{ name: params[:metadata_tags_name] }] } } }].to_json) if params[:metadata_tags_name].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ from: { metadata: { tags: [{ slug: params[:metadata_tags_slug] }] } } }].to_json) if params[:metadata_tags_slug].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ from: { metadata: { tags: [{ tagType: params[:metadata_tags_tag_type] }] } } }].to_json) if params[:metadata_tags_tag_type].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ from: { metadata: { tags: [{ meta: { main_entity: params[:metadata_tags_meta_main_entity] } }] } } }].to_json) if params[:metadata_tags_meta_main_entity].present?
    addresses = addresses.where("data->'transactions'->'items' @> ?", [{ from: { metadata: { tags: [{ meta: { tooltipUrl: params[:metadata_tags_meta_tooltip_url] } }] } } }].to_json) if params[:metadata_tags_meta_tooltip_url].present?
    
    # Apply limit with default and maximum
    limit = params[:limit]&.to_i || 100
    
    render json: { results: addresses.limit(limit) }
  end

  private

  def get_address_info(address)
    blockscout_api_get("/addresses/#{address}")
  end

  def get_address_counters(address)
    blockscout_api_get("/addresses/#{address}/counters")
  end

  def get_address_transactions(address)
    blockscout_api_get("/addresses/#{address}/transactions")
  end

  def get_address_token_transfers(address)
    blockscout_api_get("/addresses/#{address}/token-transfers")
  end

  def get_address_internal_transactions(address)
    blockscout_api_get("/addresses/#{address}/internal-transactions")
  end

  def get_address_logs(address)
    blockscout_api_get("/addresses/#{address}/logs")
  end

  def get_address_blocks_validated(address)
    blockscout_api_get("/addresses/#{address}/blocks-validated")
  end

  def get_address_token_balances(address)
    blockscout_api_get("/addresses/#{address}/token-balances")
  end

  def get_address_tokens(address)
    blockscout_api_get("/addresses/#{address}/tokens")
  end

  def get_address_coin_balance_history(address)
    blockscout_api_get("/addresses/#{address}/coin-balance-history")
  end

  def get_address_coin_balance_history_by_day(address)
    blockscout_api_get("/addresses/#{address}/coin-balance-history-by-day")
  end

  def get_address_withdrawals(address)
    blockscout_api_get("/addresses/#{address}/withdrawals")
  end

  def get_address_nft(address)
    blockscout_api_get("/addresses/#{address}/nft")
  end

  def get_address_nft_collections(address)
    blockscout_api_get("/addresses/#{address}/nft/collections")
  end
end



