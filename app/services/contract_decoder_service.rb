require 'json'
require 'net/http'
require 'uri'

class ContractDecoderService
  include Singleton

  def initialize
    # No longer need caching or RPC endpoint since we only use hardcoded contracts
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

    # USDC Contract (fixed address)
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

  def decode_transaction(tx)
    return nil unless tx['input'] && tx['input'].length >= 10
    
    to_address = tx['to']&.downcase
    input_data = tx['input']
    function_signature = input_data[0..9] # First 4 bytes (0x + 8 chars)
    value_eth = (tx['value'].to_i(16) / 1e18).round(6)
    
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

    # Check known contracts first
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
        # Even if function is unknown, use the contract name
        decoded_info.merge!(
          contract_name: contract_info[:name],
          function_name: 'unknown',
          activity_type: 'contract_call',
          category: contract_info[:category]
        )
        return decoded_info
      end
    end

    # Check ERC-20 functions
    if ERC20_FUNCTIONS.key?(function_signature)
      function_info = ERC20_FUNCTIONS[function_signature]
      decoded_info.merge!(
        contract_name: 'ERC-20 Token',
        function_name: function_info[:name],
        activity_type: function_info[:type],
        category: 'Token'
      )
      return decoded_info
    end

    # Check ERC-721 functions
    if ERC721_FUNCTIONS.key?(function_signature)
      function_info = ERC721_FUNCTIONS[function_signature]
      decoded_info.merge!(
        contract_name: 'ERC-721 NFT',
        function_name: function_info[:name],
        activity_type: function_info[:type],
        category: 'NFT'
      )
      return decoded_info
    end

    # For any other contract call, use shortened address
    short_address = "#{to_address[0..5]}...#{to_address[-4..-1]}"
    decoded_info[:contract_name] = short_address
    decoded_info[:category] = 'Contract'

    # Default for any contract interaction
    decoded_info
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
      next unless tx['to'] && tx['input'] && tx['input'] != '0x'
      
      decoded = decode_transaction(tx)
      next unless decoded
      
      # Count by category
      case decoded[:category]
      when 'DeFi'
        activities[:defi_count] += 1
      when 'NFT'
        activities[:nft_count] += 1
      when 'Token'
        activities[:token_count] += 1
      else
        activities[:other_count] += 1
      end
      
      # Track ETH volume
      activities[:total_eth_volume] += decoded[:value_eth]
      
      # Collect notable activities - only include interesting ones
      should_include = false
      
      # Include high-value transactions
      should_include = true if decoded[:value_eth] > 0.1
      
      # Include DeFi and NFT activities from known contracts
      should_include = true if ['DeFi', 'NFT'].include?(decoded[:category])
      
      # Include known contracts (not generic ERC-20/721)
      should_include = true if decoded[:contract_name] && 
                              !['ERC-20 Token', 'ERC-721 NFT'].include?(decoded[:contract_name]) &&
                              !decoded[:contract_name].start_with?('0x')
      
      if should_include
        activity_entry = {
          type: decoded[:activity_type],
          contract: decoded[:contract_name],
          function: decoded[:function_name],
          value: decoded[:value_eth],
          category: decoded[:category],
          hash: decoded[:hash][0..9] + '...'
        }
        
        activities[:top_activities] << activity_entry
      end
    end

    # Sort top activities by priority and limit to 10
    activities[:top_activities] = activities[:top_activities]
      .sort_by do |a| 
        [
          a[:value] > 0.1 ? 0 : 1,  # High value transactions first
          ['DeFi', 'NFT'].include?(a[:category]) ? 0 : 1,  # DeFi/NFT second
          !a[:contract].start_with?('0x') ? 0 : 1,  # Named contracts third
          -a[:value]  # Then by value descending
        ]
      end
      .first(10)

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