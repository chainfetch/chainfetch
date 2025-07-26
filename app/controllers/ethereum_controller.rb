class EthereumController < ApplicationController
  def index
    # Get current service status
    @service_running = EthereumStreamService.instance.running?
  end
end 