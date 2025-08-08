class User < ApplicationRecord
  has_secure_password
  has_secure_token :api_token, length: 36
  has_secure_token :email_confirmation_token, length: 36
  has_many :sessions, dependent: :destroy
  has_many :api_sessions, dependent: :destroy
  before_create :add_api_credit
  after_create :send_email_confirmation

  enum :role, { user: 0, admin: 1 }

  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  validates :email_address, presence: true, uniqueness: true, format: { with: VALID_EMAIL_REGEX }
  validates :password_digest, presence: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  def is_admin?
    role == "admin"
  end

  def confirm_email!
    update!(
      email_confirmed: true,
      email_confirmation_token: nil,
      email_confirmation_sent_at: nil
    )
  end

  def confirmation_token_expired?
    return true unless email_confirmation_sent_at
    email_confirmation_sent_at < 24.hours.ago
  end

  def resend_email_confirmation
    regenerate_email_confirmation_token
    UserMailer.email_confirmation(self).deliver_now
    update!(email_confirmation_sent_at: Time.current)
  end

  def regenerate_api_token!
    regenerate_api_token
    save!
    api_token
  end

  private

  def add_api_credit
    self.api_credit = 50
  end

  def send_email_confirmation
    UserMailer.email_confirmation(self).deliver_now
    update!(email_confirmation_sent_at: Time.current)
  end
end
