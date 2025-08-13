class Public::LandingController < Public::BaseController
  def index
    @latest_block = EthereumBlock.where.not(summary: nil).order(created_at: :desc).limit(1).first
  end
end