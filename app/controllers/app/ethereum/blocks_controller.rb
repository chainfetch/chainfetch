class App::Ethereum::BlocksController < ApplicationController
  def search
    @results = BlockDataSearchService.new(params[:query], full_json: true).call
  end
end