require 'json'
require 'net/http'
require 'uri'
require 'singleton'

class ContractDecoderService
  include Singleton

  def initialize
    # No caching or RPC endpoint needed since we use hardcoded contracts
  end

  # Popular DeFi and NFT contract addresses and their ABIs
  CONTRACTS = {
    # Uniswap V2 Router
    '0x7a250d5630b4cf539739df2c5dacb4c659f2488d' => {
      name: 'Uniswap V2 Router',
      category: 'DeFi',
      functions: {
        '0x38ed1739' => { name: 'swapExactTokensForTokens', type: 'swap' },
        '0x8803dbee' => { name: 'swapTokensForExactTokens', type: 'swap' },
        '0x7ff36ab5' => { name: 'swapExactETHForTokens', type: 'swap' },
        '0x4a25d94a' => { name: 'swapTokensForExactETH', type: 'swap' },
        '0x791ac947' => { name: 'swapExactTokensForETH', type: 'swap' },
        '0xfb3bdb41' => { name: 'swapETHForExactTokens', type: 'swap' },
        '0xe8e33700' => { name: 'addLiquidity', type: 'liquidity' },
        '0xf305d719' => { name: 'addLiquidityETH', type: 'liquidity' },
        '0xbaa2abde' => { name: 'removeLiquidity', type: 'liquidity' },
        '0x02751cec' => { name: 'removeLiquidityETH', type: 'liquidity' }
      }
    },

    # Uniswap V3 Router
    '0xe592427a0aece92de3edee1f18e0157c05861564' => {
      name: 'Uniswap V3 Router',
      category: 'DeFi',
      functions: {
        '0x414bf389' => { name: 'exactInputSingle', type: 'swap' },
        '0xc04b8d59' => { name: 'exactInput', type: 'swap' },
        '0xdb3e2198' => { name: 'exactOutputSingle', type: 'swap' },
        '0x09b81346' => { name: 'exactOutput', type: 'swap' }
      }
    },

    # Uniswap V3 Factory
    '0x1f98431c8ad98523631ae4a59f267346ea31f984' => {
      name: 'Uniswap V3 Factory',
      category: 'DeFi',
      functions: {
        '0xc6a502d6' => { name: 'createPool', type: 'liquidity' }
      }
    },

    # Aave V3 Pool
    '0x87870bca3f3fd6335c3f4ce8392d69350b4fa4e2' => {
      name: 'Aave V3 Pool',
      category: 'DeFi',
      functions: {
        '0x617ba037' => { name: 'supply', type: 'deposit' },
        '0xa415bcad' => { name: 'borrow', type: 'borrow' },
        '0x573ade81' => { name: 'repay', type: 'repay' },
        '0x02c205f0' => { name: 'withdraw', type: 'withdraw' }
      }
    },

    # MakerDAO DAI Token
    '0x6b175474e89094c44da98b954eedeac495271d0f' => {
      name: 'MakerDAO DAI',
      category: 'DeFi',
      functions: {
        '0xa9059cbb' => { name: 'transfer', type: 'transfer' },
        '0x095ea7b3' => { name: 'approve', type: 'approval' }
      }
    },

    # Curve Finance Factory
    '0xb9fc157394af804a3578134a6585c0dc9cc990d4' => {
      name: 'Curve Finance Factory',
      category: 'DeFi',
      functions: {
        '0x0fe4abd0' => { name: 'deploy_plain_pool', type: 'liquidity' }
      }
    },

    # Yearn Finance Vault
    '0xe11e3382487dc8022d3e4328dcc5a8fc53a3a5f8' => {
      name: 'Yearn Finance Vault',
      category: 'DeFi',
      functions: {
        '0xb6b55f25' => { name: 'deposit', type: 'deposit' },
        '0x2e1a7d4d' => { name: 'withdraw', type: 'withdraw' }
      }
    },

    # OpenSea Seaport
    '0x00000000006c3852cbef3e08e8df289169ede581' => {
      name: 'OpenSea Seaport',
      category: 'NFT',
      functions: {
        '0xfb0f3ee1' => { name: 'fulfillOrder', type: 'trade' },
        '0x87201b41' => { name: 'fulfillAvailableOrders', type: 'trade' },
        '0xed98a574' => { name: 'fulfillAvailableAdvancedOrders', type: 'trade' }
      }
    },

    # OpenSea Seaport 1.5
    '0x00000000000000adc04c56bf30ac9d3c0aaf14dc' => {
      name: 'OpenSea Seaport 1.5',
      category: 'NFT',
      functions: {
        '0x56d5c4d8' => { name: 'fulfillBasicOrder', type: 'nft_trade' }
      }
    },

    # Blur Marketplace
    '0x000000000000ad05ccc4f1004560a89f02fc946e' => {
      name: 'Blur Marketplace',
      category: 'NFT',
      functions: {
        '0xef7038b0' => { name: 'execute', type: 'nft_trade' }
      }
    },

    # Rarible Exchange
    '0x60f80121c31a0d46b527970bf2ff3d1b5c3220d1' => {
      name: 'Rarible Exchange',
      category: 'NFT',
      functions: {
        '0x6e9d84a5' => { name: 'matchOrders', type: 'nft_trade' }
      }
    },

    # Magic Eden Ethereum
    '0x68327a91e51f87f833d0d1f2fa446e0d8fd3c5c5' => {
      name: 'Magic Eden Ethereum',
      category: 'NFT',
      functions: {
        '0x6e9d84a5' => { name: 'matchOrders', type: 'nft_trade' }
      }
    },

    # USDC Contract
    '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48' => {
      name: 'USD Coin',
      category: 'Token',
      functions: {
        '0xa9059cbb' => { name: 'transfer', type: 'transfer' },
        '0x23b872dd' => { name: 'transferFrom', type: 'transfer' },
        '0x095ea7b3' => { name: 'approve', type: 'approval' }
      }
    },

    # WETH Contract
    '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2' => {
      name: 'WETH',
      category: 'Token',
      functions: {
        '0xd0e30db0' => { name: 'deposit', type: 'wrap' },
        '0x2e1a7d4d' => { name: 'withdraw', type: 'unwrap' },
        '0xa9059cbb' => { name: 'transfer', type: 'transfer' },
        '0x23b872dd' => { name: 'transferFrom', type: 'transfer' }
      }
    },

    # ENS Registry
    '0x00000000000c2e074ec69a0dfb2997ba6c7d2e1e' => {
      name: 'ENS Registry',
      category: 'NFT',
      functions: {
        '0x1896f70a' => { name: 'setResolver', type: 'domain' },
        '0x5b0fc9c3' => { name: 'setOwner', type: 'domain' },
        '0x14ab9038' => { name: 'setSubnodeOwner', type: 'domain' }
      }
    },

    # SushiSwap Router
    '0xd9e1ce17f2641f24ae83637ab66a2cca9c378b9f' => {
      name: 'SushiSwap Router',
      category: 'DeFi',
      functions: {
        '0x38ed1739' => { name: 'swapExactTokensForTokens', type: 'swap' },
        '0x7ff36ab5' => { name: 'swapExactETHForTokens', type: 'swap' },
        '0x791ac947' => { name: 'swapExactTokensForETH', type: 'swap' }
      }
    },

    # 1inch Router
    '0x1111111254eeb25477b68fb85ed929f73a960582' => {
      name: '1inch Router',
      category: 'DeFi',
      functions: {
        '0x7c025200' => { name: 'swap', type: 'swap' },
        '0xe449022e' => { name: 'unoswap', type: 'swap' }
      }
    },

    # Compound cUSDC
    '0x39aa39c021dfbae8fac545936693ac917d5e7563' => {
      name: 'Compound cUSDC',
      category: 'DeFi',
      functions: {
        '0xa0712d68' => { name: 'mint', type: 'lending' },
        '0xdb006a75' => { name: 'redeem', type: 'lending' },
        '0x852a12e3' => { name: 'redeemUnderlying', type: 'lending' }
      }
    },

    # USDT Contract
    '0xdac17f958d2ee523a2206206994597c13d831ec7' => {
      name: 'USDT',
      category: 'Token',
      functions: {
        '0xa9059cbb' => { name: 'transfer', type: 'transfer' },
        '0x23b872dd' => { name: 'transferFrom', type: 'transfer' },
        '0x095ea7b3' => { name: 'approve', type: 'approval' }
      }
    },

    # OpenSea Wyvern Exchange (legacy)
    '0x7be8076f4ea4a4ad08075c2508e481d6c946d12b' => {
      name: 'OpenSea Wyvern',
      category: 'NFT',
      functions: {
        '0xab834bab' => { name: 'atomicMatch', type: 'trade' }
      }
    },

    # Synthetix Proxy
    '0xc011a73ee8576fb46f5e1c5751ca3b9fe0af2a6f' => {
      name: 'Synthetix Proxy',
      category: 'DeFi',
      functions: {
        '0xcee2261c' => { name: 'exchange', type: 'swap' }
      }
    }
  }.freeze

  # ERC-20 Standard function signatures
  ERC20_FUNCTIONS = {
    '0xa9059cbb' => { name: 'transfer', type: 'transfer' },
    '0x23b872dd' => { name: 'transferFrom', type: 'transfer' },
    '0x095ea7b3' => { name: 'approve', type: 'approval' }
  }.freeze

  # ERC-721 Standard function signatures
  ERC721_FUNCTIONS = {
    '0x23b872dd' => { name: 'transferFrom', type: 'nft_transfer' },
    '0x42842e0e' => { name: 'safeTransferFrom', type: 'nft_transfer' },
    '0xb88d4fde' => { name: 'safeTransferFrom', type: 'nft_transfer' },
    '0x095ea7b3' => { name: 'approve', type: 'nft_approval' },
    '0xa22cb465' => { name: 'setApprovalForAll', type: 'nft_approval' }
  }.freeze

  # Known event signatures (full keccak hash)
  EVENT_SIGNATURES = {
    '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef' => {
      name: 'Transfer',
      category: 'Token',
      description: 'Token transfer (ERC-20/721/1155)'
    },
    '0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925' => {
      name: 'Approval',
      category: 'Token',
      description: 'Token approval'
    },
    '0xd78ad95fa46c994b6551d0da85fc275fe613ce37657fb8d5e3d130840159d822' => {
      name: 'Swap',
      category: 'DeFi',
      description: 'Uniswap V2 token swap'
    },
    '0xc42079f94a6350d7e6235f29174924f928cc2ac818eb64fed8004e115fbcca67' => {
      name: 'Swap',
      category: 'DeFi',
      description: 'Uniswap V3 token swap'
    },
    '0x7e1db2a5ca5f333392285e7c4aec4cf0e5bdc675bc4dddf151b12d0c96778d93' => {
      name: 'Deposit',
      category: 'DeFi',
      description: 'Deposit event (common in lending/vaults)'
    },
    '0x4c209b5fc8ad50758f13e2e1088ba56a560dff690a1c6fef26394f4c03821c4f' => {
      name: 'Mint',
      category: 'Token',
      description: 'Token mint'
    },
    '0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31' => {
      name: 'ApprovalForAll',
      category: 'NFT',
      description: 'Set approval for all (ERC-721/1155)'
    },
    '0xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c' => {
      name: 'Deposit',
      category: 'DeFi',
      description: 'WETH deposit'
    },
    '0x7fcf532c15f0a6db0bd6d0e038bea71d30d808c7d98cb3bf7268a95bf5081b65' => {
      name: 'Withdrawal',
      category: 'DeFi',
      description: 'WETH withdrawal'
    }
  }.freeze

  def decode_transaction(tx)
    return ['transfer', 'EOA Transfer'] if tx['input'] == '0x' && (tx['value'] || '0x0').to_i(16) > 0

    return nil unless tx['input'] && tx['input'].length >= 10
    
    to_address = tx['to']&.downcase
    input_data = tx['input']
    function_signature = input_data[0..9]
    value_eth = ((tx['value'] || '0x0').to_i(16) / 1e18).round(6)
    
    decoded_info = {
      hash: tx['hash'],
      to: tx['to'],
      value_eth: value_eth,
      function_signature: function_signature,
      contract_name: 'Unknown',
      function_name: 'unknown',
      activity_type: 'contract_call',
      category: 'Other'
    }

    if contract_info = CONTRACTS[to_address]
      if function_info = contract_info[:functions][function_signature]
        decoded_info.merge!(
          contract_name: contract_info[:name],
          function_name: function_info[:name],
          activity_type: function_info[:type],
          category: contract_info[:category]
        )
        return decoded_info
      else
        decoded_info.merge!(
          contract_name: contract_info[:name],
          function_name: 'unknown',
          activity_type: 'contract_call',
          category: contract_info[:category]
        )
        return decoded_info
      end
    end

    if function_info = ERC20_FUNCTIONS[function_signature]
      decoded_info.merge!(
        contract_name: 'ERC-20 Token',
        function_name: function_info[:name],
        activity_type: function_info[:type],
        category: 'Token'
      )
      return decoded_info
    end

    if function_info = ERC721_FUNCTIONS[function_signature]
      decoded_info.merge!(
        contract_name: 'ERC-721 NFT',
        function_name: function_info[:name],
        activity_type: function_info[:type],
        category: 'NFT'
      )
      return decoded_info
    end

    short_address = to_address ? "#{to_address[0..5]}...#{to_address[-4..-1]}" : 'Contract Creation'
    decoded_info[:contract_name] = short_address
    decoded_info[:category] = 'Contract'
    decoded_info
  end

  def decode_event_signature(signature, log, tx)
    if event_info = EVENT_SIGNATURES[signature]
      {
        signature: signature,
        name: event_info[:name],
        category: event_info[:category],
        description: event_info[:description],
        contract_address: log['address'],
        transaction_hash: tx['hash'],
        topics: log['topics'],
        data: log['data']
      }
    else
      {
        signature: signature,
        name: 'unknown',
        category: 'Unknown',
        description: 'Unknown event',
        contract_address: log['address'],
        transaction_hash: tx['hash'],
        topics: log['topics'],
        data: log['data']
      }
    end
  end

  def categorize_block_activities(transactions)
    activities = {
      defi_count: 0,
      nft_count: 0,
      token_count: 0,
      other_count: 0,
      total_eth_volume: 0.0,
      top_activities: []
    }

    transactions.each do |tx|
      decoded = decode_transaction(tx)
      next unless decoded
      
      # Handle both array and hash return formats from decode_transaction
      if decoded.is_a?(Array)
        # Handle array format: ['transfer', 'EOA Transfer']
        activity_type, contract_name = decoded
        value_eth = ((tx['value'] || '0x0').to_i(16) / 1e18).round(6)
        category = 'Transfer'
        function_name = 'transfer'
        hash = tx['hash']
      else
        # Handle hash format
        activity_type = decoded[:activity_type]
        contract_name = decoded[:contract_name]
        value_eth = decoded[:value_eth]
        category = decoded[:category]
        function_name = decoded[:function_name]
        hash = decoded[:hash]
      end

      case category
      when 'DeFi'
        activities[:defi_count] += 1
      when 'NFT'
        activities[:nft_count] += 1
      when 'Token'
        activities[:token_count] += 1
      else
        activities[:other_count] += 1
      end
      
      activities[:total_eth_volume] += value_eth
      
      should_include = value_eth > 0.1 || ['DeFi', 'NFT'].include?(category) || !(contract_name.to_s.start_with?('Unknown') || contract_name.to_s.start_with?('0x'))
      
      if should_include
        activities[:top_activities] << {
          type: activity_type,
          contract: contract_name,
          function: function_name,
          value: value_eth,
          category: category,
          hash: hash[0..9] + '...'
        }
      end
    end

    activities[:top_activities] = activities[:top_activities].sort_by do |a|
      [
        a[:value] > 0.1 ? 0 : 1,
        ['DeFi', 'NFT'].include?(a[:category]) ? 0 : 1,
        !a[:contract].to_s.start_with?('0x') ? 0 : 1,
        -a[:value]
      ]
    end.first(10)

    activities
  end

  def get_popular_contracts
    CONTRACTS.map do |address, info|
      {
        address: address,
        name: info[:name],
        category: info[:category]
      }
    end
  end
end