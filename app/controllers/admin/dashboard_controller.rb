class Admin::DashboardController < Admin::BaseController
  def index
    # Main metrics
    @blocks_count = EthereumBlock.count
    @transactions_count = EthereumTransaction.count
    @addresses_count = EthereumAddress.count
    @smart_contracts_count = EthereumSmartContract.count
    @tokens_count = EthereumToken.count
    
    # User metrics
    @users_count = User.count
    @admin_users_count = User.where(role: :admin).count
    @confirmed_users_count = User.where(email_confirmed: true).count
    @total_api_credits = User.sum(:api_credit)
    
    # Session metrics
    @sessions_count = Session.count
    @api_sessions_count = ApiSession.count
    @active_sessions_count = Session.joins(:user).where(users: { email_confirmed: true }).count
    
    # Payment metrics
    @payments_count = Payment.count
    @successful_payments_count = Payment.succeeded.count
    @total_revenue_cents = Payment.succeeded.sum(:amount_cents)
    @total_credits_sold = Payment.succeeded.sum(:credits)
    
    # Recent data
    @recent_users = User.order(created_at: :desc)
    @recent_sessions = Session.includes(:user).order(created_at: :desc)
    @recent_payments = Payment.includes(:user).order(created_at: :desc)
    
    # Latest blockchain data
    @latest_blocks = EthereumBlock.order(created_at: :desc)
    @latest_transactions = EthereumTransaction.includes(:ethereum_block).order(created_at: :desc)
    @latest_addresses = EthereumAddress.order(created_at: :desc)
  end
end