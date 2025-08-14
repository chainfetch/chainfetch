class EthereumAlert < ApplicationRecord
  belongs_to :user
  enum :status, { active: 0, inactive: 1 }

  validates :address_hash, presence: true, format: { with: /\A0x[a-fA-F0-9]{40}\z/, message: "must be a valid Ethereum address" }
  validates :webhook_url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" }
  validates :status, presence: true
  validates :address_hash, uniqueness: { scope: :user_id, message: "alert already exists for this address" }

  def trigger_webhook(transaction_hash)
    EthereumAlertWebhookJob.perform_later(self.id, transaction_hash)
  end
end
