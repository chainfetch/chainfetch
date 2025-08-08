class UserMailer < ApplicationMailer
  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.user_mailer.email_confirmation.subject
  #
  def email_confirmation(user)
    @user = user
    @confirmation_url = confirm_email_url(token: @user.email_confirmation_token)
    
    mail(
      to: @user.email_address,
      subject: "Please confirm your email address"
    )
  end
end
