class TokenPricingService
  PRICE_PER_1000_TOKENS_USD_CENTS = 100 # $1 = 100 cents
  LAMPORTS_PER_SOL = 1_000_000_000
  
  def self.current_sol_usd_price
    @current_sol_price ||= fetch_sol_price
  end
  
  def self.calculate_price_for_tokens(amount_tokens)
    return { error: "Invalid amount" } unless valid_token_amount?(amount_tokens)
    
    price_usd_cents = (amount_tokens / 1000.0 * PRICE_PER_1000_TOKENS_USD_CENTS).to_i
    sol_price_usd = current_sol_usd_price
    
    return { error: "Unable to fetch SOL price" } if sol_price_usd <= 0
    
    price_lamports = ((price_usd_cents / 100.0) / sol_price_usd * LAMPORTS_PER_SOL).to_i
    
    {
      price_usd_cents: price_usd_cents,
      price_lamports: price_lamports,
      sol_price_usd: sol_price_usd
    }
  end
  
  def self.refresh_sol_price!
    @current_sol_price = nil
    current_sol_usd_price
  end
  
  private
  
  def self.valid_token_amount?(amount_tokens)
    amount_tokens.is_a?(Integer) && amount_tokens > 0 && amount_tokens % 1000 == 0
  end
  
  def self.fetch_sol_price
    response = Net::HTTP.get(URI("https://api.coingecko.com/api/v3/simple/price?ids=solana&vs_currencies=usd"))
    JSON.parse(response).dig("solana", "usd").to_f
  rescue StandardError => e
    Rails.logger.error "Failed to fetch SOL price: #{e.message}"
    0
  end
end 