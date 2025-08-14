class App::EthereumAlertsController < App::BaseController
  before_action :set_ethereum_alert, only: [:show, :edit, :update, :destroy]

  def index
    @ethereum_alerts = Current.user.ethereum_alerts.order(created_at: :desc)
  end

  def show
  end

  def new
    @ethereum_alert = Current.user.ethereum_alerts.build
  end

  def edit
  end

  def create
    @ethereum_alert = Current.user.ethereum_alerts.build(ethereum_alert_params)

    respond_to do |format|
      if @ethereum_alert.save
        @ethereum_alerts = Current.user.ethereum_alerts.order(created_at: :desc)
        format.turbo_stream { 
          render turbo_stream: [
            turbo_stream.replace("ethereum_alerts_list", partial: "alerts_list"),
            turbo_stream.replace("alert_form", "")
          ]
        }
      else
        format.turbo_stream { 
          render turbo_stream: [
            turbo_stream.replace("alert_form", partial: "form")
          ]
        }
      end
    end
  end

  def update
    respond_to do |format|
      if @ethereum_alert.update(ethereum_alert_params)
        @ethereum_alerts = Current.user.ethereum_alerts.order(created_at: :desc)
        format.turbo_stream { 
          render turbo_stream: [
            turbo_stream.replace("ethereum_alerts_list", partial: "alerts_list"),
            turbo_stream.replace("alert_form", "")
          ]
        }
      else
        format.turbo_stream { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @ethereum_alert.destroy
    @ethereum_alerts = Current.user.ethereum_alerts.order(created_at: :desc)
    
    respond_to do |format|
      format.turbo_stream { 
        render turbo_stream: turbo_stream.replace("ethereum_alerts_list", partial: "alerts_list")
      }
    end
  end

  private

  def set_ethereum_alert
    @ethereum_alert = Current.user.ethereum_alerts.find(params[:id])
  end

  def ethereum_alert_params
    params.require(:ethereum_alert).permit(:address_hash, :webhook_url, :status)
  end
end