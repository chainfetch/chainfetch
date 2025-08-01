class Api::V1::AddressController < ApplicationController
  before_action :set_chain_config

  # @summary Get address info for a given address hash
  # @parameter chain_id(path) [!String] The chain ID to get info for (ethereum, bitcoin)
  # @parameter address_hash(path) [!String] The address hash to get info for
  # @parameter limit(query) [Integer] The number of transactions to get (default: 50, max: 10000)
  # @response success(200) [Hash{address: String, balance: String, total_received: String, total_sent: String, tx_count: Integer, tx_analyzed: String, chain: String, symbol: String}]
  def show
    address_hash = params[:address_hash]
    
    case @chain_id
    when 'ethereum', 'eth'
      render json: get_ethereum_address_info(address_hash)
    when 'bitcoin', 'btc'
      render json: get_bitcoin_address_info(address_hash)
    when 'solana', 'sol'
      render json: get_solana_address_info(address_hash)
    else
      render json: { error: "Unsupported chain: #{@chain_id}" }, status: 400
    end
  rescue => e
    render json: { error: e.message }, status: 500
  end

  private

  def set_chain_config
    @chain_id = params[:chain_id].downcase
    
    @config = case @chain_id
    when 'ethereum', 'eth'
      {
        rpc_url: 'https://ethereum-rpc.publicnode.com',
        decimals: 18,
        symbol: 'ETH'
      }
    when 'bitcoin', 'btc'
      {
        rpc_url: 'https://bitcoin-rpc.publicnode.com',
        decimals: 8,
        symbol: 'BTC'
      }
    when 'solana', 'sol'
      {
        rpc_url: 'https://solana-mainnet.api.syndica.io/api-key/48e5prksieB4p8TKvibgHPFSG1GhBy8LWUkVggtyGm67eMEh1kXx8Nvy85Rcip2R7zxSzW6h7FtihYHF4VG5cCrsHph9UWWtNsX',
        decimals: 9,
        symbol: 'SOL'
      }
    else
      nil
    end
    
    unless @config
      render json: { error: "Unsupported chain: #{@chain_id}" }, status: 400
      return
    end
  end

  def get_ethereum_address_info(address)
    # Parse transaction limit parameter (default: 50, max: 10000)
    tx_limit = params[:limit].to_i
    tx_limit = 50 if tx_limit <= 0 || tx_limit.nil?
    tx_limit = [tx_limit, 10000].min  # Cap at 10,000 for API rate limits
    
    # Use Blockscout API for comprehensive address analysis (free!)
    blockscout_data = get_blockscout_address_data(address, tx_limit)
    
    response = {
      address: address,
      balance: blockscout_data[:balance],
      total_received: blockscout_data[:total_received],
      total_sent: blockscout_data[:total_sent],
      tx_count: blockscout_data[:tx_count],
      tx_analyzed: blockscout_data[:tx_analyzed],
      chain: 'ethereum',
      symbol: @config[:symbol]
    }
    
    # Add ERC-20 tokens if any found
    if blockscout_data[:erc20_tokens]&.any?
      response[:erc20_tokens] = blockscout_data[:erc20_tokens]
      response[:erc20_token_count] = blockscout_data[:erc20_tokens].length
    end
    
    # Add transactions if any found
    if blockscout_data[:transactions]&.any?
      response[:transactions] = blockscout_data[:transactions]
    end
    
    response
  end

  def get_blockscout_address_data(address, limit)
    # Use Blockscout API (completely free, no API key needed)
    base_url = "https://eth.blockscout.com/api/v2"
    
    # Get account info (balance) from Blockscout
    account_url = "#{base_url}/addresses/#{address}"
    account_response = make_http_request(account_url)
    
    # Get balance (Blockscout returns balance in Wei as string)
    balance_wei = account_response.dig('coin_balance').to_i
    balance_eth = balance_wei / 10**18.0

    # Get ERC-20 token balances from Blockscout
    tokens_url = "#{base_url}/addresses/#{address}/token-balances"
    tokens_response = make_http_request(tokens_url)
    
    erc20_tokens = []
    if tokens_response.is_a?(Array)
      tokens_response.each do |token_data|
        next unless token_data.dig('token', 'type') == 'ERC-20'
        
        token_info = token_data['token']
        raw_balance = token_data['value'].to_i
        decimals = token_info['decimals'].to_i
        
        # Skip tokens with zero balance
        next if raw_balance == 0
        
        # Calculate human-readable balance
        balance_formatted = if decimals > 0
          (raw_balance / 10**decimals.to_f).to_s
        else
          raw_balance.to_s
        end
        
        erc20_tokens << {
          contract: token_info['address'],
          name: token_info['name'],
          symbol: token_info['symbol'],
          balance: balance_formatted,
          decimals: decimals,
          price_usd: token_info['exchange_rate']
        }
      end
    end

    # Get regular transactions from Blockscout
    # Split the limit between regular and internal transactions (70% regular, 30% internal)
    regular_limit = (limit * 0.7).ceil
    internal_limit = (limit * 0.3).ceil
    
    transactions_url = "#{base_url}/addresses/#{address}/transactions?limit=#{regular_limit}"
    transactions_response = make_http_request(transactions_url)
    
    # Get internal transactions from Blockscout
    internal_url = "#{base_url}/addresses/#{address}/internal-transactions?limit=#{internal_limit}"
    internal_response = make_http_request(internal_url)
    
    regular_transactions = transactions_response.dig('items') || []
    internal_transactions = internal_response.dig('items') || []
    
    # Calculate totals and collect detailed transaction info
    total_received = 0.0
    total_sent = 0.0
    transactions = []
    
    # Process regular transactions
    regular_transactions.each do |tx|
      value_wei = tx.dig('value').to_i
      value_eth = value_wei / 10**18.0
      
      # Collect transaction details
      timestamp = tx['timestamp'] ? Time.parse(tx['timestamp']).iso8601 : nil
      tx_hash = tx['hash']
      gas_price = tx.dig('gas_price').to_i
      gas_used = tx.dig('gas_used').to_i
      gas_fee_eth = (gas_price * gas_used) / 10**18.0
      
      if tx.dig('to', 'hash')&.downcase == address.downcase && value_eth > 0
        # ETH received
        total_received += value_eth
        
        transactions << {
          tx_id: tx_hash,
          timestamp: timestamp,
          amount: sprintf("%.18f", value_eth).gsub(/\.?0+$/, ""),
          type: "received",
          fee: sprintf("%.18f", 0).gsub(/\.?0+$/, ""),
          from: tx.dig('from', 'hash'),
          to: tx.dig('to', 'hash')
        }
      elsif tx.dig('from', 'hash')&.downcase == address.downcase
        # ETH sent (if any)
        total_sent += value_eth if value_eth > 0
        
        # Add gas fees for ALL outgoing transactions (including ERC-20 token transfers)
        total_sent += gas_fee_eth
        
        transactions << {
          tx_id: tx_hash,
          timestamp: timestamp,
          amount: value_eth > 0 ? sprintf("%.18f", -value_eth).gsub(/\.?0+$/, "") : "0",
          type: "sent",
          fee: sprintf("%.18f", gas_fee_eth).gsub(/\.?0+$/, ""),
          from: tx.dig('from', 'hash'),
          to: tx.dig('to', 'hash')
        }
      end
    end
    
    # Process internal transactions
    internal_transactions.each do |tx|
      value_wei = tx.dig('value').to_i
      value_eth = value_wei / 10**18.0
      next if value_eth == 0
      
      if tx.dig('to', 'hash')&.downcase == address.downcase
        total_received += value_eth
        
        transactions << {
          tx_id: tx['transaction_hash'],
          timestamp: tx['timestamp'] ? Time.parse(tx['timestamp']).iso8601 : nil,
          amount: sprintf("%.18f", value_eth).gsub(/\.?0+$/, ""),
          type: "received_internal",
          fee: "0",
          from: tx.dig('from', 'hash'),
          to: tx.dig('to', 'hash')
        }
      elsif tx.dig('from', 'hash')&.downcase == address.downcase
        total_sent += value_eth
        
        transactions << {
          tx_id: tx['transaction_hash'],
          timestamp: tx['timestamp'] ? Time.parse(tx['timestamp']).iso8601 : nil,
          amount: sprintf("%.18f", -value_eth).gsub(/\.?0+$/, ""),
          type: "sent_internal",
          fee: "0",
          from: tx.dig('from', 'hash'),
          to: tx.dig('to', 'hash')
        }
      end
    end

    # Sort all transactions by timestamp (newest first) and limit to user's requested limit
    transactions.sort! { |a, b| (b[:timestamp] || "") <=> (a[:timestamp] || "") }
    transactions = transactions.first(limit)

    {
      balance: balance_eth.to_s,
      total_received: total_received.to_s,
      total_sent: total_sent.to_s,
      tx_count: regular_transactions.length + internal_transactions.length,
      tx_analyzed: "#{transactions.length}/#{limit} transactions analyzed (#{regular_transactions.length} regular + #{internal_transactions.length} internal fetched, sorted by timestamp, limited to #{limit})",
      erc20_tokens: erc20_tokens,
      transactions: transactions
    }
  end

  def make_http_request(url)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == 'https'
    
    request = Net::HTTP::Get.new(uri)
    response = http.request(request)
    JSON.parse(response.body)
  end

  def get_bitcoin_address_info(address)
    # Parse transaction limit parameter (default: 50, max: 2000 for Bitcoin)
    tx_limit = params[:limit].to_i
    tx_limit = 50 if tx_limit <= 0 || tx_limit.nil?
    tx_limit = [tx_limit, 2000].min  # BlockCypher has lower limits than Etherscan
    
    # Use BlockCypher API for Bitcoin address analysis
    bitcoin_data = get_blockcypher_address_data(address, tx_limit)
    
    response = {
      address: address,
      balance: bitcoin_data[:balance],
      total_received: bitcoin_data[:total_received],
      total_sent: bitcoin_data[:total_sent],
      tx_count: bitcoin_data[:tx_count],
      tx_analyzed: bitcoin_data[:tx_analyzed],
      chain: 'bitcoin',
      symbol: @config[:symbol]
    }
    
    # Add transactions if any found
    if bitcoin_data[:transactions]&.any?
      response[:transactions] = bitcoin_data[:transactions]
    end
    
    response
  end

  def get_blockcypher_address_data(address, limit)
    base_url = "https://api.blockcypher.com/v1/btc/main"
    
    # Get address info with transaction details (BlockCypher includes txrefs by default)
    address_url = "#{base_url}/addrs/#{address}?limit=#{limit}"
    address_response = make_http_request(address_url)
    
    # Convert satoshis to BTC
    balance_satoshis = address_response['balance'] || 0
    total_received_satoshis = address_response['total_received'] || 0
    total_sent_satoshis = address_response['total_sent'] || 0
    
    balance_btc = balance_satoshis / 100_000_000.0
    total_received_btc = total_received_satoshis / 100_000_000.0
    total_sent_btc = total_sent_satoshis / 100_000_000.0
    
    # Get transaction count (BlockCypher provides this directly)
    tx_count = address_response['n_tx'] || 0
    
    # Process transactions from txrefs
    transactions = []
    txrefs = address_response['txrefs'] || []
    
    txrefs.each do |txref|
      value_satoshis = txref['value'] || 0
      value_btc = value_satoshis / 100_000_000.0
      
      # Determine transaction type based on tx_input_n
      # -1 means it's an output (received), otherwise it's an input (sent)
      if txref['tx_input_n'] == -1
        # Bitcoin received
        tx_type = "received"
        amount = sprintf("%.8f", value_btc).gsub(/\.?0+$/, "")
      else
        # Bitcoin sent
        tx_type = "sent" 
        amount = sprintf("%.8f", -value_btc).gsub(/\.?0+$/, "")
      end
      
      transactions << {
        tx_id: txref['tx_hash'],
        timestamp: txref['confirmed'],
        amount: amount,
        type: tx_type,
        block_height: txref['block_height'],
        confirmations: txref['confirmations'],
        spent: txref['spent'] || false
      }
    end
    
    # Sort transactions by block height (newest first)
    transactions.sort! { |a, b| (b[:block_height] || 0) <=> (a[:block_height] || 0) }
    
    # Limit to user's requested limit
    transactions = transactions.first(limit)
    
    analyzed_note = if tx_count > 0
      "#{transactions.length}/#{limit} transactions analyzed (#{tx_count} total transactions available)"
    else
      "No transactions found"
    end

    {
      balance: balance_btc.to_s,
      total_received: total_received_btc.to_s,
      total_sent: total_sent_btc.to_s,
      tx_count: tx_count,
      tx_analyzed: analyzed_note,
      transactions: transactions
    }
  end

  def get_solana_address_info(address)
    # Parse transaction limit parameter (default: 50, max: 1000 for Solana)
    tx_limit = params[:limit].to_i
    tx_limit = 50 if tx_limit <= 0 || tx_limit.nil?
    tx_limit = [tx_limit, 1000].min  # Solana RPC has reasonable limits
    
    # Use Solana RPC for address analysis
    solana_data = get_solana_address_data(address, tx_limit)
    
    # Return the complete data from get_solana_address_data
    solana_data
  end

  def get_solana_address_data(address, limit)
    # Get SOL balance from Solana RPC
    balance_response = make_solana_rpc_call('getBalance', [address])
    balance_lamports = balance_response.dig('result', 'value') || 0
    balance_sol = balance_lamports / 10**@config[:decimals].to_f

    # Get SPL token accounts for this address
    spl_tokens = []
    
    begin
      token_accounts_response = make_solana_rpc_call('getTokenAccountsByOwner', [
        address,
        { "programId" => "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA" },
        { "encoding" => "jsonParsed" }
      ])
      
      if token_accounts_response.dig('result', 'value')
        token_accounts = token_accounts_response['result']['value']
        
        token_accounts.each do |account|
          account_info = account.dig('account', 'data', 'parsed', 'info')
          next unless account_info
          
          mint = account_info['mint']
          token_amount = account_info.dig('tokenAmount')
          next unless token_amount && token_amount['uiAmount'] && token_amount['uiAmount'] > 0
          
          # Get token metadata
          token_name = get_spl_token_name(mint) || "#{mint[0..7]}..."
          
          spl_tokens << {
            mint: mint,
            name: token_name,
            balance: token_amount['uiAmountString'],
            decimals: token_amount['decimals']
          }
        end
      elsif token_accounts_response['error']
        Rails.logger.warn "Error fetching SPL token accounts for #{address}: #{token_accounts_response['error']}"
      else
        Rails.logger.warn "Unexpected response for SPL token accounts for #{address}: #{token_accounts_response.to_s[0..200]}"
      end
    rescue => e
      Rails.logger.warn "Exception fetching SPL token accounts for #{address}: #{e.message}"
    end

    # Get transactions directly from Solana RPC (most reliable)
    signatures_response = make_solana_rpc_call('getSignaturesForAddress', [address, {"limit" => limit}])
    
    # Initialize response
    response = {
      address: address,
      balance: balance_sol.to_s,
      chain: 'solana',
      symbol: @config[:symbol]
    }
    
    # Add SPL tokens if any found
    if spl_tokens.any?
      response[:spl_tokens] = spl_tokens
      response[:spl_token_count] = spl_tokens.length
    end
    
    begin
      if signatures_response.dig('result')&.any?
        signatures = signatures_response['result']
        tx_count = signatures.length
        
        # Analyze transactions using Solana RPC
        # NOTE: total_sent/total_received track SOL only (not SPL tokens)
        # SPL tokens are shown separately in spl_tokens array
        total_received = 0.0
        total_sent = 0.0
        analyzed_count = 0
        sol_transfers_found = 0
        failed_to_parse = 0
        no_balance_change = 0
        transactions = []        
        # Analyze available transactions with better RPC provider
        sample_size = [limit, signatures.length].min
        signatures.first(sample_size).each do |sig_info|
          signature = sig_info['signature']
          next unless signature
          
          begin
            # Get detailed transaction from Solana RPC (simplified)
            tx_response = make_solana_rpc_call('getTransaction', [
              signature, 
              {
                "encoding" => "jsonParsed",
                "maxSupportedTransactionVersion" => 0
              }
            ])
            
            # Debug: check what we got back
            if tx_response.nil?
              failed_to_parse += 1
            elsif tx_response.dig('error')
              failed_to_parse += 1
            elsif tx_response.dig('result')
              tx_data = tx_response['result']
              analyzed_count += 1
              
              # Parse account changes
              account_keys = tx_data.dig('transaction', 'message', 'accountKeys') || []
              pre_balances = tx_data.dig('meta', 'preBalances') || []
              post_balances = tx_data.dig('meta', 'postBalances') || []
              
              # Find the index of our target address in account keys
              account_index = nil
              account_keys.each_with_index do |key, index|
                key_address = key.is_a?(Hash) ? key['pubkey'] : key
                if key_address == address
                  account_index = index
                  break
                end
              end
              
              if account_index && pre_balances[account_index] && post_balances[account_index]
                # Calculate balance change in lamports
                pre_balance_lamports = pre_balances[account_index].to_i
                post_balance_lamports = post_balances[account_index].to_i
                
                # Convert to SOL and calculate net change
                net_change_lamports = post_balance_lamports - pre_balance_lamports
                net_change_sol = net_change_lamports / 10**@config[:decimals].to_f
                
                if net_change_sol > 0
                  # Collect transaction details
                  tx_detail = {
                    tx_id: signature,
                    timestamp: sig_info['blockTime'] ? Time.at(sig_info['blockTime']).utc.iso8601 : nil,
                    amount: sprintf("%.9f", net_change_sol).gsub(/\.?0+$/, ""),
                    type: "received",
                    fee: tx_data.dig('meta', 'fee') ? (tx_data['meta']['fee'] / 10**@config[:decimals].to_f).to_s : "0"
                  }
                  transactions << tx_detail
                  
                  # SOL received
                  total_received += net_change_sol
                  sol_transfers_found += 1
                elsif net_change_sol < 0
                  # Collect transaction details
                  tx_detail = {
                    tx_id: signature,
                    timestamp: sig_info['blockTime'] ? Time.at(sig_info['blockTime']).utc.iso8601 : nil,
                    amount: sprintf("%.9f", net_change_sol).gsub(/\.?0+$/, ""),
                    type: "sent",
                    fee: tx_data.dig('meta', 'fee') ? (tx_data['meta']['fee'] / 10**@config[:decimals].to_f).to_s : "0"
                  }
                  transactions << tx_detail
                  
                  # SOL sent (absolute value, includes fees)
                  total_sent += net_change_sol.abs
                  sol_transfers_found += 1
                else
                  # No balance change
                  no_balance_change += 1
                end
              else
                # Address not in transaction or no balance data
                no_balance_change += 1
              end
            else
              # RPC returned no result and no error - unexpected response
              failed_to_parse += 1
            end
          rescue => e
            Rails.logger.warn "Error analyzing Solana transaction #{signature}: #{e.message}"
            failed_to_parse += 1
          end
        end
        
        # Format numbers properly (avoid scientific notation)
        total_received_formatted = sprintf("%.9f", total_received).gsub(/\.?0+$/, "")
        total_sent_formatted = sprintf("%.9f", total_sent).gsub(/\.?0+$/, "")
        
        # Create detailed analysis note
        analysis_parts = []
        
        if analyzed_count > 0
          analysis_parts << "#{analyzed_count}/#{sample_size} recent transactions analyzed"
          
          if sol_transfers_found > 0
            analysis_parts << "#{sol_transfers_found} with SOL transfers"
          end
          
          if no_balance_change > 0
            analysis_parts << "#{no_balance_change} without SOL changes"
          end
          
          if failed_to_parse > 0
            analysis_parts << "#{failed_to_parse} RPC timeouts"
          end
        else
          analysis_parts << "Transaction analysis limited due to RPC constraints"
        end
        
        analysis_note = analysis_parts.join(", ")
        
        # Always mention that this is a limited sample
        if tx_count > sample_size
          analysis_note += " (#{tx_count} total transactions available)"
        end
        
        # Check if the math makes sense and add explanatory note
        expected_balance = total_received - total_sent
        current_balance = balance_sol
        
        if analyzed_count > 0 && (current_balance - expected_balance).abs > 0.001
          analysis_note += ". Note: Balance includes historical activity beyond analyzed sample"
        elsif analyzed_count == 0
          analysis_note += ". Total sent/received unavailable - balance and SPL tokens are reliable"
        end
        
        response[:total_received] = total_received > 0 ? total_received_formatted : "0"
        response[:total_sent] = total_sent > 0 ? total_sent_formatted : "0"
        response[:tx_count] = tx_count
        response[:transactions] = transactions if transactions.any?
        response[:tx_analyzed] = "#{analysis_note} (limit: #{limit})"
        
      else
        # No transactions found
        response[:total_received] = "0.0"
        response[:total_sent] = "0.0"
        response[:tx_count] = 0
        response[:tx_analyzed] = "No transactions found"
      end
    rescue => e
      # RPC error fallback
      response[:total_received] = "RPC error - balance only"
      response[:total_sent] = "RPC error - balance only"
      response[:tx_count] = 0
      response[:tx_analyzed] = "Error fetching transactions: #{e.message}"
    end
    
    response
  end

  def make_solana_rpc_call(method, params)
    uri = URI(@config[:rpc_url])
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == 'https'
    
    # Add proper timeouts
    http.open_timeout = 10  # seconds
    http.read_timeout = 30  # seconds
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    
    request.body = {
      jsonrpc: '2.0',
      id: 1,
      method: method,
      params: params
    }.to_json

    response = http.request(request)
    
    # Better error handling
    if response.code.to_i != 200
      Rails.logger.warn "HTTP error #{response.code} for Solana RPC call: #{method}"
      return { 'error' => "HTTP #{response.code}" }
    end
    
    JSON.parse(response.body)
  rescue Net::TimeoutError => e
    Rails.logger.warn "Timeout error for Solana RPC call: #{method} - #{e.message}"
    { 'error' => 'Timeout' }
  rescue JSON::ParserError => e
    Rails.logger.warn "JSON parse error for Solana RPC call: #{method} - #{e.message}"
    { 'error' => 'JSON parse error' }
  rescue => e
    Rails.logger.warn "Error for Solana RPC call: #{method} - #{e.message}"
    { 'error' => e.message }
  end

  def get_spl_token_name(mint_address)
    # Common SPL token registry (you could expand this or use an API)
    token_registry = {
      'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v' => 'USDC',
      'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB' => 'USDT',
      'SRMuApVNdxXokk5GT7XD5cUUgXMBCoAz2LHeuAoKWRt' => 'SRM',
      'So11111111111111111111111111111111111111112' => 'SOL',
      'mSoLzYCxHdYgdzU16g5QSh3i5K3z3KZK7ytfqcJm7So' => 'mSOL',
      'DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263' => 'BONK',
      '7vfCXTUXx5WJV5JADk17DUJ4ksgau7utNKj4b963voxs' => 'ETH',
      'A9mUU4qviSctJVPJdBJWkb28deg915LYJKrzQ19ji3FM' => 'USTv2',
      'Saber2gLauYim4Mvftnrasomsv6NvAuncvMEZwcLpD1' => 'SBR'
    }
    
    token_registry[mint_address]
  end
end 