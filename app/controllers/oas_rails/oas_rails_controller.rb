class OasRails::OasRailsController < ApplicationController
  # Include URL help if the layout is a user-customized layout.
  include Rails.application.routes.url_helpers
  before_action :set_current_user

  def index
    respond_to do |format|
      format.html { render "index" }
      format.json do
        render json: OasRails.build.to_json, status: :ok
      end
    end
  end

  private
  def set_current_user
    Current.session ||= Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
  end
end
