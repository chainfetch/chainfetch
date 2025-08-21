class Api::V1::Ethereum::AddressesController < Api::V1::Ethereum::BaseController
  # @summary Get address info
  # @parameter address(path) [!String] The address hash to get info for
  # @response success(200) [Hash{info: Hash, counters: Hash, transactions: Hash, token_transfers: Hash, internal_transactions: Hash, logs: Hash, blocks_validated: Hash, token_balances: Hash, tokens: Hash, withdrawals: Hash, nft: Hash, nft_collections: Hash}]
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
        withdrawals: Async { get_address_withdrawals(address) },
        nft: Async { get_address_nft(address) },
        nft_collections: Async { get_address_nft_collections(address) }
      }
      
      render json: tasks.transform_values(&:wait)
    end
  end

  # @summary LLM Search for addresses
  # @parameter query(query) [!String] The query to search for
  # @response success(200) [Hash{results: String}]
  # This endpoint leverages LLaMA 3.2 3B model to analyze and select the most suitable parameters from over 150 available options
  def llm_search
    query = params[:query]
    response = AddressDataSearchService.new(query).call
    render json: response
  end

  # @summary Address Summary
  # @parameter address_hash(query) [!String] The address hash to search for
  # @response success(200) [Hash{summary: String}]
  def address_summary
    address_hash = params[:address_hash]
    address_data = Ethereum::AddressDataService.new(address_hash).call
    summary = Ethereum::AddressSummaryService.new(address_data).call
    render json: { summary: summary }
  end

  # @summary Semantic Search for addresses
  # @parameter query(query) [!String] The query to search for
  # @parameter limit(query) [!Integer] The number of results to return (default: 10)
  # @response success(200) [Hash{result: Hash{points: Array<Hash{id: Integer, version: Integer, score: Float, payload: Hash{address_summary: String}}}>}}]
  # This endpoint queries Qdrant to search for addresses based on the provided input. Address summaries are embedded using gemini-embedding-001 and stored in Qdrant's 'addresses' collection.
  def semantic_search
    query = params[:query]
    limit = params[:limit] || 10
    embedding = Embedding::GeminiService.new(query).embed_query
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

  # @parameter nft_collections_amount_min(query) [Integer] Minimum NFT collections amount
  # @parameter nft_collections_amount_max(query) [Integer] Maximum NFT collections amount
  # @parameter metadata_tags_name(query) [String] Metadata tags name
  # @parameter metadata_tags_slug(query) [String] Metadata tags slug
  # @parameter metadata_tags_tag_type(query) [String] Metadata tags tag type
  # @parameter metadata_tags_ordinal_min(query) [Integer] Minimum metadata tags ordinal
  # @parameter metadata_tags_ordinal_max(query) [Integer] Maximum metadata tags ordinal
  # @parameter metadata_tags_meta_main_entity(query) [String] Metadata tags meta main entity
  # @parameter metadata_tags_meta_tooltip_url(query) [String] Metadata tags meta tooltip URL
  # @parameter limit(query) [Integer] Number of results to return (default: 10, max: 50)
  # @parameter offset(query) [Integer] Number of results to skip for pagination (default: 0)
  # @parameter page(query) [Integer] Page number (alternative to offset, starts at 1)
  # @parameter sort_by(query) [String] Field to sort by (default: "id")
  # @parameter sort_order(query) [String] Sort direction: "asc" or "desc" (default: "desc")
  # @response success(200) [Hash{results: Array<Hash{id: Integer, address_hash: String, data: Hash}>, pagination: Hash{total: Integer, limit: Integer, offset: Integer, page: Integer, total_pages: Integer}}]
  # This endpoint provides address search with string-based comparisons for scalability (no CAST operations).
  def json_search
    addresses = EthereumAddress.where(nil)
    
    # ETH Balance search (in ETH units)
    if params[:eth_balance_min].present?
      addresses = addresses.where("eth_balance >= ?", params[:eth_balance_min].to_f)
    end
    if params[:eth_balance_max].present?
      addresses = addresses.where("eth_balance <= ?", params[:eth_balance_max].to_f)
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
    
    # Info fields - Numeric with min/max using string comparisons
    addresses = addresses.where("data->'info'->>'coin_balance' >= ?", params[:coin_balance_min]) if params[:coin_balance_min].present?
    addresses = addresses.where("data->'info'->>'coin_balance' <= ?", params[:coin_balance_max]) if params[:coin_balance_max].present?
    addresses = addresses.where("data->'info'->>'exchange_rate' >= ?", params[:exchange_rate_min]) if params[:exchange_rate_min].present?
    addresses = addresses.where("data->'info'->>'exchange_rate' <= ?", params[:exchange_rate_max]) if params[:exchange_rate_max].present?
    addresses = addresses.where("data->'info'->>'block_number_balance_updated_at' >= ?", params[:block_number_balance_updated_at_min]) if params[:block_number_balance_updated_at_min].present?
    addresses = addresses.where("data->'info'->>'block_number_balance_updated_at' <= ?", params[:block_number_balance_updated_at_max]) if params[:block_number_balance_updated_at_max].present?
    
    # Counter fields
    addresses = addresses.where("data->'counters'->>'transactions_count' >= ?", params[:transactions_count_min]) if params[:transactions_count_min].present?
    addresses = addresses.where("data->'counters'->>'transactions_count' <= ?", params[:transactions_count_max]) if params[:transactions_count_max].present?
    addresses = addresses.where("data->'counters'->>'token_transfers_count' >= ?", params[:token_transfers_count_min]) if params[:token_transfers_count_min].present?
    addresses = addresses.where("data->'counters'->>'token_transfers_count' <= ?", params[:token_transfers_count_max]) if params[:token_transfers_count_max].present?
    addresses = addresses.where("data->'counters'->>'gas_usage_count' >= ?", params[:gas_usage_count_min]) if params[:gas_usage_count_min].present?
    addresses = addresses.where("data->'counters'->>'gas_usage_count' <= ?", params[:gas_usage_count_max]) if params[:gas_usage_count_max].present?
    addresses = addresses.where("data->'counters'->>'validations_count' >= ?", params[:validations_count_min]) if params[:validations_count_min].present?
    addresses = addresses.where("data->'counters'->>'validations_count' <= ?", params[:validations_count_max]) if params[:validations_count_max].present?
    
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
    
    # Apply sorting
    sort_by = params[:sort_by] || 'id'
    sort_order = params[:sort_order]&.downcase == 'asc' ? 'asc' : 'desc'
    
    allowed_sort_fields = {
      # Basic fields
      'id' => 'ethereum_addresses.id',
      'created_at' => 'ethereum_addresses.created_at',
      'updated_at' => 'ethereum_addresses.updated_at',
      'address_hash' => 'ethereum_addresses.address_hash',
      'eth_balance' => 'ethereum_addresses.eth_balance',
      
      # Boolean fields (convert to numeric for sorting)
      'has_logs' => "CASE WHEN data->'info'->>'has_logs' = 'true' THEN 1 ELSE 0 END",
      'is_contract' => "CASE WHEN data->'info'->>'is_contract' = 'true' THEN 1 ELSE 0 END",
      'has_beacon_chain_withdrawals' => "CASE WHEN data->'info'->>'has_beacon_chain_withdrawals' = 'true' THEN 1 ELSE 0 END",
      'has_token_transfers' => "CASE WHEN data->'info'->>'has_token_transfers' = 'true' THEN 1 ELSE 0 END",
      'has_tokens' => "CASE WHEN data->'info'->>'has_tokens' = 'true' THEN 1 ELSE 0 END",
      'has_validated_blocks' => "CASE WHEN data->'info'->>'has_validated_blocks' = 'true' THEN 1 ELSE 0 END",
      'is_scam' => "CASE WHEN data->'info'->>'is_scam' = 'true' THEN 1 ELSE 0 END",
      'is_verified' => "CASE WHEN data->'info'->>'is_verified' = 'true' THEN 1 ELSE 0 END",
      
      # String fields
      'ens_domain_name' => "data->'info'->>'ens_domain_name'",
      'name' => "data->'info'->>'name'",
      'hash' => "data->'info'->>'hash'",
      'creation_transaction_hash' => "data->'info'->>'creation_transaction_hash'",
      'creator_address_hash' => "data->'info'->>'creator_address_hash'",
      'proxy_type' => "data->'info'->>'proxy_type'",
      'watchlist_address_id' => "data->'info'->>'watchlist_address_id'",
      
      # Transaction fields (from transactions->items array, using first item)
      'tx_hash' => "data->'transactions'->'items'->0->>'hash'",
      'tx_status' => "data->'transactions'->'items'->0->>'status'",
      'tx_result' => "data->'transactions'->'items'->0->>'result'",
      'tx_method' => "data->'transactions'->'items'->0->>'method'",
      'tx_block_hash' => "data->'transactions'->'items'->0->>'block_hash'",
      'tx_raw_input' => "data->'transactions'->'items'->0->>'raw_input'",
      'tx_revert_reason' => "data->'transactions'->'items'->0->>'revert_reason'",
      'tx_token_transfers_overflow' => "CASE WHEN data->'transactions'->'items'->0->>'token_transfers_overflow' = 'true' THEN 1 ELSE 0 END",
      'tx_transaction_tag' => "data->'transactions'->'items'->0->>'transaction_tag'",
      'tx_created_contract' => "data->'transactions'->'items'->0->>'created_contract'",
      'tx_timestamp' => "data->'transactions'->'items'->0->>'timestamp'",
      'tx_has_error_in_internal_transactions' => "CASE WHEN data->'transactions'->'items'->0->>'has_error_in_internal_transactions' = 'true' THEN 1 ELSE 0 END",
      'tx_decoded_input' => "data->'transactions'->'items'->0->>'decoded_input'",
      'tx_token_transfers' => "data->'transactions'->'items'->0->>'token_transfers'",
      'tx_fee_type' => "data->'transactions'->'items'->0->'fee'->>'type'",
      
      # Transaction from/to address fields
      'tx_from_hash' => "data->'transactions'->'items'->0->'from'->>'hash'",
      'tx_from_ens_domain_name' => "data->'transactions'->'items'->0->'from'->>'ens_domain_name'",
      'tx_from_is_contract' => "CASE WHEN data->'transactions'->'items'->0->'from'->>'is_contract' = 'true' THEN 1 ELSE 0 END",
      'tx_from_is_scam' => "CASE WHEN data->'transactions'->'items'->0->'from'->>'is_scam' = 'true' THEN 1 ELSE 0 END",
      'tx_from_is_verified' => "CASE WHEN data->'transactions'->'items'->0->'from'->>'is_verified' = 'true' THEN 1 ELSE 0 END",
      'tx_from_name' => "data->'transactions'->'items'->0->'from'->>'name'",
      'tx_from_proxy_type' => "data->'transactions'->'items'->0->'from'->>'proxy_type'",
      'tx_to_hash' => "data->'transactions'->'items'->0->'to'->>'hash'",
      'tx_to_ens_domain_name' => "data->'transactions'->'items'->0->'to'->>'ens_domain_name'",
      'tx_to_is_contract' => "CASE WHEN data->'transactions'->'items'->0->'to'->>'is_contract' = 'true' THEN 1 ELSE 0 END",
      'tx_to_is_scam' => "CASE WHEN data->'transactions'->'items'->0->'to'->>'is_scam' = 'true' THEN 1 ELSE 0 END",
      'tx_to_is_verified' => "CASE WHEN data->'transactions'->'items'->0->'to'->>'is_verified' = 'true' THEN 1 ELSE 0 END",
      'tx_to_name' => "data->'transactions'->'items'->0->'to'->>'name'",
      'tx_to_proxy_type' => "data->'transactions'->'items'->0->'to'->>'proxy_type'",
      
      # Token fields (from token_balances->items array, using first item)
      'token_address' => "data->'token_balances'->0->'token'->>'address'",
      'token_name' => "data->'token_balances'->0->'token'->>'name'",
      'token_symbol' => "data->'token_balances'->0->'token'->>'symbol'",
      'token_type' => "data->'token_balances'->0->'token'->>'type'",
      'token_id' => "data->'token_balances'->0->>'token_id'",
      'token_icon_url' => "data->'token_balances'->0->'token'->>'icon_url'",
      
      # Token instance fields (from tokens->items array, using first item)
      'token_instance_animation_url' => "data->'tokens'->'items'->0->'token_instance'->>'animation_url'",
      'token_instance_external_app_url' => "data->'tokens'->'items'->0->'token_instance'->>'external_app_url'",
      'token_instance_id' => "data->'tokens'->'items'->0->'token_instance'->>'id'",
      'token_instance_image_url' => "data->'tokens'->'items'->0->'token_instance'->>'image_url'",
      'token_instance_is_unique' => "CASE WHEN data->'tokens'->'items'->0->'token_instance'->>'is_unique' = 'true' THEN 1 ELSE 0 END",
      'token_instance_media_type' => "data->'tokens'->'items'->0->'token_instance'->>'media_type'",
      'token_instance_media_url' => "data->'tokens'->'items'->0->'token_instance'->>'media_url'",
      'token_instance_owner' => "data->'tokens'->'items'->0->'token_instance'->>'owner'",
      'token_instance_thumbnails' => "data->'tokens'->'items'->0->'token_instance'->>'thumbnails'",
      'token_instance_metadata_description' => "data->'tokens'->'items'->0->'token_instance'->'metadata'->>'description'",
      'token_instance_metadata_image' => "data->'tokens'->'items'->0->'token_instance'->'metadata'->>'image'",
      'token_instance_metadata_name' => "data->'tokens'->'items'->0->'token_instance'->'metadata'->>'name'",
      
      # NFT fields (from nft->items array, using first item)
      'nft_animation_url' => "data->'nft'->'items'->0->>'animation_url'",
      'nft_external_app_url' => "data->'nft'->'items'->0->>'external_app_url'",
      'nft_image_url' => "data->'nft'->'items'->0->>'image_url'",
      'nft_media_url' => "data->'nft'->'items'->0->>'media_url'",
      'nft_media_type' => "data->'nft'->'items'->0->>'media_type'",
      'nft_is_unique' => "CASE WHEN data->'nft'->'items'->0->>'is_unique' = 'true' THEN 1 ELSE 0 END",
      'nft_token_type' => "data->'nft'->'items'->0->>'token_type'",
      'nft_metadata_description' => "data->'nft'->'items'->0->'metadata'->>'description'",
      'nft_metadata_name' => "data->'nft'->'items'->0->'metadata'->>'name'",
      
      # Metadata tags fields (from transactions->items->from->metadata->tags array)
      'metadata_tags_name' => "data->'transactions'->'items'->0->'from'->'metadata'->'tags'->0->>'name'",
      'metadata_tags_slug' => "data->'transactions'->'items'->0->'from'->'metadata'->'tags'->0->>'slug'",
      'metadata_tags_tag_type' => "data->'transactions'->'items'->0->'from'->'metadata'->'tags'->0->>'tagType'",
      'metadata_tags_meta_main_entity' => "data->'transactions'->'items'->0->'from'->'metadata'->'tags'->0->'meta'->>'main_entity'",
      'metadata_tags_meta_tooltip_url' => "data->'transactions'->'items'->0->'from'->'metadata'->'tags'->0->'meta'->>'tooltipUrl'"
    }
    
    if allowed_sort_fields.key?(sort_by)
      sort_column = allowed_sort_fields[sort_by]
      # Add NULLS LAST for JSON-based fields to ensure addresses with data come first
      if sort_column.include?("data->")
        addresses = addresses.order(Arel.sql("#{sort_column} #{sort_order} NULLS LAST"))
      else
        addresses = addresses.order(Arel.sql("#{sort_column} #{sort_order}"))
      end
    else
      # Default fallback
      addresses = addresses.order(id: :desc)
    end
    
    # Apply pagination with defaults
    limit = params[:limit]&.to_i || 10
    limit = [limit, 50].min # Ensure limit doesn't exceed maximum
    
    # Calculate offset from either offset param or page param
    offset = if params[:page].present?
               page = [params[:page].to_i, 1].max # Ensure page is at least 1
               (page - 1) * limit
             else
               params[:offset]&.to_i || 0
             end
    
    # Get total count before applying limit/offset
    total_count = addresses.count
    
    # Apply pagination
    paginated_addresses = addresses.limit(limit).offset(offset)
    
    # Calculate pagination metadata
    current_page = (offset / limit) + 1
    total_pages = (total_count.to_f / limit).ceil
    
    render json: {
      results: paginated_addresses.pluck(:address_hash),
      pagination: {
        total: total_count,
        limit: limit,
        offset: offset,
        page: current_page,
        total_pages: total_pages
      }
    }
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


# EthereumAddress.find_in_batches(batch_size: 100) do |batch|
#   batch.each do |address|
#     wei_str = address.data&.dig('info', 'coin_balance')
#     wei = wei_str.present? ? BigDecimal(wei_str) : 0
#     eth_balance = wei / 1e18
#     address.update!(eth_balance: eth_balance)
#   end
# end

