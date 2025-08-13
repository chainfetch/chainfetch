class Public::LandingController < Public::BaseController
  def index
    @latest_block = EthereumBlock.order(created_at: :desc).limit(1).first
  end
end