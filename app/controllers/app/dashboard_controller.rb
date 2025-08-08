class App::DashboardController < App::BaseController
  def index
  end
  def regenerate_api_key
    new_token = Current.user.regenerate_api_token!
    render json: { api_token: new_token, message: "API key regenerated successfully" }
  rescue => e
    render json: { error: "Failed to regenerate API key" }, status: :unprocessable_entity
  end
end