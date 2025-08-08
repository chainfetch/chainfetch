module App
  class TokenPurchasesController < App::BaseController
    before_action :require_authentication

    # POST /app/buy_token
    def create
      purchase_params = params.require(:token_purchase).permit(:token_amount, :sol_amount, :transaction_signature)
      amount_tokens = purchase_params[:token_amount].to_i

      return render json: { error: "Invalid token amount" }, status: :unprocessable_entity unless valid_token_amount?(amount_tokens)
      return render json: { error: verifier.error_message }, status: :unprocessable_entity unless (verifier = verify_transaction(purchase_params)).valid?

      Current.user.increment!(:api_credit, amount_tokens)
      record_payment(amount_tokens, purchase_params[:transaction_signature])

      render json: { success: true, new_credit: Current.user.api_credit }
    end

    def sol_price
      render json: { sol_price_usd: TokenPricingService.current_sol_usd_price }
    end

    def set_solana_key
      return head :bad_request if params[:public_key].blank?
      
      Current.user.update!(solana_public_key: params[:public_key])
      head :ok
    end

    private

    def valid_token_amount?(amount)
      amount.positive? && amount >= 3000
    end

    def verify_transaction(purchase_params)
      verifier = SolanaTransactionVerifier.new(signature: purchase_params[:transaction_signature]).call
      Rails.logger.warn "Token purchase rejected – #{verifier.error_message} (user ##{Current.user.id})" unless verifier.valid?
      verifier
    end

    def record_payment(amount_tokens, signature)
      amount_usd = (amount_tokens / 1000.0) * 1
      amount_cents = (amount_usd * 100).round
      
      Payment.create!(
        user: Current.user,
        stripe_payment_intent_id: "solana_#{signature}",
        amount_cents: amount_cents,
        credits: amount_tokens,
        status: 'succeeded'
      )
    rescue => e
      Rails.logger.error "Failed to record SOL payment: #{e.message}"
    end
  end
end 