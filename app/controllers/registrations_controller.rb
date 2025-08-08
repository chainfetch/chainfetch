class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  before_action :resume_session, only: %i[new create]

  def new
    redirect_to app_root_path if Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    
    # Verify reCAPTCHA first
    unless verify_recaptcha(model: @user)
      flash.now[:alert] = "❌ Please complete the reCAPTCHA verification."
      render :new, status: :unprocessable_entity
      return
    end
    
    if @user.save
      redirect_to new_session_path, notice: "🎉 Welcome! We've sent a confirmation email to #{@user.email_address}. Please check your inbox and click the confirmation link to activate your account."
    else
      flash.now[:alert] = "Please fix the following errors: #{@user.errors.full_messages.join(', ')}"
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.expect(user: [ :email_address, :password, :password_confirmation ])
  end
end