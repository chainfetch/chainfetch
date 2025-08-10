class Api::V1::Ethereum::TransactionsController < Api::V1::Ethereum::BaseController
  # @summary Get transaction info 
  # @parameter transaction(path) [!String] The transaction hash to get info for
  # @response success(200) [Hash{info: Hash, token_transfers: Hash, internal_transactions: Hash, logs: Hash, raw_trace: Hash, state_changes: Hash, summary: Hash}]
  def show
    transaction = params[:transaction]
    Sync do
      tasks = {
        info: Async { get_transaction_info(transaction) },
        token_transfers: Async { get_transaction_token_transfers(transaction) },
        internal_transactions: Async { get_transaction_internal_transactions(transaction) },
        logs: Async { get_transaction_logs(transaction) },
        raw_trace: Async { get_transaction_raw_trace(transaction) },
        state_changes: Async { get_transaction_state_changes(transaction) },
        summary: Async { get_transaction_summary(transaction) },
      }

      render json: tasks.transform_values(&:wait)
    end
  end

  # @summary Semantic Search for transactions
  # @parameter query(query) [!String] The query to search for
  # @parameter limit(query) [!Integer] The number of results to return (default: 10)
  # @response success(200) [Hash{result: Hash{points: Array<Hash{id: Integer, version: Integer, score: Float, payload: Hash{transaction_summary: String}}}>}}]
  # This endpoint queries Qdrant to search transactions based on the provided input. Transaction summaries are embedded using dengcao/Qwen3-Embedding-0.6B:Q8_0 and stored in Qdrant's 'transactions' collection.
  def semantic_search
    query = params[:query]
    limit = params[:limit] || 10
    embedding = EmbeddingService.new(query).call
    qdrant_objects = QdrantService.new.query_points(collection: "transactions", query: embedding, limit: limit)
    render json: qdrant_objects
  end

  # @summary Transaction Summary
  # @parameter transaction_hash(query) [!String] The transaction hash to search for
  # @response success(200) [Hash{summary: String}]
  def transaction_summary
    transaction_hash = params[:transaction_hash]
    transaction_data = Ethereum::TransactionDataService.new(transaction_hash).call
    summary = Ethereum::TransactionSummaryService.new(transaction_data).call
    render json: { summary: summary }
  end

  # @summary LLM Search for transactions
  # @parameter query(query) [!String] The query to search for
  # @response success(200) [Hash{results: String}]
  # This endpoint leverages LLaMA 3.2 3B model to analyze and select the most suitable parameters from 254 carefully curated options
  def llm_search
    query = params[:query]
    response = TransactionDataSearchServiceCurated.new(query).call
    render json: response
  end

  # @summary JSON Search for transactions
  # @parameter hash(query) [String] Transaction hash
  # @parameter result(query) [String] Transaction result (success, failure)
  # @parameter value_min(query) [String] Minimum transaction value in WEI
  # @parameter value_max(query) [String] Maximum transaction value in WEI
  # @parameter gas_used_min(query) [String] Minimum gas used
  # @parameter gas_used_max(query) [String] Maximum gas used
  # @parameter gas_limit_min(query) [String] Minimum gas limit
  # @parameter gas_limit_max(query) [String] Maximum gas limit
  # @parameter gas_price_min(query) [String] Minimum gas price
  # @parameter gas_price_max(query) [String] Maximum gas price
  # @parameter priority_fee_min(query) [String] Minimum priority fee
  # @parameter priority_fee_max(query) [String] Maximum priority fee
  # @parameter max_fee_per_gas_min(query) [String] Minimum max fee per gas
  # @parameter max_fee_per_gas_max(query) [String] Maximum max fee per gas
  # @parameter max_priority_fee_per_gas_min(query) [String] Minimum max priority fee per gas
  # @parameter max_priority_fee_per_gas_max(query) [String] Maximum max priority fee per gas
  # @parameter base_fee_per_gas_min(query) [String] Minimum base fee per gas
  # @parameter base_fee_per_gas_max(query) [String] Maximum base fee per gas
  # @parameter fee_value_min(query) [String] Minimum fee value
  # @parameter fee_value_max(query) [String] Maximum fee value
  # @parameter fee_type(query) [String] Fee type
  # @parameter transaction_burnt_fee_min(query) [String] Minimum transaction burnt fee
  # @parameter transaction_burnt_fee_max(query) [String] Maximum transaction burnt fee
  # @parameter from_hash(query) [String] From address hash
  # @parameter to_hash(query) [String] To address hash
  # @parameter from_name(query) [String] From address name
  # @parameter to_name(query) [String] To address name
  # @parameter from_is_contract(query) [Boolean] Whether from address is contract
  # @parameter to_is_contract(query) [Boolean] Whether to address is contract
  # @parameter from_is_verified(query) [Boolean] Whether from address is verified
  # @parameter to_is_verified(query) [Boolean] Whether to address is verified
  # @parameter from_is_scam(query) [Boolean] Whether from address is scam
  # @parameter to_is_scam(query) [Boolean] Whether to address is scam
  # @parameter from_ens_domain_name(query) [String] From address ENS domain name
  # @parameter to_ens_domain_name(query) [String] To address ENS domain name
  # @parameter from_proxy_type(query) [String] From address proxy type
  # @parameter to_proxy_type(query) [String] To address proxy type
  # @parameter from_private_tags(query) [String] From address private tags
  # @parameter to_private_tags(query) [String] To address private tags
  # @parameter from_public_tags(query) [String] From address public tags
  # @parameter to_public_tags(query) [String] To address public tags
  # @parameter from_watchlist_names(query) [String] From address watchlist names
  # @parameter to_watchlist_names(query) [String] To address watchlist names
  # @parameter from_metadata_tags_name(query) [String] From address metadata tags name
  # @parameter to_metadata_tags_name(query) [String] To address metadata tags name
  # @parameter from_metadata_tags_slug(query) [String] From address metadata tags slug
  # @parameter to_metadata_tags_slug(query) [String] To address metadata tags slug
  # @parameter from_metadata_tags_tag_type(query) [String] From address metadata tags tag type
  # @parameter to_metadata_tags_tag_type(query) [String] To address metadata tags tag type
  # @parameter from_metadata_tags_ordinal_min(query) [Integer] Minimum from address metadata tags ordinal
  # @parameter from_metadata_tags_ordinal_max(query) [Integer] Maximum from address metadata tags ordinal
  # @parameter block_hash(query) [String] Block hash
  # @parameter block_number_min(query) [Integer] Minimum block number
  # @parameter block_number_max(query) [Integer] Maximum block number
  # @parameter timestamp_min(query) [String] Minimum timestamp
  # @parameter timestamp_max(query) [String] Maximum timestamp
  # @parameter transaction_index_min(query) [Integer] Minimum transaction index
  # @parameter transaction_index_max(query) [Integer] Maximum transaction index
  # @parameter transaction_tag(query) [String] Transaction tag (e.g., 'DeFi Interaction')
  # @parameter type_min(query) [Integer] Minimum transaction type
  # @parameter type_max(query) [Integer] Maximum transaction type
  # @parameter position_min(query) [Integer] Minimum position in block
  # @parameter position_max(query) [Integer] Maximum position in block
  # @parameter revert_reason(query) [String] Transaction revert reason
  # @parameter raw_input(query) [String] Transaction raw input data
  # @parameter created_contract(query) [String] Created contract address
  # @parameter nonce_min(query) [Integer] Minimum nonce
  # @parameter nonce_max(query) [Integer] Maximum nonce
  # @parameter cumulative_gas_used_min(query) [String] Minimum cumulative gas used
  # @parameter cumulative_gas_used_max(query) [String] Maximum cumulative gas used
  # @parameter error(query) [String] Transaction error message
  # @parameter status(query) [String] Transaction status
  # @parameter token_transfers_token_hash(query) [String] Token contract address
  # @parameter token_transfers_token_symbol(query) [String] Token symbol (e.g., USDC, ETH)
  # @parameter token_transfers_token_name(query) [String] Token name
  # @parameter token_transfers_token_type(query) [String] Token type (ERC-20, ERC-721, etc.)
  # @parameter token_transfers_token_decimals_min(query) [Integer] Minimum token decimals
  # @parameter token_transfers_token_decimals_max(query) [Integer] Maximum token decimals
  # @parameter token_transfers_from_hash(query) [String] Token transfer from address
  # @parameter token_transfers_to_hash(query) [String] Token transfer to address
  # @parameter token_transfers_amount_min(query) [String] Minimum token transfer amount
  # @parameter token_transfers_amount_max(query) [String] Maximum token transfer amount
  # @parameter token_transfers_log_index_min(query) [Integer] Minimum token transfer log index
  # @parameter token_transfers_log_index_max(query) [Integer] Maximum token transfer log index
  # @parameter token_transfers_token_id(query) [String] Token ID for NFTs
  # @parameter token_transfers_overflow(query) [Boolean] Whether token transfers overflow
  # @parameter token_transfers_from_ens_domain_name(query) [String] Token transfer from ENS domain name
  # @parameter token_transfers_from_is_contract(query) [Boolean] Token transfer from is contract
  # @parameter token_transfers_from_is_verified(query) [Boolean] Token transfer from is verified
  # @parameter token_transfers_from_is_scam(query) [Boolean] Token transfer from is scam
  # @parameter token_transfers_from_name(query) [String] Token transfer from name
  # @parameter token_transfers_from_proxy_type(query) [String] Token transfer from proxy type
  # @parameter token_transfers_to_ens_domain_name(query) [String] Token transfer to ENS domain name
  # @parameter token_transfers_to_is_contract(query) [Boolean] Token transfer to is contract
  # @parameter token_transfers_to_is_verified(query) [Boolean] Token transfer to is verified
  # @parameter token_transfers_to_is_scam(query) [Boolean] Token transfer to is scam
  # @parameter token_transfers_to_name(query) [String] Token transfer to name
  # @parameter token_transfers_to_proxy_type(query) [String] Token transfer to proxy type
  # @parameter token_transfers_token_address(query) [String] Token transfer token address
  # @parameter token_transfers_token_address_hash(query) [String] Token transfer token address hash
  # @parameter token_transfers_block_number_min(query) [Integer] Minimum token transfer block number
  # @parameter token_transfers_block_number_max(query) [Integer] Maximum token transfer block number
  # @parameter token_transfers_block_hash(query) [String] Token transfer block hash
  # @parameter token_transfers_transaction_hash(query) [String] Token transfer transaction hash
  # @parameter token_transfers_to_metadata_tags_name(query) [String] Token transfer to metadata tags name
  # @parameter token_transfers_to_metadata_tags_slug(query) [String] Token transfer to metadata tags slug
  # @parameter token_transfers_to_metadata_tags_tag_type(query) [String] Token transfer to metadata tags tag type
  # @parameter token_transfers_method(query) [String] Token transfer method
  # @parameter token_transfers_type(query) [String] Token transfer type
  # @parameter token_transfers_timestamp_min(query) [String] Minimum token transfer timestamp
  # @parameter token_transfers_timestamp_max(query) [String] Maximum token transfer timestamp
  # @parameter token_transfers_token_holders_count_min(query) [Integer] Minimum token holders count
  # @parameter token_transfers_token_holders_count_max(query) [Integer] Maximum token holders count
  # @parameter token_transfers_total_value_min(query) [String] Minimum total token transfer value
  # @parameter token_transfers_total_value_max(query) [String] Maximum total token transfer value
  # @parameter token_transfers_total_decimals_min(query) [Integer] Minimum total decimals
  # @parameter token_transfers_total_decimals_max(query) [Integer] Maximum total decimals
  # @parameter token_transfers_token_icon_url(query) [String] Token icon URL
  # @parameter token_transfers_token_total_supply_min(query) [String] Minimum token total supply
  # @parameter token_transfers_token_total_supply_max(query) [String] Maximum token total supply
  # @parameter token_transfers_token_exchange_rate_min(query) [String] Minimum token exchange rate
  # @parameter token_transfers_token_exchange_rate_max(query) [String] Maximum token exchange rate
  # @parameter token_transfers_token_volume_24h_min(query) [String] Minimum token 24h volume
  # @parameter token_transfers_token_volume_24h_max(query) [String] Maximum token 24h volume
  # @parameter token_transfers_token_circulating_market_cap_min(query) [String] Minimum token circulating market cap
  # @parameter token_transfers_token_circulating_market_cap_max(query) [String] Maximum token circulating market cap
  # @parameter token_transfers_token_holders_min(query) [Integer] Minimum token holders
  # @parameter token_transfers_token_holders_max(query) [Integer] Maximum token holders
  # @parameter token_transfers_next_page_params_block_number_min(query) [Integer] Minimum token transfers next page params block number
  # @parameter token_transfers_next_page_params_block_number_max(query) [Integer] Maximum token transfers next page params block number
  # @parameter token_transfers_next_page_params_index_min(query) [Integer] Minimum token transfers next page params index
  # @parameter token_transfers_next_page_params_index_max(query) [Integer] Maximum token transfers next page params index
  # @parameter token_transfers_next_page_params_items_count_min(query) [Integer] Minimum token transfers next page params items count
  # @parameter token_transfers_next_page_params_items_count_max(query) [Integer] Maximum token transfers next page params items count
  # @parameter method_method_id(query) [String] Smart contract method ID
  # @parameter method_call_type(query) [String] Method call type
  # @parameter decoded_input_method_call(query) [String] Decoded method call
  # @parameter decoded_input_method_id(query) [String] Decoded method ID
  # @parameter decoded_input_parameters_name(query) [String] Decoded parameter name
  # @parameter decoded_input_parameters_type(query) [String] Decoded parameter type
  # @parameter decoded_input_parameters_value(query) [String] Decoded parameter value
  # @parameter method(query) [String] Transaction method
  # @parameter actions_action_type(query) [String] Action type
  # @parameter transaction_types(query) [String] Transaction types
  # @parameter actions_data_from(query) [String] Action from address
  # @parameter actions_data_to(query) [String] Action to address
  # @parameter actions_data_token(query) [String] Action token symbol
  # @parameter actions_data_amount(query) [String] Action amount
  # @parameter actions_protocol(query) [String] Protocol involved in action
  # @parameter actions_type(query) [String] Action type (transfer, swap, etc.)
  # @parameter exchange_rate_min(query) [String] Minimum exchange rate
  # @parameter exchange_rate_max(query) [String] Maximum exchange rate
  # @parameter historic_exchange_rate_min(query) [String] Minimum historic exchange rate
  # @parameter historic_exchange_rate_max(query) [String] Maximum historic exchange rate
  # @parameter confirmation_duration_min(query) [Integer] Minimum confirmation duration in milliseconds
  # @parameter confirmation_duration_max(query) [Integer] Maximum confirmation duration in milliseconds
  # @parameter confirmations_min(query) [Integer] Minimum confirmations count
  # @parameter confirmations_max(query) [Integer] Maximum confirmations count
  # @parameter has_error_in_internal_transactions(query) [Boolean] Has error in internal transactions
  # @parameter logs_address_hash(query) [String] Log address hash
  # @parameter logs_data(query) [String] Log data
  # @parameter logs_topics(query) [String] Log topics
  # @parameter logs_decoded_method_call(query) [String] Log decoded method call
  # @parameter logs_decoded_method_id(query) [String] Log decoded method ID
  # @parameter logs_decoded_parameters_name(query) [String] Log decoded parameters name
  # @parameter logs_decoded_parameters_type(query) [String] Log decoded parameters type
  # @parameter logs_decoded_parameters_value(query) [String] Log decoded parameters value
  # @parameter logs_index_min(query) [Integer] Minimum log index
  # @parameter logs_index_max(query) [Integer] Maximum log index
  # @parameter logs_block_hash(query) [String] Log block hash
  # @parameter logs_block_number_min(query) [Integer] Minimum log block number
  # @parameter logs_block_number_max(query) [Integer] Maximum log block number
  # @parameter logs_transaction_hash(query) [String] Log transaction hash
  # @parameter logs_smart_contract_hash(query) [String] Log smart contract hash
  # @parameter internal_transactions_from_hash(query) [String] Internal transaction from hash
  # @parameter internal_transactions_to_hash(query) [String] Internal transaction to hash
  # @parameter internal_transactions_value_min(query) [String] Minimum internal transaction value
  # @parameter internal_transactions_value_max(query) [String] Maximum internal transaction value
  # @parameter internal_transactions_gas_limit_min(query) [String] Minimum internal transaction gas limit
  # @parameter internal_transactions_gas_limit_max(query) [String] Maximum internal transaction gas limit
  # @parameter internal_transactions_success(query) [Boolean] Internal transaction success
  # @parameter internal_transactions_error(query) [String] Internal transaction error
  # @parameter internal_transactions_type(query) [String] Internal transaction type
  # @parameter internal_transactions_block_number_min(query) [Integer] Minimum internal transaction block number
  # @parameter internal_transactions_block_number_max(query) [Integer] Maximum internal transaction block number
  # @parameter internal_transactions_transaction_hash(query) [String] Internal transaction transaction hash
  # @parameter internal_transactions_index_min(query) [Integer] Minimum internal transaction index
  # @parameter internal_transactions_index_max(query) [Integer] Maximum internal transaction index
  # @parameter authorization_list_authority(query) [String] Authorization list authority
  # @parameter authorization_list_delegated_address(query) [String] Authorization list delegated address
  # @parameter authorization_list_nonce(query) [String] Authorization list nonce
  # @parameter authorization_list_validity(query) [String] Authorization list validity
  # @parameter authorization_list_r(query) [String] Authorization list r value
  # @parameter authorization_list_s(query) [String] Authorization list s value
  # @parameter authorization_list_y_parity(query) [String] Authorization list y parity
  # @parameter raw_trace_action_call_type(query) [String] Raw trace action call type
  # @parameter raw_trace_action_from(query) [String] Raw trace action from
  # @parameter raw_trace_action_to(query) [String] Raw trace action to
  # @parameter raw_trace_action_value(query) [String] Raw trace action value
  # @parameter raw_trace_action_gas(query) [String] Raw trace action gas
  # @parameter raw_trace_action_input(query) [String] Raw trace action input
  # @parameter raw_trace_result_gas_used(query) [String] Raw trace result gas used
  # @parameter raw_trace_result_output(query) [String] Raw trace result output
  # @parameter raw_trace_type(query) [String] Raw trace type
  # @parameter raw_trace_subtraces_min(query) [Integer] Minimum raw trace subtraces
  # @parameter raw_trace_subtraces_max(query) [Integer] Maximum raw trace subtraces
  # @parameter raw_trace_trace_address(query) [String] Raw trace trace address
  # @parameter state_changes_address_hash(query) [String] State change address hash
  # @parameter state_changes_balance_before_min(query) [String] Minimum state change balance before
  # @parameter state_changes_balance_before_max(query) [String] Maximum state change balance before
  # @parameter state_changes_balance_after_min(query) [String] Minimum state change balance after
  # @parameter state_changes_balance_after_max(query) [String] Maximum state change balance after
  # @parameter state_changes_change_min(query) [String] Minimum state change
  # @parameter state_changes_change_max(query) [String] Maximum state change
  # @parameter state_changes_is_miner(query) [Boolean] State change is miner
  # @parameter state_changes_type(query) [String] State change type
  # @parameter summary_success(query) [Boolean] Summary success
  # @parameter limit(query) [Integer] Number of results to return (default: 10, max: 50)
  # @parameter offset(query) [Integer] Number of results to skip for pagination (default: 0)
  # @parameter page(query) [Integer] Page number (alternative to offset, starts at 1)
  # @parameter sort_by(query) [String] Field to sort by (e.g., value, gas_used, timestamp, priority_fee, etc.)
  # @parameter sort_order(query) [String] Sort order: 'asc' for ascending or 'desc' for descending (default: 'desc')
  # @response success(200) [Hash{results: Array<Hash{id: Integer, transaction_hash: String, data: Hash}>, pagination: Hash{total: Integer, limit: Integer, offset: Integer, page: Integer, total_pages: Integer}}]
  # This endpoint provides 254 carefully curated parameters to search for transactions, optimized for both comprehensive coverage and LLM performance.
  def json_search
    transactions = EthereumTransaction.where(nil)

    # Core transaction fields with min/max ranges
    transactions = transactions.where("CAST(data->'info'->>'priority_fee' AS NUMERIC) >= ?", params[:priority_fee_min]) if params[:priority_fee_min].present?
    transactions = transactions.where("CAST(data->'info'->>'priority_fee' AS NUMERIC) <= ?", params[:priority_fee_max]) if params[:priority_fee_max].present?
    transactions = transactions.where("data->'info'->>'raw_input' ILIKE ?", "%#{params[:raw_input]}%") if params[:raw_input].present?
    transactions = transactions.where("data->'info'->>'result' = ?", params[:result]) if params[:result].present?
    transactions = transactions.where("data->'info'->>'hash' = ?", params[:hash]) if params[:hash].present?
    transactions = transactions.where("CAST(data->'info'->>'max_fee_per_gas' AS NUMERIC) >= ?", params[:max_fee_per_gas_min]) if params[:max_fee_per_gas_min].present?
    transactions = transactions.where("CAST(data->'info'->>'max_fee_per_gas' AS NUMERIC) <= ?", params[:max_fee_per_gas_max]) if params[:max_fee_per_gas_max].present?
    transactions = transactions.where("data->'info'->>'revert_reason' ILIKE ?", "%#{params[:revert_reason]}%") if params[:revert_reason].present?
    transactions = transactions.where("CAST(data->'info'->>'confirmation_duration'->>0 AS NUMERIC) >= ?", params[:confirmation_duration_min]) if params[:confirmation_duration_min].present?
    transactions = transactions.where("CAST(data->'info'->>'confirmation_duration'->>0 AS NUMERIC) <= ?", params[:confirmation_duration_max]) if params[:confirmation_duration_max].present?
    transactions = transactions.where("CAST(data->'info'->>'transaction_burnt_fee' AS NUMERIC) >= ?", params[:transaction_burnt_fee_min]) if params[:transaction_burnt_fee_min].present?
    transactions = transactions.where("CAST(data->'info'->>'transaction_burnt_fee' AS NUMERIC) <= ?", params[:transaction_burnt_fee_max]) if params[:transaction_burnt_fee_max].present?
    transactions = transactions.where("CAST(data->'info'->>'type' AS INTEGER) >= ?", params[:type_min]) if params[:type_min].present?
    transactions = transactions.where("CAST(data->'info'->>'type' AS INTEGER) <= ?", params[:type_max]) if params[:type_max].present?
    transactions = transactions.where("CAST(data->'info'->>'token_transfers_overflow' AS BOOLEAN) = ?", params[:token_transfers_overflow]) if params[:token_transfers_overflow].present?
    transactions = transactions.where("CAST(data->'info'->>'confirmations' AS INTEGER) >= ?", params[:confirmations_min]) if params[:confirmations_min].present?
    transactions = transactions.where("CAST(data->'info'->>'confirmations' AS INTEGER) <= ?", params[:confirmations_max]) if params[:confirmations_max].present?
    transactions = transactions.where("CAST(data->'info'->>'position' AS INTEGER) >= ?", params[:position_min]) if params[:position_min].present?
    transactions = transactions.where("CAST(data->'info'->>'position' AS INTEGER) <= ?", params[:position_max]) if params[:position_max].present?
    transactions = transactions.where("CAST(data->'info'->>'max_priority_fee_per_gas' AS NUMERIC) >= ?", params[:max_priority_fee_per_gas_min]) if params[:max_priority_fee_per_gas_min].present?
    transactions = transactions.where("CAST(data->'info'->>'max_priority_fee_per_gas' AS NUMERIC) <= ?", params[:max_priority_fee_per_gas_max]) if params[:max_priority_fee_per_gas_max].present?
    transactions = transactions.where("data->'info'->>'transaction_tag' ILIKE ?", "%#{params[:transaction_tag]}%") if params[:transaction_tag].present?
    transactions = transactions.where("data->'info'->>'created_contract' = ?", params[:created_contract]) if params[:created_contract].present?
    transactions = transactions.where("CAST(data->'info'->>'value' AS NUMERIC) >= ?", params[:value_min]) if params[:value_min].present?
    transactions = transactions.where("CAST(data->'info'->>'value' AS NUMERIC) <= ?", params[:value_max]) if params[:value_max].present?

    # From address fields
    transactions = transactions.where("data->'info'->'from'->>'ens_domain_name' ILIKE ?", "%#{params[:from_ens_domain_name]}%") if params[:from_ens_domain_name].present?
    transactions = transactions.where("data->'info'->'from'->>'hash' = ?", params[:from_hash]) if params[:from_hash].present?
    transactions = transactions.where("CAST(data->'info'->'from'->>'is_contract' AS BOOLEAN) = ?", params[:from_is_contract]) if params[:from_is_contract].present?
    transactions = transactions.where("CAST(data->'info'->'from'->>'is_scam' AS BOOLEAN) = ?", params[:from_is_scam]) if params[:from_is_scam].present?
    transactions = transactions.where("CAST(data->'info'->'from'->>'is_verified' AS BOOLEAN) = ?", params[:from_is_verified]) if params[:from_is_verified].present?
    transactions = transactions.where("data->'info'->'from'->>'name' ILIKE ?", "%#{params[:from_name]}%") if params[:from_name].present?
    transactions = transactions.where("data->'info'->'from'->>'proxy_type' = ?", params[:from_proxy_type]) if params[:from_proxy_type].present?
    transactions = transactions.where("data->'info'->'from'->>'private_tags' @> ?", [params[:from_private_tags]].to_json) if params[:from_private_tags].present?
    transactions = transactions.where("data->'info'->'from'->>'public_tags' @> ?", [params[:from_public_tags]].to_json) if params[:from_public_tags].present?
    transactions = transactions.where("data->'info'->'from'->>'watchlist_names' @> ?", [params[:from_watchlist_names]].to_json) if params[:from_watchlist_names].present?

    # From address metadata tags
    transactions = transactions.where("data->'info'->'from'->'metadata'->'tags' @> ?", [{"name": params[:from_metadata_tags_name]}].to_json) if params[:from_metadata_tags_name].present?
    transactions = transactions.where("data->'info'->'from'->'metadata'->'tags' @> ?", [{"slug": params[:from_metadata_tags_slug]}].to_json) if params[:from_metadata_tags_slug].present?
    transactions = transactions.where("data->'info'->'from'->'metadata'->'tags' @> ?", [{"tagType": params[:from_metadata_tags_tag_type]}].to_json) if params[:from_metadata_tags_tag_type].present?

    # To address fields
    transactions = transactions.where("data->'info'->'to'->>'ens_domain_name' ILIKE ?", "%#{params[:to_ens_domain_name]}%") if params[:to_ens_domain_name].present?
    transactions = transactions.where("data->'info'->'to'->>'hash' = ?", params[:to_hash]) if params[:to_hash].present?
    transactions = transactions.where("CAST(data->'info'->'to'->>'is_contract' AS BOOLEAN) = ?", params[:to_is_contract]) if params[:to_is_contract].present?
    transactions = transactions.where("CAST(data->'info'->'to'->>'is_scam' AS BOOLEAN) = ?", params[:to_is_scam]) if params[:to_is_scam].present?
    transactions = transactions.where("CAST(data->'info'->'to'->>'is_verified' AS BOOLEAN) = ?", params[:to_is_verified]) if params[:to_is_verified].present?
    transactions = transactions.where("data->'info'->'to'->>'name' ILIKE ?", "%#{params[:to_name]}%") if params[:to_name].present?
    transactions = transactions.where("data->'info'->'to'->>'proxy_type' = ?", params[:to_proxy_type]) if params[:to_proxy_type].present?

    # Authorization list fields
    transactions = transactions.where("data->'info'->'authorization_list' @> ?", [{"authority": params[:authorization_list_authority]}].to_json) if params[:authorization_list_authority].present?
    transactions = transactions.where("data->'info'->'authorization_list' @> ?", [{"delegated_address": params[:authorization_list_delegated_address]}].to_json) if params[:authorization_list_delegated_address].present?
    transactions = transactions.where("data->'info'->'authorization_list' @> ?", [{"nonce": params[:authorization_list_nonce]}].to_json) if params[:authorization_list_nonce].present?

    # Gas and fee fields
    transactions = transactions.where("CAST(data->'info'->>'gas_used' AS NUMERIC) >= ?", params[:gas_used_min]) if params[:gas_used_min].present?
    transactions = transactions.where("CAST(data->'info'->>'gas_used' AS NUMERIC) <= ?", params[:gas_used_max]) if params[:gas_used_max].present?
    transactions = transactions.where("CAST(data->'info'->>'gas_limit' AS NUMERIC) >= ?", params[:gas_limit_min]) if params[:gas_limit_min].present?
    transactions = transactions.where("CAST(data->'info'->>'gas_limit' AS NUMERIC) <= ?", params[:gas_limit_max]) if params[:gas_limit_max].present?
    transactions = transactions.where("CAST(data->'info'->>'gas_price' AS NUMERIC) >= ?", params[:gas_price_min]) if params[:gas_price_min].present?
    transactions = transactions.where("CAST(data->'info'->>'gas_price' AS NUMERIC) <= ?", params[:gas_price_max]) if params[:gas_price_max].present?
    transactions = transactions.where("CAST(data->'info'->>'base_fee_per_gas' AS NUMERIC) >= ?", params[:base_fee_per_gas_min]) if params[:base_fee_per_gas_min].present?
    transactions = transactions.where("CAST(data->'info'->>'base_fee_per_gas' AS NUMERIC) <= ?", params[:base_fee_per_gas_max]) if params[:base_fee_per_gas_max].present?

    # Other core fields
    transactions = transactions.where("data->'info'->>'method' ILIKE ?", "%#{params[:method]}%") if params[:method].present?
    transactions = transactions.where("data->'info'->>'status' = ?", params[:status]) if params[:status].present?
    transactions = transactions.where("data->'info'->>'timestamp' >= ?", params[:timestamp_min]) if params[:timestamp_min].present?
    transactions = transactions.where("data->'info'->>'timestamp' <= ?", params[:timestamp_max]) if params[:timestamp_max].present?
    transactions = transactions.where("CAST(data->'info'->>'nonce' AS INTEGER) >= ?", params[:nonce_min]) if params[:nonce_min].present?
    transactions = transactions.where("CAST(data->'info'->>'nonce' AS INTEGER) <= ?", params[:nonce_max]) if params[:nonce_max].present?
    transactions = transactions.where("CAST(data->'info'->>'historic_exchange_rate' AS NUMERIC) >= ?", params[:historic_exchange_rate_min]) if params[:historic_exchange_rate_min].present?
    transactions = transactions.where("CAST(data->'info'->>'historic_exchange_rate' AS NUMERIC) <= ?", params[:historic_exchange_rate_max]) if params[:historic_exchange_rate_max].present?
    transactions = transactions.where("CAST(data->'info'->>'exchange_rate' AS NUMERIC) >= ?", params[:exchange_rate_min]) if params[:exchange_rate_min].present?
    transactions = transactions.where("CAST(data->'info'->>'exchange_rate' AS NUMERIC) <= ?", params[:exchange_rate_max]) if params[:exchange_rate_max].present?
    transactions = transactions.where("CAST(data->'info'->>'block_number' AS INTEGER) >= ?", params[:block_number_min]) if params[:block_number_min].present?
    transactions = transactions.where("CAST(data->'info'->>'block_number' AS INTEGER) <= ?", params[:block_number_max]) if params[:block_number_max].present?
    transactions = transactions.where("CAST(data->'info'->>'has_error_in_internal_transactions' AS BOOLEAN) = ?", params[:has_error_in_internal_transactions]) if params[:has_error_in_internal_transactions].present?
    transactions = transactions.where("data->'info'->>'block_hash' = ?", params[:block_hash]) if params[:block_hash].present?
    transactions = transactions.where("CAST(data->'info'->>'transaction_index' AS INTEGER) >= ?", params[:transaction_index_min]) if params[:transaction_index_min].present?
    transactions = transactions.where("CAST(data->'info'->>'transaction_index' AS INTEGER) <= ?", params[:transaction_index_max]) if params[:transaction_index_max].present?

    # Fee structure
    transactions = transactions.where("data->'info'->'fee'->>'type' = ?", params[:fee_type]) if params[:fee_type].present?
    transactions = transactions.where("CAST(data->'info'->'fee'->>'value' AS NUMERIC) >= ?", params[:fee_value_min]) if params[:fee_value_min].present?
    transactions = transactions.where("CAST(data->'info'->'fee'->>'value' AS NUMERIC) <= ?", params[:fee_value_max]) if params[:fee_value_max].present?

    # Actions
    transactions = transactions.where("data->'info'->'actions' @> ?", [{"action_type": params[:actions_action_type]}].to_json) if params[:actions_action_type].present?
    transactions = transactions.where("data->'info'->'actions' @> ?", [{"data": {"from": params[:actions_data_from]}}].to_json) if params[:actions_data_from].present?
    transactions = transactions.where("data->'info'->'actions' @> ?", [{"data": {"to": params[:actions_data_to]}}].to_json) if params[:actions_data_to].present?
    transactions = transactions.where("data->'info'->'actions' @> ?", [{"data": {"token": params[:actions_data_token]}}].to_json) if params[:actions_data_token].present?

    # Decoded input
    transactions = transactions.where("data->'info'->'decoded_input'->>'method_call' ILIKE ?", "%#{params[:decoded_input_method_call]}%") if params[:decoded_input_method_call].present?
    transactions = transactions.where("data->'info'->'decoded_input'->>'method_id' = ?", params[:decoded_input_method_id]) if params[:decoded_input_method_id].present?

    # Token transfers
    transactions = transactions.where("data->'info'->'token_transfers' @> ?", [{"block_hash": params[:token_transfers_block_hash]}].to_json) if params[:token_transfers_block_hash].present?
    transactions = transactions.where("data->'info'->'token_transfers' @> ?", [{"from": {"hash": params[:token_transfers_from_hash]}}].to_json) if params[:token_transfers_from_hash].present?
    transactions = transactions.where("data->'info'->'token_transfers' @> ?", [{"to": {"hash": params[:token_transfers_to_hash]}}].to_json) if params[:token_transfers_to_hash].present?
    transactions = transactions.where("data->'info'->'token_transfers' @> ?", [{"token": {"address": params[:token_transfers_token_address]}}].to_json) if params[:token_transfers_token_address].present?
    transactions = transactions.where("data->'info'->'token_transfers' @> ?", [{"token": {"symbol": params[:token_transfers_token_symbol]}}].to_json) if params[:token_transfers_token_symbol].present?
    transactions = transactions.where("data->'info'->'token_transfers' @> ?", [{"token": {"name": params[:token_transfers_token_name]}}].to_json) if params[:token_transfers_token_name].present?
    transactions = transactions.where("data->'info'->'token_transfers' @> ?", [{"token": {"type": params[:token_transfers_token_type]}}].to_json) if params[:token_transfers_token_type].present?
    transactions = transactions.where("data->'info'->'token_transfers' @> ?", [{"method": params[:token_transfers_method]}].to_json) if params[:token_transfers_method].present?
    transactions = transactions.where("data->'info'->'token_transfers' @> ?", [{"type": params[:token_transfers_type]}].to_json) if params[:token_transfers_type].present?

    # Internal transactions
    transactions = transactions.where("data->'internal_transactions'->'items' @> ?", [{"block_index": params[:internal_transactions_block_index_min].to_i}].to_json) if params[:internal_transactions_block_index_min].present?
    transactions = transactions.where("data->'internal_transactions'->'items' @> ?", [{"created_contract": {"hash": params[:internal_transactions_created_contract_hash]}}].to_json) if params[:internal_transactions_created_contract_hash].present?
    transactions = transactions.where("data->'internal_transactions'->'items' @> ?", [{"error": params[:internal_transactions_error]}].to_json) if params[:internal_transactions_error].present?
    transactions = transactions.where("data->'internal_transactions'->'items' @> ?", [{"from": {"hash": params[:internal_transactions_from_hash]}}].to_json) if params[:internal_transactions_from_hash].present?
    transactions = transactions.where("data->'internal_transactions'->'items' @> ?", [{"to": {"hash": params[:internal_transactions_to_hash]}}].to_json) if params[:internal_transactions_to_hash].present?
    transactions = transactions.where("data->'internal_transactions'->'items' @> ?", [{"type": params[:internal_transactions_type]}].to_json) if params[:internal_transactions_type].present?
    transactions = transactions.where("CAST(data->'internal_transactions'->'items'->0->>'success' AS BOOLEAN) = ?", params[:internal_transactions_success]) if params[:internal_transactions_success].present?
    transactions = transactions.where("CAST(data->'internal_transactions'->'items'->0->>'gas_limit' AS NUMERIC) >= ?", params[:internal_transactions_gas_limit_min]) if params[:internal_transactions_gas_limit_min].present?
    transactions = transactions.where("CAST(data->'internal_transactions'->'items'->0->>'gas_limit' AS NUMERIC) <= ?", params[:internal_transactions_gas_limit_max]) if params[:internal_transactions_gas_limit_max].present?
    transactions = transactions.where("CAST(data->'internal_transactions'->'items'->0->>'value' AS NUMERIC) >= ?", params[:internal_transactions_value_min]) if params[:internal_transactions_value_min].present?
    transactions = transactions.where("CAST(data->'internal_transactions'->'items'->0->>'value' AS NUMERIC) <= ?", params[:internal_transactions_value_max]) if params[:internal_transactions_value_max].present?

    # Logs
    transactions = transactions.where("data->'logs'->'items' @> ?", [{"address": {"hash": params[:logs_address_hash]}}].to_json) if params[:logs_address_hash].present?
    transactions = transactions.where("data->'logs'->'items' @> ?", [{"block_hash": params[:logs_block_hash]}].to_json) if params[:logs_block_hash].present?
    transactions = transactions.where("data->'logs'->>'data' ILIKE ?", "%#{params[:logs_data]}%") if params[:logs_data].present?
    transactions = transactions.where("data->'logs'->'items' @> ?", [{"decoded": {"method_call": params[:logs_decoded_method_call]}}].to_json) if params[:logs_decoded_method_call].present?
    transactions = transactions.where("data->'logs'->'items' @> ?", [{"decoded": {"method_id": params[:logs_decoded_method_id]}}].to_json) if params[:logs_decoded_method_id].present?
    transactions = transactions.where("data->'logs'->'items' @> ?", [{"smart_contract": {"hash": params[:logs_smart_contract_hash]}}].to_json) if params[:logs_smart_contract_hash].present?
    transactions = transactions.where("data->'logs'->>'topics' ILIKE ?", "%#{params[:logs_topics]}%") if params[:logs_topics].present?

    # Raw trace
    transactions = transactions.where("data->'raw_trace' @> ?", [{"action": {"callType": params[:raw_trace_action_call_type]}}].to_json) if params[:raw_trace_action_call_type].present?
    transactions = transactions.where("data->'raw_trace' @> ?", [{"action": {"from": params[:raw_trace_action_from]}}].to_json) if params[:raw_trace_action_from].present?
    transactions = transactions.where("data->'raw_trace' @> ?", [{"action": {"to": params[:raw_trace_action_to]}}].to_json) if params[:raw_trace_action_to].present?
    transactions = transactions.where("data->'raw_trace' @> ?", [{"action": {"gas": params[:raw_trace_action_gas]}}].to_json) if params[:raw_trace_action_gas].present?
    transactions = transactions.where("data->'raw_trace' @> ?", [{"action": {"input": params[:raw_trace_action_input]}}].to_json) if params[:raw_trace_action_input].present?
    transactions = transactions.where("data->'raw_trace' @> ?", [{"action": {"value": params[:raw_trace_action_value]}}].to_json) if params[:raw_trace_action_value].present?
    transactions = transactions.where("data->'raw_trace' @> ?", [{"result": {"gasUsed": params[:raw_trace_result_gas_used]}}].to_json) if params[:raw_trace_result_gas_used].present?
    transactions = transactions.where("data->'raw_trace' @> ?", [{"result": {"output": params[:raw_trace_result_output]}}].to_json) if params[:raw_trace_result_output].present?
    transactions = transactions.where("data->'raw_trace' @> ?", [{"type": params[:raw_trace_type]}].to_json) if params[:raw_trace_type].present?

    # State changes
    transactions = transactions.where("data->'state_changes'->'items' @> ?", [{"address": {"hash": params[:state_changes_address_hash]}}].to_json) if params[:state_changes_address_hash].present?
    transactions = transactions.where("CAST(data->'state_changes'->'items'->0->>'balance_after' AS NUMERIC) >= ?", params[:state_changes_balance_after_min]) if params[:state_changes_balance_after_min].present?
    transactions = transactions.where("CAST(data->'state_changes'->'items'->0->>'balance_after' AS NUMERIC) <= ?", params[:state_changes_balance_after_max]) if params[:state_changes_balance_after_max].present?
    transactions = transactions.where("CAST(data->'state_changes'->'items'->0->>'balance_before' AS NUMERIC) >= ?", params[:state_changes_balance_before_min]) if params[:state_changes_balance_before_min].present?
    transactions = transactions.where("CAST(data->'state_changes'->'items'->0->>'balance_before' AS NUMERIC) <= ?", params[:state_changes_balance_before_max]) if params[:state_changes_balance_before_max].present?
    transactions = transactions.where("CAST(data->'state_changes'->'items'->0->>'change' AS NUMERIC) >= ?", params[:state_changes_change_min]) if params[:state_changes_change_min].present?
    transactions = transactions.where("CAST(data->'state_changes'->'items'->0->>'change' AS NUMERIC) <= ?", params[:state_changes_change_max]) if params[:state_changes_change_max].present?
    transactions = transactions.where("CAST(data->'state_changes'->'items'->0->>'is_miner' AS BOOLEAN) = ?", params[:state_changes_is_miner]) if params[:state_changes_is_miner].present?
    transactions = transactions.where("data->'state_changes'->'items' @> ?", [{"token_id": params[:state_changes_token_id]}].to_json) if params[:state_changes_token_id].present?
    transactions = transactions.where("data->'state_changes'->'items' @> ?", [{"type": params[:state_changes_type]}].to_json) if params[:state_changes_type].present?
    transactions = transactions.where("data->'state_changes'->'items' @> ?", [{"token": {"address": params[:state_changes_token_address]}}].to_json) if params[:state_changes_token_address].present?
    transactions = transactions.where("data->'state_changes'->'items' @> ?", [{"token": {"symbol": params[:state_changes_token_symbol]}}].to_json) if params[:state_changes_token_symbol].present?
    transactions = transactions.where("data->'state_changes'->'items' @> ?", [{"token": {"name": params[:state_changes_token_name]}}].to_json) if params[:state_changes_token_name].present?

    # Summary
    transactions = transactions.where("CAST(data->'summary'->>'success' AS BOOLEAN) = ?", params[:summary_success]) if params[:summary_success].present?
    transactions = transactions.where("CAST(data->'summary'->'data'->'debug_data'->>'is_prompt_truncated' AS BOOLEAN) = ?", params[:summary_debug_data_is_prompt_truncated]) if params[:summary_debug_data_is_prompt_truncated].present?
    transactions = transactions.where("data->'summary'->'data'->'debug_data'->>'model_classification_type' = ?", params[:summary_debug_data_model_classification_type]) if params[:summary_debug_data_model_classification_type].present?
    transactions = transactions.where("data->'summary'->'data'->'debug_data'->>'post_llm_classification_type' = ?", params[:summary_debug_data_post_llm_classification_type]) if params[:summary_debug_data_post_llm_classification_type].present?
    transactions = transactions.where("data->'summary'->'data'->'debug_data'->>'transaction_hash' = ?", params[:summary_debug_data_transaction_hash]) if params[:summary_debug_data_transaction_hash].present?

    # Summary template transfer
    transactions = transactions.where("data->'summary'->'data'->'debug_data'->'summary_template'->'transfer'->>'template_name' = ?", params[:summary_debug_data_summary_template_transfer_template_name]) if params[:summary_debug_data_summary_template_transfer_template_name].present?
    transactions = transactions.where("data->'summary'->'data'->'debug_data'->'summary_template'->'transfer'->'template_vars'->>'decoded_input' ILIKE ?", "%#{params[:summary_debug_data_summary_template_transfer_template_vars_decoded_input]}%") if params[:summary_debug_data_summary_template_transfer_template_vars_decoded_input].present?
    transactions = transactions.where("data->'summary'->'data'->'debug_data'->'summary_template'->'transfer'->'template_vars'->>'erc20_amount' = ?", params[:summary_debug_data_summary_template_transfer_template_vars_erc20_amount]) if params[:summary_debug_data_summary_template_transfer_template_vars_erc20_amount].present?
    transactions = transactions.where("CAST(data->'summary'->'data'->'debug_data'->'summary_template'->'transfer'->'template_vars'->>'is_erc20_transfer' AS BOOLEAN) = ?", params[:summary_debug_data_summary_template_transfer_template_vars_is_erc20_transfer]) if params[:summary_debug_data_summary_template_transfer_template_vars_is_erc20_transfer].present?
    transactions = transactions.where("CAST(data->'summary'->'data'->'debug_data'->'summary_template'->'transfer'->'template_vars'->>'is_nft_transfer' AS BOOLEAN) = ?", params[:summary_debug_data_summary_template_transfer_template_vars_is_nft_transfer]) if params[:summary_debug_data_summary_template_transfer_template_vars_is_nft_transfer].present?

    # Summary template basic ETH transfer
    transactions = transactions.where("data->'summary'->'data'->'debug_data'->'summary_template'->'basic_eth_transfer'->>'template_name' = ?", params[:summary_debug_data_summary_template_basic_eth_transfer_template_name]) if params[:summary_debug_data_summary_template_basic_eth_transfer_template_name].present?
    transactions = transactions.where("data->'summary'->'data'->'debug_data'->'summary_template'->'basic_eth_transfer'->'template_vars'->>'ether_value' = ?", params[:summary_debug_data_summary_template_basic_eth_transfer_template_vars_ether_value]) if params[:summary_debug_data_summary_template_basic_eth_transfer_template_vars_ether_value].present?
    transactions = transactions.where("data->'summary'->'data'->'debug_data'->'summary_template'->'basic_eth_transfer'->'template_vars'->>'from_hash' = ?", params[:summary_debug_data_summary_template_basic_eth_transfer_template_vars_from_hash]) if params[:summary_debug_data_summary_template_basic_eth_transfer_template_vars_from_hash].present?
    transactions = transactions.where("CAST(data->'summary'->'data'->'debug_data'->'summary_template'->'basic_eth_transfer'->'template_vars'->>'is_from_binance' AS BOOLEAN) = ?", params[:summary_debug_data_summary_template_basic_eth_transfer_template_vars_is_from_binance]) if params[:summary_debug_data_summary_template_basic_eth_transfer_template_vars_is_from_binance].present?
    transactions = transactions.where("CAST(data->'summary'->'data'->'debug_data'->'summary_template'->'basic_eth_transfer'->'template_vars'->>'is_to_binance' AS BOOLEAN) = ?", params[:summary_debug_data_summary_template_basic_eth_transfer_template_vars_is_to_binance]) if params[:summary_debug_data_summary_template_basic_eth_transfer_template_vars_is_to_binance].present?

    # Summary summaries
    transactions = transactions.where("data->'summary'->'data'->'summaries'->0->>'summary_template' ILIKE ?", "%#{params[:summary_summaries_summary_template]}%") if params[:summary_summaries_summary_template].present?
    transactions = transactions.where("data->'summary'->'data'->'summaries'->0->'summary_template_variables'->'action_type'->>'type' = ?", params[:summary_summaries_summary_template_variables_action_type_type]) if params[:summary_summaries_summary_template_variables_action_type_type].present?
    transactions = transactions.where("data->'summary'->'data'->'summaries'->0->'summary_template_variables'->'action_type'->>'value' = ?", params[:summary_summaries_summary_template_variables_action_type_value]) if params[:summary_summaries_summary_template_variables_action_type_value].present?

    # Token transfers next page params
    transactions = transactions.where("CAST(data->'token_transfers'->'next_page_params'->>'block_number' AS INTEGER) >= ?", params[:token_transfers_next_page_params_block_number_min]) if params[:token_transfers_next_page_params_block_number_min].present?
    transactions = transactions.where("CAST(data->'token_transfers'->'next_page_params'->>'block_number' AS INTEGER) <= ?", params[:token_transfers_next_page_params_block_number_max]) if params[:token_transfers_next_page_params_block_number_max].present?
    transactions = transactions.where("CAST(data->'token_transfers'->'next_page_params'->>'index' AS INTEGER) >= ?", params[:token_transfers_next_page_params_index_min]) if params[:token_transfers_next_page_params_index_min].present?
    transactions = transactions.where("CAST(data->'token_transfers'->'next_page_params'->>'index' AS INTEGER) <= ?", params[:token_transfers_next_page_params_index_max]) if params[:token_transfers_next_page_params_index_max].present?
    transactions = transactions.where("CAST(data->'token_transfers'->'next_page_params'->>'items_count' AS INTEGER) >= ?", params[:token_transfers_next_page_params_items_count_min]) if params[:token_transfers_next_page_params_items_count_min].present?
    transactions = transactions.where("CAST(data->'token_transfers'->'next_page_params'->>'items_count' AS INTEGER) <= ?", params[:token_transfers_next_page_params_items_count_max]) if params[:token_transfers_next_page_params_items_count_max].present?

    # Apply sorting
    sort_by = params[:sort_by] || 'id'
    sort_order = params[:sort_order]&.downcase == 'asc' ? 'asc' : 'desc'

    allowed_sort_fields = {
      'id' => 'ethereum_transactions.id',
      'transaction_hash' => 'ethereum_transactions.transaction_hash',
      'value' => "CAST(data->'info'->>'value' AS NUMERIC)",
      'gas_used' => "CAST(data->'info'->>'gas_used' AS NUMERIC)",
      'gas_price' => "CAST(data->'info'->>'gas_price' AS NUMERIC)",
      'priority_fee' => "CAST(data->'info'->>'priority_fee' AS NUMERIC)",
      'max_fee_per_gas' => "CAST(data->'info'->>'max_fee_per_gas' AS NUMERIC)",
      'transaction_burnt_fee' => "CAST(data->'info'->>'transaction_burnt_fee' AS NUMERIC)",
      'confirmations' => "CAST(data->'info'->>'confirmations' AS INTEGER)",
      'position' => "CAST(data->'info'->>'position' AS INTEGER)",
      'type' => "CAST(data->'info'->>'type' AS INTEGER)",
      'block_number' => "CAST(data->'info'->>'block_number' AS INTEGER)",
      'transaction_index' => "CAST(data->'info'->>'transaction_index' AS INTEGER)",
      'nonce' => "CAST(data->'info'->>'nonce' AS INTEGER)",
      'timestamp' => "data->'info'->>'timestamp'",
      'exchange_rate' => "CAST(data->'info'->>'exchange_rate' AS NUMERIC)",
      'historic_exchange_rate' => "CAST(data->'info'->>'historic_exchange_rate' AS NUMERIC)",
      'created_at' => 'transactions.created_at'
    }

    if allowed_sort_fields.key?(sort_by)
      sort_column = allowed_sort_fields[sort_by]
      if sort_column.include?("data->")
        transactions = transactions.order(Arel.sql("#{sort_column} #{sort_order} NULLS LAST"))
      else
        transactions = transactions.order(Arel.sql("#{sort_column} #{sort_order}"))
      end
    else
      # Default fallback
      transactions = transactions.order(Arel.sql("ethereum_transactions.id DESC"))
    end

    # Apply pagination with defaults
    limit = params[:limit]&.to_i || 10
    limit = [limit, 50].min
    offset = if params[:page].present?
               page = [params[:page].to_i, 1].max
               (page - 1) * limit
             else
               params[:offset]&.to_i || 0
             end

    total_count = transactions.count
    paginated_transactions = transactions.limit(limit).offset(offset)

    current_page = (offset / limit) + 1
    total_pages = (total_count.to_f / limit).ceil

    render json: {
      results: paginated_transactions.pluck(:transaction_hash),
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

  def get_transaction_info(transaction)
    blockscout_api_get("/transactions/#{transaction}")
  end

  def get_transaction_token_transfers(transaction)
    blockscout_api_get("/transactions/#{transaction}/token-transfers")
  end

  def get_transaction_internal_transactions(transaction)
    blockscout_api_get("/transactions/#{transaction}/internal-transactions")
  end

  def get_transaction_logs(transaction)
    blockscout_api_get("/transactions/#{transaction}/logs")
  end

  def get_transaction_raw_trace(transaction)
    blockscout_api_get("/transactions/#{transaction}/raw-trace")
  end

  def get_transaction_state_changes(transaction)
    blockscout_api_get("/transactions/#{transaction}/state-changes")
  end

  def get_transaction_summary(transaction)
    blockscout_api_get("/transactions/#{transaction}/summary")
  end

end



