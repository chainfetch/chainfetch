class EmailConfirmationsController < ApplicationController
  allow_unauthenticated_access only: %i[show new create]

  def show
    @user = User.find_by(email_confirmation_token: params[:token])
    
    if @user.nil?
      redirect_to new_session_path, alert: "❌ Invalid or expired confirmation token. Please request a new confirmation email."
    elsif @user.email_confirmed?
      redirect_to new_session_path, notice: "✅ Your email is already confirmed! You can sign in now."
    elsif @user.confirmation_token_expired?
      redirect_to new_email_confirmation_path(email: @user.email_address), 
                  alert: "⏰ Your confirmation link has expired (links expire after 24 hours). Please request a new one below."
    else
      @user.confirm_email!
      redirect_to new_session_path, notice: "🎉 Email confirmed successfully! Welcome to the platform. You can now sign in to your account."
    end
  end

  def new
    @email = params[:email]
  end

  def create
    @user = User.find_by(email_address: params[:email])
    
    if @user&.email_confirmed?
      redirect_to new_session_path, notice: "✅ Your email is already confirmed. You can sign in now."
    elsif @user
      @user.resend_email_confirmation
      redirect_to new_session_path, notice: "📧 Confirmation email sent to #{params[:email]}! Please check your inbox (and spam folder) and click the confirmation link."
    else
      redirect_to new_email_confirmation_path, alert: "❌ No account found with that email address. Please check your email or sign up for a new account."
    end
  end
end 