class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :api_session

  def user
    session&.user || api_session&.user
  end
end
