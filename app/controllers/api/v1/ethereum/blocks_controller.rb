class Api::V1::Ethereum::BlocksController < Api::V1::Ethereum::BaseController
  # @summary Get block info
  # @parameter block(path) [!String] The block number to get info for
  # @response success(200) [Hash{info: Hash, transactions: Hash, withdrawals: Hash}]
  def show
    block = params[:block]
    Sync do
      tasks = {
        info: Async { get_block_info(block) },
        transactions: Async { get_block_transactions(block) },
        withdrawals: Async { get_block_withdrawals(block) },
      }

      render json: tasks.transform_values(&:wait)
    end
  end

  # @summary Semantic Search for blocks
  # @parameter query(query) [!String] The query to search for
  # @parameter limit(query) [!Integer] The number of results to return (default: 10)
  # @response success(200) [Hash{result: Hash{points: Array<Hash{id: Integer, version: Integer, score: Float, payload: Hash{block_summary: String}}}>}}]
  # This endpoint queries Qdrant to search blocks based on the provided input. Block summaries are embedded using dengcao/Qwen3-Embedding-0.6B:Q8_0 and stored in Qdrant's 'blocks' collection.
  def semantic_search
    query = params[:query]
    limit = params[:limit] || 10
    embedding = EmbeddingService.new(query).call
    qdrant_objects = QdrantService.new.query_points(collection: "blocks", query: embedding, limit: limit)
    render json: qdrant_objects
  end

  # @summary LLM Search for blocks
  # @parameter query(query) [!String] The query to search for
  # @response success(200) [Hash{results: String}]
  # This endpoint leverages LLaMA 3.2 3B model to analyze and select the most suitable parameters from over 120+ available options
  def llm_search
    query = params[:query]
    response = BlockDataSearchService.new(query).call
    render json: response
  end

  # @summary JSON Search for blocks
  # @parameter base_fee_per_gas_min(query) [String] Minimum base fee per gas (e.g., "995703568")
  # @parameter base_fee_per_gas_max(query) [String] Maximum base fee per gas (e.g., "1000000000")
  # @parameter blob_gas_price_min(query) [String] Minimum blob gas price (e.g., "1")
  # @parameter blob_gas_price_max(query) [String] Maximum blob gas price (e.g., "10")
  # @parameter blob_gas_used_min(query) [String] Minimum blob gas used (e.g., "524288")
  # @parameter blob_gas_used_max(query) [String] Maximum blob gas used (e.g., "1000000")
  # @parameter blob_transaction_count_min(query) [Integer] Minimum blob transaction count
  # @parameter blob_transaction_count_max(query) [Integer] Maximum blob transaction count
  # @parameter blob_transactions_count_min(query) [Integer] Minimum blob transactions count
  # @parameter blob_transactions_count_max(query) [Integer] Maximum blob transactions count
  # @parameter burnt_blob_fees_min(query) [String] Minimum burnt blob fees
  # @parameter burnt_blob_fees_max(query) [String] Maximum burnt blob fees
  # @parameter burnt_fees_min(query) [String] Minimum burnt fees
  # @parameter burnt_fees_max(query) [String] Maximum burnt fees
  # @parameter burnt_fees_percentage_min(query) [Float] Minimum burnt fees percentage
  # @parameter burnt_fees_percentage_max(query) [Float] Maximum burnt fees percentage
  # @parameter difficulty_min(query) [String] Minimum difficulty
  # @parameter difficulty_max(query) [String] Maximum difficulty
  # @parameter excess_blob_gas_min(query) [String] Minimum excess blob gas
  # @parameter excess_blob_gas_max(query) [String] Maximum excess blob gas
  # @parameter gas_limit_min(query) [String] Minimum gas limit
  # @parameter gas_limit_max(query) [String] Maximum gas limit
  # @parameter gas_target_percentage_min(query) [Float] Minimum gas target percentage
  # @parameter gas_target_percentage_max(query) [Float] Maximum gas target percentage
  # @parameter gas_used_min(query) [String] Minimum gas used
  # @parameter gas_used_max(query) [String] Maximum gas used
  # @parameter gas_used_percentage_min(query) [Float] Minimum gas used percentage
  # @parameter gas_used_percentage_max(query) [Float] Maximum gas used percentage
  # @parameter hash(query) [String] Block hash
  # @parameter height_min(query) [Integer] Minimum block height
  # @parameter height_max(query) [Integer] Maximum block height
  # @parameter internal_transactions_count_min(query) [Integer] Minimum internal transactions count
  # @parameter internal_transactions_count_max(query) [Integer] Maximum internal transactions count
  # @parameter miner_hash(query) [String] Miner address hash
  # @parameter miner_ens_domain_name(query) [String] Miner ENS domain name
  # @parameter miner_is_contract(query) [Boolean] Whether miner is contract
  # @parameter miner_is_scam(query) [Boolean] Whether miner is scam
  # @parameter miner_is_verified(query) [Boolean] Whether miner is verified
  # @parameter miner_name(query) [String] Miner name
  # @parameter miner_proxy_type(query) [String] Miner proxy type
  # @parameter nonce(query) [String] Block nonce
  # @parameter parent_hash(query) [String] Parent block hash
  # @parameter priority_fee_min(query) [String] Minimum priority fee
  # @parameter priority_fee_max(query) [String] Maximum priority fee
  # @parameter reward_type(query) [String] Reward type
  # @parameter reward_value_min(query) [String] Minimum reward value
  # @parameter reward_value_max(query) [String] Maximum reward value
  # @parameter size_min(query) [Integer] Minimum block size
  # @parameter size_max(query) [Integer] Maximum block size
  # @parameter timestamp_min(query) [String] Minimum timestamp (ISO format)
  # @parameter timestamp_max(query) [String] Maximum timestamp (ISO format)
  # @parameter total_difficulty_min(query) [String] Minimum total difficulty
  # @parameter total_difficulty_max(query) [String] Maximum total difficulty
  # @parameter transaction_count_min(query) [Integer] Minimum transaction count
  # @parameter transaction_count_max(query) [Integer] Maximum transaction count
  # @parameter transaction_fees_min(query) [String] Minimum transaction fees
  # @parameter transaction_fees_max(query) [String] Maximum transaction fees
  # @parameter transactions_count_min(query) [Integer] Minimum transactions count
  # @parameter transactions_count_max(query) [Integer] Maximum transactions count
  # @parameter block_type(query) [String] Block type
  # @parameter withdrawals_count_min(query) [Integer] Minimum withdrawals count
  # @parameter withdrawals_count_max(query) [Integer] Maximum withdrawals count
  # @parameter tx_hash(query) [String] Transaction hash
  # @parameter tx_priority_fee_min(query) [String] Minimum transaction priority fee
  # @parameter tx_priority_fee_max(query) [String] Maximum transaction priority fee
  # @parameter tx_raw_input(query) [String] Transaction raw input
  # @parameter tx_result(query) [String] Transaction result
  # @parameter tx_max_fee_per_gas_min(query) [String] Minimum transaction max fee per gas
  # @parameter tx_max_fee_per_gas_max(query) [String] Maximum transaction max fee per gas
  # @parameter tx_revert_reason(query) [String] Transaction revert reason
  # @parameter tx_confirmation_duration_min(query) [Integer] Minimum confirmation duration
  # @parameter tx_confirmation_duration_max(query) [Integer] Maximum confirmation duration
  # @parameter tx_transaction_burnt_fee_min(query) [String] Minimum transaction burnt fee
  # @parameter tx_transaction_burnt_fee_max(query) [String] Maximum transaction burnt fee
  # @parameter tx_type_min(query) [Integer] Minimum transaction type
  # @parameter tx_type_max(query) [Integer] Maximum transaction type
  # @parameter tx_token_transfers_overflow(query) [Boolean] Transaction token transfers overflow
  # @parameter tx_confirmations_min(query) [Integer] Minimum transaction confirmations
  # @parameter tx_confirmations_max(query) [Integer] Maximum transaction confirmations
  # @parameter tx_position_min(query) [Integer] Minimum transaction position
  # @parameter tx_position_max(query) [Integer] Maximum transaction position
  # @parameter tx_max_priority_fee_per_gas_min(query) [String] Minimum transaction max priority fee per gas
  # @parameter tx_max_priority_fee_per_gas_max(query) [String] Maximum transaction max priority fee per gas
  # @parameter tx_transaction_tag(query) [String] Transaction tag
  # @parameter tx_created_contract(query) [String] Transaction created contract
  # @parameter tx_value_min(query) [String] Minimum transaction value
  # @parameter tx_value_max(query) [String] Maximum transaction value
  # @parameter tx_from_hash(query) [String] Transaction from hash
  # @parameter tx_from_ens_domain_name(query) [String] Transaction from ENS domain name
  # @parameter tx_from_is_contract(query) [Boolean] Transaction from is contract
  # @parameter tx_from_is_scam(query) [Boolean] Transaction from is scam
  # @parameter tx_from_is_verified(query) [Boolean] Transaction from is verified
  # @parameter tx_from_name(query) [String] Transaction from name
  # @parameter tx_from_proxy_type(query) [String] Transaction from proxy type
  # @parameter tx_gas_used_min(query) [String] Minimum transaction gas used
  # @parameter tx_gas_used_max(query) [String] Maximum transaction gas used
  # @parameter tx_status(query) [String] Transaction status
  # @parameter tx_to_hash(query) [String] Transaction to hash
  # @parameter tx_to_ens_domain_name(query) [String] Transaction to ENS domain name
  # @parameter tx_to_is_contract(query) [Boolean] Transaction to is contract
  # @parameter tx_to_is_scam(query) [Boolean] Transaction to is scam
  # @parameter tx_to_is_verified(query) [Boolean] Transaction to is verified
  # @parameter tx_to_name(query) [String] Transaction to name
  # @parameter tx_to_proxy_type(query) [String] Transaction to proxy type
  # @parameter tx_authorization_list(query) [String] Transaction authorization list
  # @parameter tx_method(query) [String] Transaction method
  # @parameter tx_fee_type(query) [String] Transaction fee type
  # @parameter tx_fee_value_min(query) [String] Minimum transaction fee value
  # @parameter tx_fee_value_max(query) [String] Maximum transaction fee value
  # @parameter tx_gas_limit_min(query) [String] Minimum transaction gas limit
  # @parameter tx_gas_limit_max(query) [String] Maximum transaction gas limit
  # @parameter tx_gas_price_min(query) [String] Minimum transaction gas price
  # @parameter tx_gas_price_max(query) [String] Maximum transaction gas price
  # @parameter tx_decoded_input(query) [String] Transaction decoded input
  # @parameter tx_token_transfers(query) [String] Transaction token transfers
  # @parameter tx_base_fee_per_gas_min(query) [String] Minimum transaction base fee per gas
  # @parameter tx_base_fee_per_gas_max(query) [String] Maximum transaction base fee per gas
  # @parameter tx_timestamp_min(query) [String] Minimum transaction timestamp
  # @parameter tx_timestamp_max(query) [String] Maximum transaction timestamp
  # @parameter tx_nonce_min(query) [Integer] Minimum transaction nonce
  # @parameter tx_nonce_max(query) [Integer] Maximum transaction nonce
  # @parameter tx_historic_exchange_rate_min(query) [String] Minimum historic exchange rate
  # @parameter tx_historic_exchange_rate_max(query) [String] Maximum historic exchange rate
  # @parameter tx_transaction_types(query) [String] Transaction types
  # @parameter tx_exchange_rate_min(query) [String] Minimum exchange rate
  # @parameter tx_exchange_rate_max(query) [String] Maximum exchange rate
  # @parameter tx_block_number_min(query) [Integer] Minimum transaction block number
  # @parameter tx_block_number_max(query) [Integer] Maximum transaction block number
  # @parameter tx_has_error_in_internal_transactions(query) [Boolean] Transaction has error in internal transactions
  # @parameter withdrawal_amount_min(query) [String] Minimum withdrawal amount
  # @parameter withdrawal_amount_max(query) [String] Maximum withdrawal amount
  # @parameter withdrawal_index_min(query) [Integer] Minimum withdrawal index
  # @parameter withdrawal_index_max(query) [Integer] Maximum withdrawal index
  # @parameter withdrawal_receiver_hash(query) [String] Withdrawal receiver hash
  # @parameter withdrawal_receiver_ens_domain_name(query) [String] Withdrawal receiver ENS domain name
  # @parameter withdrawal_receiver_is_contract(query) [Boolean] Withdrawal receiver is contract
  # @parameter withdrawal_receiver_is_scam(query) [Boolean] Withdrawal receiver is scam
  # @parameter withdrawal_receiver_is_verified(query) [Boolean] Withdrawal receiver is verified
  # @parameter withdrawal_receiver_name(query) [String] Withdrawal receiver name
  # @parameter withdrawal_receiver_proxy_type(query) [String] Withdrawal receiver proxy type
  # @parameter withdrawal_validator_index_min(query) [Integer] Minimum withdrawal validator index
  # @parameter withdrawal_validator_index_max(query) [Integer] Maximum withdrawal validator index
  # @parameter withdrawal_metadata_tags_name(query) [String] Withdrawal metadata tags name
  # @parameter withdrawal_metadata_tags_slug(query) [String] Withdrawal metadata tags slug
  # @parameter withdrawal_metadata_tags_tag_type(query) [String] Withdrawal metadata tags tag type
  # @parameter withdrawal_metadata_tags_ordinal_min(query) [Integer] Minimum withdrawal metadata tags ordinal
  # @parameter withdrawal_metadata_tags_ordinal_max(query) [Integer] Maximum withdrawal metadata tags ordinal
  # @parameter limit(query) [Integer] Number of results to return (default: 10, max: 50)
  # @parameter offset(query) [Integer] Number of results to skip for pagination (default: 0)
  # @parameter page(query) [Integer] Page number (alternative to offset, starts at 1)
  # @parameter sort_by(query) [String] Field to sort by (default: "id")
  # @parameter sort_order(query) [String] Sort direction: "asc" or "desc" (default: "desc")
  # @response success(200) [Hash{results: Array<Hash{id: Integer, block_number: Integer, data: Hash}>, pagination: Hash{total: Integer, limit: Integer, offset: Integer, page: Integer, total_pages: Integer}}]
  # This endpoint provides 120+ parameters to search for blocks based on the provided input.
  def json_search
    blocks = EthereumBlock.where(nil)
    
    # Block info fields - Numeric with min/max
    blocks = blocks.where("CAST(data->'info'->>'base_fee_per_gas' AS NUMERIC) >= ?", params[:base_fee_per_gas_min]) if params[:base_fee_per_gas_min].present?
    blocks = blocks.where("CAST(data->'info'->>'base_fee_per_gas' AS NUMERIC) <= ?", params[:base_fee_per_gas_max]) if params[:base_fee_per_gas_max].present?
    blocks = blocks.where("CAST(data->'info'->>'blob_gas_price' AS NUMERIC) >= ?", params[:blob_gas_price_min]) if params[:blob_gas_price_min].present?
    blocks = blocks.where("CAST(data->'info'->>'blob_gas_price' AS NUMERIC) <= ?", params[:blob_gas_price_max]) if params[:blob_gas_price_max].present?
    blocks = blocks.where("CAST(data->'info'->>'blob_gas_used' AS NUMERIC) >= ?", params[:blob_gas_used_min]) if params[:blob_gas_used_min].present?
    blocks = blocks.where("CAST(data->'info'->>'blob_gas_used' AS NUMERIC) <= ?", params[:blob_gas_used_max]) if params[:blob_gas_used_max].present?
    blocks = blocks.where("CAST(data->'info'->>'blob_transaction_count' AS INTEGER) >= ?", params[:blob_transaction_count_min].to_i) if params[:blob_transaction_count_min].present?
    blocks = blocks.where("CAST(data->'info'->>'blob_transaction_count' AS INTEGER) <= ?", params[:blob_transaction_count_max].to_i) if params[:blob_transaction_count_max].present?
    blocks = blocks.where("CAST(data->'info'->>'blob_transactions_count' AS INTEGER) >= ?", params[:blob_transactions_count_min].to_i) if params[:blob_transactions_count_min].present?
    blocks = blocks.where("CAST(data->'info'->>'blob_transactions_count' AS INTEGER) <= ?", params[:blob_transactions_count_max].to_i) if params[:blob_transactions_count_max].present?
    blocks = blocks.where("CAST(data->'info'->>'burnt_blob_fees' AS NUMERIC) >= ?", params[:burnt_blob_fees_min]) if params[:burnt_blob_fees_min].present?
    blocks = blocks.where("CAST(data->'info'->>'burnt_blob_fees' AS NUMERIC) <= ?", params[:burnt_blob_fees_max]) if params[:burnt_blob_fees_max].present?
    blocks = blocks.where("CAST(data->'info'->>'burnt_fees' AS NUMERIC) >= ?", params[:burnt_fees_min]) if params[:burnt_fees_min].present?
    blocks = blocks.where("CAST(data->'info'->>'burnt_fees' AS NUMERIC) <= ?", params[:burnt_fees_max]) if params[:burnt_fees_max].present?
    blocks = blocks.where("CAST(data->'info'->>'burnt_fees_percentage' AS DECIMAL) >= ?", params[:burnt_fees_percentage_min].to_f) if params[:burnt_fees_percentage_min].present?
    blocks = blocks.where("CAST(data->'info'->>'burnt_fees_percentage' AS DECIMAL) <= ?", params[:burnt_fees_percentage_max].to_f) if params[:burnt_fees_percentage_max].present?
    blocks = blocks.where("CAST(data->'info'->>'difficulty' AS NUMERIC) >= ?", params[:difficulty_min]) if params[:difficulty_min].present?
    blocks = blocks.where("CAST(data->'info'->>'difficulty' AS NUMERIC) <= ?", params[:difficulty_max]) if params[:difficulty_max].present?
    blocks = blocks.where("CAST(data->'info'->>'excess_blob_gas' AS NUMERIC) >= ?", params[:excess_blob_gas_min]) if params[:excess_blob_gas_min].present?
    blocks = blocks.where("CAST(data->'info'->>'excess_blob_gas' AS NUMERIC) <= ?", params[:excess_blob_gas_max]) if params[:excess_blob_gas_max].present?
    blocks = blocks.where("CAST(data->'info'->>'gas_limit' AS NUMERIC) >= ?", params[:gas_limit_min]) if params[:gas_limit_min].present?
    blocks = blocks.where("CAST(data->'info'->>'gas_limit' AS NUMERIC) <= ?", params[:gas_limit_max]) if params[:gas_limit_max].present?
    blocks = blocks.where("CAST(data->'info'->>'gas_target_percentage' AS DECIMAL) >= ?", params[:gas_target_percentage_min].to_f) if params[:gas_target_percentage_min].present?
    blocks = blocks.where("CAST(data->'info'->>'gas_target_percentage' AS DECIMAL) <= ?", params[:gas_target_percentage_max].to_f) if params[:gas_target_percentage_max].present?
    blocks = blocks.where("CAST(data->'info'->>'gas_used' AS NUMERIC) >= ?", params[:gas_used_min]) if params[:gas_used_min].present?
    blocks = blocks.where("CAST(data->'info'->>'gas_used' AS NUMERIC) <= ?", params[:gas_used_max]) if params[:gas_used_max].present?
    blocks = blocks.where("CAST(data->'info'->>'gas_used_percentage' AS DECIMAL) >= ?", params[:gas_used_percentage_min].to_f) if params[:gas_used_percentage_min].present?
    blocks = blocks.where("CAST(data->'info'->>'gas_used_percentage' AS DECIMAL) <= ?", params[:gas_used_percentage_max].to_f) if params[:gas_used_percentage_max].present?
    blocks = blocks.where("CAST(data->'info'->>'height' AS INTEGER) >= ?", params[:height_min].to_i) if params[:height_min].present?
    blocks = blocks.where("CAST(data->'info'->>'height' AS INTEGER) <= ?", params[:height_max].to_i) if params[:height_max].present?
    blocks = blocks.where("CAST(data->'info'->>'internal_transactions_count' AS INTEGER) >= ?", params[:internal_transactions_count_min].to_i) if params[:internal_transactions_count_min].present?
    blocks = blocks.where("CAST(data->'info'->>'internal_transactions_count' AS INTEGER) <= ?", params[:internal_transactions_count_max].to_i) if params[:internal_transactions_count_max].present?
    blocks = blocks.where("CAST(data->'info'->>'priority_fee' AS NUMERIC) >= ?", params[:priority_fee_min]) if params[:priority_fee_min].present?
    blocks = blocks.where("CAST(data->'info'->>'priority_fee' AS NUMERIC) <= ?", params[:priority_fee_max]) if params[:priority_fee_max].present?
    blocks = blocks.where("CAST(data->'info'->>'size' AS INTEGER) >= ?", params[:size_min].to_i) if params[:size_min].present?
    blocks = blocks.where("CAST(data->'info'->>'size' AS INTEGER) <= ?", params[:size_max].to_i) if params[:size_max].present?
    blocks = blocks.where("CAST(data->'info'->>'total_difficulty' AS NUMERIC) >= ?", params[:total_difficulty_min]) if params[:total_difficulty_min].present?
    blocks = blocks.where("CAST(data->'info'->>'total_difficulty' AS NUMERIC) <= ?", params[:total_difficulty_max]) if params[:total_difficulty_max].present?
    blocks = blocks.where("CAST(data->'info'->>'transaction_count' AS INTEGER) >= ?", params[:transaction_count_min].to_i) if params[:transaction_count_min].present?
    blocks = blocks.where("CAST(data->'info'->>'transaction_count' AS INTEGER) <= ?", params[:transaction_count_max].to_i) if params[:transaction_count_max].present?
    blocks = blocks.where("CAST(data->'info'->>'transaction_fees' AS NUMERIC) >= ?", params[:transaction_fees_min]) if params[:transaction_fees_min].present?
    blocks = blocks.where("CAST(data->'info'->>'transaction_fees' AS NUMERIC) <= ?", params[:transaction_fees_max]) if params[:transaction_fees_max].present?
    blocks = blocks.where("CAST(data->'info'->>'transactions_count' AS INTEGER) >= ?", params[:transactions_count_min].to_i) if params[:transactions_count_min].present?
    blocks = blocks.where("CAST(data->'info'->>'transactions_count' AS INTEGER) <= ?", params[:transactions_count_max].to_i) if params[:transactions_count_max].present?
    blocks = blocks.where("CAST(data->'info'->>'withdrawals_count' AS INTEGER) >= ?", params[:withdrawals_count_min].to_i) if params[:withdrawals_count_min].present?
    blocks = blocks.where("CAST(data->'info'->>'withdrawals_count' AS INTEGER) <= ?", params[:withdrawals_count_max].to_i) if params[:withdrawals_count_max].present?
    
    # Block info fields - String
    blocks = blocks.where("data->'info'->>'hash' = ?", params[:hash]) if params[:hash].present?
    blocks = blocks.where("data->'info'->>'nonce' = ?", params[:nonce]) if params[:nonce].present?
    blocks = blocks.where("data->'info'->>'parent_hash' = ?", params[:parent_hash]) if params[:parent_hash].present?
    blocks = blocks.where("data->'info'->>'type' = ?", params[:block_type]) if params[:block_type].present?
    blocks = blocks.where("data->'info'->>'timestamp' >= ?", params[:timestamp_min]) if params[:timestamp_min].present?
    blocks = blocks.where("data->'info'->>'timestamp' <= ?", params[:timestamp_max]) if params[:timestamp_max].present?
    
    # Miner fields
    blocks = blocks.where("data->'info'->'miner'->>'hash' = ?", params[:miner_hash]) if params[:miner_hash].present?
    blocks = blocks.where("data->'info'->'miner'->>'ens_domain_name' = ?", params[:miner_ens_domain_name]) if params[:miner_ens_domain_name].present?
    blocks = blocks.where("data->'info'->'miner'->>'is_contract' = ?", params[:miner_is_contract].to_s) if params[:miner_is_contract].present?
    blocks = blocks.where("data->'info'->'miner'->>'is_scam' = ?", params[:miner_is_scam].to_s) if params[:miner_is_scam].present?
    blocks = blocks.where("data->'info'->'miner'->>'is_verified' = ?", params[:miner_is_verified].to_s) if params[:miner_is_verified].present?
    blocks = blocks.where("data->'info'->'miner'->>'name' = ?", params[:miner_name]) if params[:miner_name].present?
    blocks = blocks.where("data->'info'->'miner'->>'proxy_type' = ?", params[:miner_proxy_type]) if params[:miner_proxy_type].present?
    
    # Rewards fields
    blocks = blocks.where("data->'info'->'rewards' @> ?", [{ type: params[:reward_type] }].to_json) if params[:reward_type].present?
    blocks = blocks.where("CAST(data->'info'->'rewards'->0->>'reward' AS NUMERIC) >= ?", params[:reward_value_min]) if params[:reward_value_min].present?
    blocks = blocks.where("CAST(data->'info'->'rewards'->0->>'reward' AS NUMERIC) <= ?", params[:reward_value_max]) if params[:reward_value_max].present?
    
    # Transaction fields (nested in transactions->items array)
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ hash: params[:tx_hash] }].to_json) if params[:tx_hash].present?
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ priority_fee: params[:tx_priority_fee_min] }].to_json) if params[:tx_priority_fee_min].present?
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ raw_input: params[:tx_raw_input] }].to_json) if params[:tx_raw_input].present?
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ result: params[:tx_result] }].to_json) if params[:tx_result].present?
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ revert_reason: params[:tx_revert_reason] }].to_json) if params[:tx_revert_reason].present?
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ token_transfers_overflow: params[:tx_token_transfers_overflow] }].to_json) if params[:tx_token_transfers_overflow].present?
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ transaction_tag: params[:tx_transaction_tag] }].to_json) if params[:tx_transaction_tag].present?
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ created_contract: params[:tx_created_contract] }].to_json) if params[:tx_created_contract].present?
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ status: params[:tx_status] }].to_json) if params[:tx_status].present?
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ method: params[:tx_method] }].to_json) if params[:tx_method].present?
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ decoded_input: params[:tx_decoded_input] }].to_json) if params[:tx_decoded_input].present?
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ token_transfers: params[:tx_token_transfers] }].to_json) if params[:tx_token_transfers].present?
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ timestamp: params[:tx_timestamp_min] }].to_json) if params[:tx_timestamp_min].present?
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ timestamp: params[:tx_timestamp_max] }].to_json) if params[:tx_timestamp_max].present?
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ has_error_in_internal_transactions: params[:tx_has_error_in_internal_transactions] }].to_json) if params[:tx_has_error_in_internal_transactions].present?
    
    # Transaction from/to address fields
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ from: { hash: params[:tx_from_hash] } }].to_json) if params[:tx_from_hash].present?
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ from: { ens_domain_name: params[:tx_from_ens_domain_name] } }].to_json) if params[:tx_from_ens_domain_name].present?
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ from: { is_contract: params[:tx_from_is_contract] } }].to_json) if params[:tx_from_is_contract].present?
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ from: { is_scam: params[:tx_from_is_scam] } }].to_json) if params[:tx_from_is_scam].present?
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ from: { is_verified: params[:tx_from_is_verified] } }].to_json) if params[:tx_from_is_verified].present?
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ from: { name: params[:tx_from_name] } }].to_json) if params[:tx_from_name].present?
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ from: { proxy_type: params[:tx_from_proxy_type] } }].to_json) if params[:tx_from_proxy_type].present?
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ to: { hash: params[:tx_to_hash] } }].to_json) if params[:tx_to_hash].present?
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ to: { ens_domain_name: params[:tx_to_ens_domain_name] } }].to_json) if params[:tx_to_ens_domain_name].present?
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ to: { is_contract: params[:tx_to_is_contract] } }].to_json) if params[:tx_to_is_contract].present?
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ to: { is_scam: params[:tx_to_is_scam] } }].to_json) if params[:tx_to_is_scam].present?
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ to: { is_verified: params[:tx_to_is_verified] } }].to_json) if params[:tx_to_is_verified].present?
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ to: { name: params[:tx_to_name] } }].to_json) if params[:tx_to_name].present?
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ to: { proxy_type: params[:tx_to_proxy_type] } }].to_json) if params[:tx_to_proxy_type].present?
    
    # Transaction fee fields
    blocks = blocks.where("data->'transactions'->'items' @> ?", [{ fee: { type: params[:tx_fee_type] } }].to_json) if params[:tx_fee_type].present?
    
    # Transaction numeric fields with min/max
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'max_fee_per_gas' AS NUMERIC) >= ?", params[:tx_max_fee_per_gas_min]) if params[:tx_max_fee_per_gas_min].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'max_fee_per_gas' AS NUMERIC) <= ?", params[:tx_max_fee_per_gas_max]) if params[:tx_max_fee_per_gas_max].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'transaction_burnt_fee' AS NUMERIC) >= ?", params[:tx_transaction_burnt_fee_min]) if params[:tx_transaction_burnt_fee_min].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'transaction_burnt_fee' AS NUMERIC) <= ?", params[:tx_transaction_burnt_fee_max]) if params[:tx_transaction_burnt_fee_max].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'type' AS INTEGER) >= ?", params[:tx_type_min].to_i) if params[:tx_type_min].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'type' AS INTEGER) <= ?", params[:tx_type_max].to_i) if params[:tx_type_max].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'confirmations' AS INTEGER) >= ?", params[:tx_confirmations_min].to_i) if params[:tx_confirmations_min].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'confirmations' AS INTEGER) <= ?", params[:tx_confirmations_max].to_i) if params[:tx_confirmations_max].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'position' AS INTEGER) >= ?", params[:tx_position_min].to_i) if params[:tx_position_min].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'position' AS INTEGER) <= ?", params[:tx_position_max].to_i) if params[:tx_position_max].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'max_priority_fee_per_gas' AS NUMERIC) >= ?", params[:tx_max_priority_fee_per_gas_min]) if params[:tx_max_priority_fee_per_gas_min].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'max_priority_fee_per_gas' AS NUMERIC) <= ?", params[:tx_max_priority_fee_per_gas_max]) if params[:tx_max_priority_fee_per_gas_max].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'value' AS NUMERIC) >= ?", params[:tx_value_min]) if params[:tx_value_min].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'value' AS NUMERIC) <= ?", params[:tx_value_max]) if params[:tx_value_max].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'gas_used' AS NUMERIC) >= ?", params[:tx_gas_used_min]) if params[:tx_gas_used_min].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'gas_used' AS NUMERIC) <= ?", params[:tx_gas_used_max]) if params[:tx_gas_used_max].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'gas_limit' AS NUMERIC) >= ?", params[:tx_gas_limit_min]) if params[:tx_gas_limit_min].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'gas_limit' AS NUMERIC) <= ?", params[:tx_gas_limit_max]) if params[:tx_gas_limit_max].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'gas_price' AS NUMERIC) >= ?", params[:tx_gas_price_min]) if params[:tx_gas_price_min].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'gas_price' AS NUMERIC) <= ?", params[:tx_gas_price_max]) if params[:tx_gas_price_max].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'base_fee_per_gas' AS NUMERIC) >= ?", params[:tx_base_fee_per_gas_min]) if params[:tx_base_fee_per_gas_min].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'base_fee_per_gas' AS NUMERIC) <= ?", params[:tx_base_fee_per_gas_max]) if params[:tx_base_fee_per_gas_max].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'nonce' AS INTEGER) >= ?", params[:tx_nonce_min].to_i) if params[:tx_nonce_min].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'nonce' AS INTEGER) <= ?", params[:tx_nonce_max].to_i) if params[:tx_nonce_max].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'historic_exchange_rate' AS DECIMAL) >= ?", params[:tx_historic_exchange_rate_min].to_f) if params[:tx_historic_exchange_rate_min].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'historic_exchange_rate' AS DECIMAL) <= ?", params[:tx_historic_exchange_rate_max].to_f) if params[:tx_historic_exchange_rate_max].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'exchange_rate' AS DECIMAL) >= ?", params[:tx_exchange_rate_min].to_f) if params[:tx_exchange_rate_min].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'exchange_rate' AS DECIMAL) <= ?", params[:tx_exchange_rate_max].to_f) if params[:tx_exchange_rate_max].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'block_number' AS INTEGER) >= ?", params[:tx_block_number_min].to_i) if params[:tx_block_number_min].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->>'block_number' AS INTEGER) <= ?", params[:tx_block_number_max].to_i) if params[:tx_block_number_max].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->'fee'->>'value' AS NUMERIC) >= ?", params[:tx_fee_value_min]) if params[:tx_fee_value_min].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->'fee'->>'value' AS NUMERIC) <= ?", params[:tx_fee_value_max]) if params[:tx_fee_value_max].present?
    
    # Confirmation duration fields (array with min/max values)
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->'confirmation_duration'->0 AS INTEGER) >= ?", params[:tx_confirmation_duration_min].to_i) if params[:tx_confirmation_duration_min].present?
    blocks = blocks.where("CAST(data->'transactions'->'items'->0->'confirmation_duration'->1 AS INTEGER) <= ?", params[:tx_confirmation_duration_max].to_i) if params[:tx_confirmation_duration_max].present?
    
    # Transaction types array
    blocks = blocks.where("data->'transactions'->'items'->0->'transaction_types' @> ?", [params[:tx_transaction_types]].to_json) if params[:tx_transaction_types].present?
    
    # Withdrawal fields (nested in withdrawals->items array)
    blocks = blocks.where("CAST(data->'withdrawals'->'items'->0->>'amount' AS NUMERIC) >= ?", params[:withdrawal_amount_min]) if params[:withdrawal_amount_min].present?
    blocks = blocks.where("CAST(data->'withdrawals'->'items'->0->>'amount' AS NUMERIC) <= ?", params[:withdrawal_amount_max]) if params[:withdrawal_amount_max].present?
    blocks = blocks.where("CAST(data->'withdrawals'->'items'->0->>'index' AS INTEGER) >= ?", params[:withdrawal_index_min].to_i) if params[:withdrawal_index_min].present?
    blocks = blocks.where("CAST(data->'withdrawals'->'items'->0->>'index' AS INTEGER) <= ?", params[:withdrawal_index_max].to_i) if params[:withdrawal_index_max].present?
    blocks = blocks.where("data->'withdrawals'->'items' @> ?", [{ receiver: { hash: params[:withdrawal_receiver_hash] } }].to_json) if params[:withdrawal_receiver_hash].present?
    blocks = blocks.where("data->'withdrawals'->'items' @> ?", [{ receiver: { ens_domain_name: params[:withdrawal_receiver_ens_domain_name] } }].to_json) if params[:withdrawal_receiver_ens_domain_name].present?
    blocks = blocks.where("data->'withdrawals'->'items' @> ?", [{ receiver: { is_contract: params[:withdrawal_receiver_is_contract] } }].to_json) if params[:withdrawal_receiver_is_contract].present?
    blocks = blocks.where("data->'withdrawals'->'items' @> ?", [{ receiver: { is_scam: params[:withdrawal_receiver_is_scam] } }].to_json) if params[:withdrawal_receiver_is_scam].present?
    blocks = blocks.where("data->'withdrawals'->'items' @> ?", [{ receiver: { is_verified: params[:withdrawal_receiver_is_verified] } }].to_json) if params[:withdrawal_receiver_is_verified].present?
    blocks = blocks.where("data->'withdrawals'->'items' @> ?", [{ receiver: { name: params[:withdrawal_receiver_name] } }].to_json) if params[:withdrawal_receiver_name].present?
    blocks = blocks.where("data->'withdrawals'->'items' @> ?", [{ receiver: { proxy_type: params[:withdrawal_receiver_proxy_type] } }].to_json) if params[:withdrawal_receiver_proxy_type].present?
    blocks = blocks.where("CAST(data->'withdrawals'->'items'->0->>'validator_index' AS INTEGER) >= ?", params[:withdrawal_validator_index_min].to_i) if params[:withdrawal_validator_index_min].present?
    blocks = blocks.where("CAST(data->'withdrawals'->'items'->0->>'validator_index' AS INTEGER) <= ?", params[:withdrawal_validator_index_max].to_i) if params[:withdrawal_validator_index_max].present?
    
    # Withdrawal metadata tags fields
    blocks = blocks.where("data->'withdrawals'->'items' @> ?", [{ receiver: { metadata: { tags: [{ name: params[:withdrawal_metadata_tags_name] }] } } }].to_json) if params[:withdrawal_metadata_tags_name].present?
    blocks = blocks.where("data->'withdrawals'->'items' @> ?", [{ receiver: { metadata: { tags: [{ slug: params[:withdrawal_metadata_tags_slug] }] } } }].to_json) if params[:withdrawal_metadata_tags_slug].present?
    blocks = blocks.where("data->'withdrawals'->'items' @> ?", [{ receiver: { metadata: { tags: [{ tagType: params[:withdrawal_metadata_tags_tag_type] }] } } }].to_json) if params[:withdrawal_metadata_tags_tag_type].present?
    blocks = blocks.where("CAST(data->'withdrawals'->'items'->0->'receiver'->'metadata'->'tags'->0->>'ordinal' AS INTEGER) >= ?", params[:withdrawal_metadata_tags_ordinal_min].to_i) if params[:withdrawal_metadata_tags_ordinal_min].present?
    blocks = blocks.where("CAST(data->'withdrawals'->'items'->0->'receiver'->'metadata'->'tags'->0->>'ordinal' AS INTEGER) <= ?", params[:withdrawal_metadata_tags_ordinal_max].to_i) if params[:withdrawal_metadata_tags_ordinal_max].present?
    
    # Apply sorting
    sort_by = params[:sort_by] || 'id'
    sort_order = params[:sort_order]&.downcase == 'asc' ? 'asc' : 'desc'
    
    allowed_sort_fields = {
      # Basic fields
      'id' => 'ethereum_blocks.id',
      'created_at' => 'ethereum_blocks.created_at',
      'updated_at' => 'ethereum_blocks.updated_at',
      'block_number' => 'ethereum_blocks.block_number',
      
      # Block info fields
      'base_fee_per_gas' => "CAST(data->'info'->>'base_fee_per_gas' AS NUMERIC)",
      'blob_gas_price' => "CAST(data->'info'->>'blob_gas_price' AS NUMERIC)",
      'blob_gas_used' => "CAST(data->'info'->>'blob_gas_used' AS NUMERIC)",
      'blob_transaction_count' => "CAST(data->'info'->>'blob_transaction_count' AS INTEGER)",
      'blob_transactions_count' => "CAST(data->'info'->>'blob_transactions_count' AS INTEGER)",
      'burnt_blob_fees' => "CAST(data->'info'->>'burnt_blob_fees' AS NUMERIC)",
      'burnt_fees' => "CAST(data->'info'->>'burnt_fees' AS NUMERIC)",
      'burnt_fees_percentage' => "CAST(data->'info'->>'burnt_fees_percentage' AS DECIMAL)",
      'difficulty' => "CAST(data->'info'->>'difficulty' AS NUMERIC)",
      'excess_blob_gas' => "CAST(data->'info'->>'excess_blob_gas' AS NUMERIC)",
      'gas_limit' => "CAST(data->'info'->>'gas_limit' AS NUMERIC)",
      'gas_target_percentage' => "CAST(data->'info'->>'gas_target_percentage' AS DECIMAL)",
      'gas_used' => "CAST(data->'info'->>'gas_used' AS NUMERIC)",
      'gas_used_percentage' => "CAST(data->'info'->>'gas_used_percentage' AS DECIMAL)",
      'hash' => "data->'info'->>'hash'",
      'height' => "CAST(data->'info'->>'height' AS INTEGER)",
      'internal_transactions_count' => "CAST(data->'info'->>'internal_transactions_count' AS INTEGER)",
      'nonce' => "data->'info'->>'nonce'",
      'parent_hash' => "data->'info'->>'parent_hash'",
      'priority_fee' => "CAST(data->'info'->>'priority_fee' AS NUMERIC)",
      'size' => "CAST(data->'info'->>'size' AS INTEGER)",
      'timestamp' => "data->'info'->>'timestamp'",
      'total_difficulty' => "CAST(data->'info'->>'total_difficulty' AS NUMERIC)",
      'transaction_count' => "CAST(data->'info'->>'transaction_count' AS INTEGER)",
      'transaction_fees' => "CAST(data->'info'->>'transaction_fees' AS NUMERIC)",
      'transactions_count' => "CAST(data->'info'->>'transactions_count' AS INTEGER)",
      'block_type' => "data->'info'->>'type'",
      'withdrawals_count' => "CAST(data->'info'->>'withdrawals_count' AS INTEGER)",
      
      # Miner fields
      'miner_hash' => "data->'info'->'miner'->>'hash'",
      'miner_ens_domain_name' => "data->'info'->'miner'->>'ens_domain_name'",
      'miner_is_contract' => "CASE WHEN data->'info'->'miner'->>'is_contract' = 'true' THEN 1 ELSE 0 END",
      'miner_is_scam' => "CASE WHEN data->'info'->'miner'->>'is_scam' = 'true' THEN 1 ELSE 0 END",
      'miner_is_verified' => "CASE WHEN data->'info'->'miner'->>'is_verified' = 'true' THEN 1 ELSE 0 END",
      'miner_name' => "data->'info'->'miner'->>'name'",
      'miner_proxy_type' => "data->'info'->'miner'->>'proxy_type'",
      
      # Reward fields (using first reward)
      'reward_type' => "data->'info'->'rewards'->0->>'type'",
      'reward_value' => "CAST(data->'info'->'rewards'->0->>'reward' AS NUMERIC)",
      
      # Transaction fields (using first transaction)
      'tx_hash' => "data->'transactions'->'items'->0->>'hash'",
      'tx_priority_fee' => "CAST(data->'transactions'->'items'->0->>'priority_fee' AS NUMERIC)",
      'tx_raw_input' => "data->'transactions'->'items'->0->>'raw_input'",
      'tx_result' => "data->'transactions'->'items'->0->>'result'",
      'tx_max_fee_per_gas' => "CAST(data->'transactions'->'items'->0->>'max_fee_per_gas' AS NUMERIC)",
      'tx_revert_reason' => "data->'transactions'->'items'->0->>'revert_reason'",
      'tx_transaction_burnt_fee' => "CAST(data->'transactions'->'items'->0->>'transaction_burnt_fee' AS NUMERIC)",
      'tx_type' => "CAST(data->'transactions'->'items'->0->>'type' AS INTEGER)",
      'tx_token_transfers_overflow' => "CASE WHEN data->'transactions'->'items'->0->>'token_transfers_overflow' = 'true' THEN 1 ELSE 0 END",
      'tx_confirmations' => "CAST(data->'transactions'->'items'->0->>'confirmations' AS INTEGER)",
      'tx_position' => "CAST(data->'transactions'->'items'->0->>'position' AS INTEGER)",
      'tx_max_priority_fee_per_gas' => "CAST(data->'transactions'->'items'->0->>'max_priority_fee_per_gas' AS NUMERIC)",
      'tx_transaction_tag' => "data->'transactions'->'items'->0->>'transaction_tag'",
      'tx_created_contract' => "data->'transactions'->'items'->0->>'created_contract'",
      'tx_value' => "CAST(data->'transactions'->'items'->0->>'value' AS NUMERIC)",
      'tx_gas_used' => "CAST(data->'transactions'->'items'->0->>'gas_used' AS NUMERIC)",
      'tx_status' => "data->'transactions'->'items'->0->>'status'",
      'tx_method' => "data->'transactions'->'items'->0->>'method'",
      'tx_gas_limit' => "CAST(data->'transactions'->'items'->0->>'gas_limit' AS NUMERIC)",
      'tx_gas_price' => "CAST(data->'transactions'->'items'->0->>'gas_price' AS NUMERIC)",
      'tx_decoded_input' => "data->'transactions'->'items'->0->>'decoded_input'",
      'tx_token_transfers' => "data->'transactions'->'items'->0->>'token_transfers'",
      'tx_base_fee_per_gas' => "CAST(data->'transactions'->'items'->0->>'base_fee_per_gas' AS NUMERIC)",
      'tx_timestamp' => "data->'transactions'->'items'->0->>'timestamp'",
      'tx_nonce' => "CAST(data->'transactions'->'items'->0->>'nonce' AS INTEGER)",
      'tx_historic_exchange_rate' => "CAST(data->'transactions'->'items'->0->>'historic_exchange_rate' AS DECIMAL)",
      'tx_exchange_rate' => "CAST(data->'transactions'->'items'->0->>'exchange_rate' AS DECIMAL)",
      'tx_block_number' => "CAST(data->'transactions'->'items'->0->>'block_number' AS INTEGER)",
      'tx_has_error_in_internal_transactions' => "CASE WHEN data->'transactions'->'items'->0->>'has_error_in_internal_transactions' = 'true' THEN 1 ELSE 0 END",
      'tx_fee_type' => "data->'transactions'->'items'->0->'fee'->>'type'",
      'tx_fee_value' => "CAST(data->'transactions'->'items'->0->'fee'->>'value' AS NUMERIC)",
      
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
      
      # Withdrawal fields (using first withdrawal)
      'withdrawal_amount' => "CAST(data->'withdrawals'->'items'->0->>'amount' AS NUMERIC)",
      'withdrawal_index' => "CAST(data->'withdrawals'->'items'->0->>'index' AS INTEGER)",
      'withdrawal_receiver_hash' => "data->'withdrawals'->'items'->0->'receiver'->>'hash'",
      'withdrawal_receiver_ens_domain_name' => "data->'withdrawals'->'items'->0->'receiver'->>'ens_domain_name'",
      'withdrawal_receiver_is_contract' => "CASE WHEN data->'withdrawals'->'items'->0->'receiver'->>'is_contract' = 'true' THEN 1 ELSE 0 END",
      'withdrawal_receiver_is_scam' => "CASE WHEN data->'withdrawals'->'items'->0->'receiver'->>'is_scam' = 'true' THEN 1 ELSE 0 END",
      'withdrawal_receiver_is_verified' => "CASE WHEN data->'withdrawals'->'items'->0->'receiver'->>'is_verified' = 'true' THEN 1 ELSE 0 END",
      'withdrawal_receiver_name' => "data->'withdrawals'->'items'->0->'receiver'->>'name'",
      'withdrawal_receiver_proxy_type' => "data->'withdrawals'->'items'->0->'receiver'->>'proxy_type'",
      'withdrawal_validator_index' => "CAST(data->'withdrawals'->'items'->0->>'validator_index' AS INTEGER)",
      
      # Withdrawal metadata tags fields
      'withdrawal_metadata_tags_name' => "data->'withdrawals'->'items'->0->'receiver'->'metadata'->'tags'->0->>'name'",
      'withdrawal_metadata_tags_slug' => "data->'withdrawals'->'items'->0->'receiver'->'metadata'->'tags'->0->>'slug'",
      'withdrawal_metadata_tags_tag_type' => "data->'withdrawals'->'items'->0->'receiver'->'metadata'->'tags'->0->>'tagType'",
      'withdrawal_metadata_tags_ordinal' => "CAST(data->'withdrawals'->'items'->0->'receiver'->'metadata'->'tags'->0->>'ordinal' AS INTEGER)"
    }
    
    if allowed_sort_fields.key?(sort_by)
      sort_column = allowed_sort_fields[sort_by]
      # Add NULLS LAST for JSON-based fields to ensure blocks with data come first
      if sort_column.include?("data->")
        blocks = blocks.order(Arel.sql("#{sort_column} #{sort_order} NULLS LAST"))
      else
        blocks = blocks.order(Arel.sql("#{sort_column} #{sort_order}"))
      end
    else
      # Default fallback
      blocks = blocks.order(Arel.sql("ethereum_blocks.id DESC"))
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
    total_count = blocks.count
    
    # Apply pagination
    paginated_blocks = blocks.limit(limit).offset(offset)
    
    # Calculate pagination metadata
    current_page = (offset / limit) + 1
    total_pages = (total_count.to_f / limit).ceil
    
    render json: {
      results: paginated_blocks.pluck(:block_number),
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

  def get_block_info(block)
    blockscout_api_get("/blocks/#{block}")
  end

  def get_block_transactions(block)
    all_transactions = []
    next_page_params = nil
    page_number = 1
    
    Sync do
      loop do
        Rails.logger.info "Fetching transactions page #{page_number} for block #{block}..."
        
        # Build the API path with pagination parameters
        api_path = if next_page_params
          query_params = "block_number=#{next_page_params['block_number']}&index=#{next_page_params['index']}&items_count=#{next_page_params['items_count']}"
          "/blocks/#{block}/transactions?#{query_params}"
        else
          "/blocks/#{block}/transactions"
        end
        
        # Fetch page data asynchronously
        page_data = Async { blockscout_api_get(api_path) }.wait
        
        # Break if no data or no transactions
        break unless page_data && page_data['items']
        
        page_transactions = page_data['items']
        all_transactions.concat(page_transactions)
        
        Rails.logger.info "Fetched #{page_transactions.count} transactions from page #{page_number}. Total so far: #{all_transactions.count}"
        
        # Check if there are more pages
        if page_data['next_page_params']
          next_page_params = page_data['next_page_params']
          page_number += 1
        else
          Rails.logger.info "No more pages. Finished fetching all #{all_transactions.count} transactions for block #{block}"
          break
        end
      end
    end
    
    # Return the data in the same format as the original API response
    {
      'items' => all_transactions,
      'next_page_params' => nil # No pagination needed since we fetched everything
    }
  end

  def get_block_withdrawals(block)
    blockscout_api_get("/blocks/#{block}/withdrawals")
  end

end


