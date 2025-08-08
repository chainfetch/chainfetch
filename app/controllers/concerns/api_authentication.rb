module ApiAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_api_token!
    after_action :update_api_credit!
  end

  private

  def authenticate_api_token!
    if api_token = request.headers["Authorization"]&.split(" ")&.last
      @user = User.find_by(api_token: api_token)
      
      unless @user
        render json: { error: "Invalid API Key." }, status: :unauthorized
        return
      end

      if @user.role == "admin"
        return
      end
      
      if @user.api_credit <= 0
        render json: { error: "Insufficient API credit." }, status: :payment_required
        return
      end
      
      if @user.api_sessions.where("created_at >= ?", 1.minute.ago).count >= 600
        render json: { error: "Rate limit exceeded." }, status: :too_many_requests
        return
      end
      
      Current.api_session = @user.api_sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip, endpoint: params.permit(:controller)[:controller], request_params: params)
    else
      render json: { error: "Missing Authorization header." }, status: :unauthorized
      return
    end
  end

  def update_api_credit!
    Current.api_session.set_credit(@usd_cost) if response.status == 200 && @user.role != "admin"
  end
end
