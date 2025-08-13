module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      set_current_user || reject_unauthorized_connection
    end

    private
    def set_current_user
      token = request.params[:token] || request.headers['Authorization']&.split(' ')&.last
      if token.present?
        user = User.find_by(api_token: token)
        return self.current_user = user if user && user.api_credit > 0
      end
      nil
    end
  end
end
