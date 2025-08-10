class Admin::BaseController < ApplicationController
  before_action :check_admin
  layout "admin"

  private

  def check_admin
    redirect_to root_path unless Current.user.role == "admin"
  end
end