class ApiSession < ApplicationRecord
  belongs_to :user

  def set_credit(usd_cost)
    credit_cost = api_session_cost(usd_cost)
    update!(cost: credit_cost)
    user.decrement!(:api_credit, credit_cost)
  end
  
  def api_session_cost(usd_cost = nil)
    # case request_params["controller"]
    # when "api/v1/serp"
    #   request_params["pages_number"].present? ? request_params["pages_number"].to_i : 1
    # else
    #   return 0
    # end
    1
  end
end
