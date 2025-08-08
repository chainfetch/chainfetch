class ApplicationMailer < ActionMailer::Base
  default from: Rails.application.credentials.mailgun_smtp_username
  layout "mailer"
end
