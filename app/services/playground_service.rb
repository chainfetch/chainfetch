class PlaygroundService < BaseService
  def initialize(params = nil)
    @params = params
  end

  def call
    token_counts = Hash.new(0)
    whale_addresses_info.each do |address|
      address["tokens_balance"].each do |token|
        symbol = token["symbol"]
        token_counts[symbol] += 1
      end
    end
    sorted_tokens = token_counts.sort_by { |_, count| -count }
    sorted_tokens.to_h
  end

  def whale_addresses_info
    Async do
      tasks = whale_addresses.map do |address_hash|
        Async { process_address(address_hash) }
      end
      tasks.map(&:wait)
    end.wait
  end

  private

  def process_address(address_hash)
    summary_task = Async { chainfetch_http("/api/v1/ethereum/addresses/summary", { "address_hash" => address_hash }) }
    address_info_task = Async { chainfetch_http("/api/v1/ethereum/addresses/#{address_hash}") }
    
    summary_result = summary_task.wait
    address_info_result = address_info_task.wait
    
    tokens_balance = extract_token_balances(address_info_result)
    
    result = {
      "address" => address_hash,
      "summary" => summary_result,
      "tokens_balance" => tokens_balance
    }
    
    result
  end

  def extract_token_balances(address_info)
    address_info.dig("token_balances")&.map do |token|
      {
        "address" => token.dig("token", "address_hash"),
        "symbol" => token.dig("token", "symbol"),
        "name" => token.dig("token", "name"),
        "balance" => token.dig("value")
      }
    end || []
  end

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

  def chainfetch_http(path, params = nil)
    base_url = "https://www.chainfetch.app"
    uri = URI.parse(base_url + path)
    uri.query = URI.encode_www_form(params) if params
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{Rails.application.credentials.chainfetch_api_token}"
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"
    
    response = http.request(request)
    JSON.parse(response.body)
  end
end