require "net/http"
require "json"
require "openssl"

# This service automates the discovery of interesting tokens by analyzing the activity of "smart money" wallets.
# It uses the Chainfetch MCP server for blockchain data and applies heuristics to identify promising tokens.
#
# How it works:
# 1. It finds wallets with a high ETH balance and a high transaction count ("smart money").
# 2. It analyzes the token holdings of one of these wallets.
# 3. It filters out common, well-known tokens (e.g., stablecoins, top meme coins) to focus on lesser-known assets.
# 4. It ranks the remaining tokens by their approximate USD value to find the most significant holdings.
# 5. For the top-ranked tokens, it fetches detailed information and an AI-generated summary from Chainfetch.
#
#   - Make sure your Chainfetch API key is set up in Rails credentials.
#
# Example usage:
#   service = InterestingTokensService.new
#   results = service.call
#   puts JSON.pretty_generate(results)
#
class InterestingTokensService
  # Remove MCP_SERVER_URL and add the base URL for the Chainfetch API
  CHAINFETCH_API_URL = "https://www.chainfetch.app".freeze
  # List of common/major token symbols to ignore during analysis.
  IGNORE_LIST = %w[WETH USDT USDC DAI SHIB PEPE WBTC WMATIC].freeze

  def initialize
    # Assumes API key is stored in Rails' encrypted credentials.
    # To edit credentials: `rails credentials:edit`
    @chainfetch_api_token = Rails.application.credentials.chainfetch_api_token
  end

  # Main method to run the analysis pipeline.
  def call
    # Step 1: Find smart money wallets
    wallets = whale_addresses
    if wallets.empty?
      return [ { error: "Could not find any smart money wallets matching the criteria." } ]
    end

    # Take the top 10 wallets for analysis
    wallets_to_analyze = wallets.first(10)

    # Process each wallet and collect the results
    results = wallets_to_analyze.map do |wallet|
      # Step 2: Analyze the wallet to find interesting tokens
      interesting_tokens = analyze_wallet_for_interesting_tokens(wallet)
      next if interesting_tokens.empty?

      # Step 3: Get summary for each interesting token
      found_tokens = interesting_tokens.map do |token|
        contract_address = token["contract_address"]
        {
          token_info: token,
          summary: get_token_summary(contract_address)
        }
      end

      {
        analyzed_wallet: wallet,
        found_tokens: found_tokens
      }
    end.compact # Remove nil entries for wallets with no interesting tokens

    results
  end

  private

  # Finds wallets with high ETH balance and transaction count using the Chainfetch API.
  def whale_addresses
    addresses = []
    page = 1

    while page <= 10
      response = chainfetch_http("/api/v1/ethereum/addresses/json_search", {
        "eth_balance_min" => 1000,
        "transactions_count_min" => 5000,
        "is_contract" => false,
        "limit" => 50,
        "page" => page
      })

      items = response.dig("results") || []
      break if items.empty?

      addresses.concat(items)
      page += 1
    end

    addresses
  end

  # Identifies interesting tokens based on heuristics, avoiding common, well-known tokens.
  def analyze_wallet_for_interesting_tokens(wallet_address)
    puts "Analyzing wallet #{wallet_address} for interesting tokens..."
    address_info = get_address_info(wallet_address)
    return [] unless address_info && address_info["token_balances"]

    token_balances = address_info["token_balances"]

    # Filter out tokens from the ignore list.
    interesting_tokens = token_balances.reject do |balance|
      symbol = balance.dig("token", "symbol")
      symbol.nil? || IGNORE_LIST.include?(symbol.upcase)
    end

    # Sort by approximate USD value (value * exchange_rate) in descending order.
    interesting_tokens.sort_by! do |balance|
      value = balance["value"].to_f
      rate = balance.dig("token", "exchange_rate").to_f
      decimals = balance.dig("token", "decimals").to_i

      usd_value = (rate > 0 && decimals > 0) ? (value / (10**decimals)) * rate : 0
      -usd_value # Negate for descending sort
    end

    # Return the top 3 promising tokens with a simplified structure.
    interesting_tokens.first(3).map do |balance|
      {
        "contract_address" => balance.dig("token", "address_hash"),
        "name" => balance.dig("token", "name"),
        "symbol" => balance.dig("token", "symbol"),
        "reason" => "High-value token held by a smart money wallet, excluding common tokens."
      }
    end
  end

  # Fetches general information about an address from the Chainfetch API.
  def get_address_info(address)
    puts "Fetching info for address: #{address}"
    chainfetch_http("/api/v1/ethereum/addresses/#{address}.json")
  end

  # Fetches detailed information for a specific token from the Chainfetch API.
  def get_token_details(contract_address)
    puts "Getting details for token #{contract_address}..."
    chainfetch_http("/api/v1/ethereum/tokens/#{contract_address}.json")
  end

  # Fetches an AI-generated summary for a specific token from the Chainfetch API.
  def get_token_summary(contract_address)
    puts "Getting summary for token #{contract_address}..."
    chainfetch_http("/api/v1/ethereum/tokens/summary.json", { token_address: contract_address })
  end

  # Helper method to make authenticated HTTP GET requests to the Chainfetch API.
  def chainfetch_http(path, params = nil)
    uri = URI.parse(CHAINFETCH_API_URL + path)
    uri.query = URI.encode_www_form(params) if params

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{@chainfetch_api_token}"
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"

    response = http.request(request)
    JSON.parse(response.body)
  rescue StandardError => e
    { "error" => "Failed to call Chainfetch API: #{e.message}" }
  end
end
