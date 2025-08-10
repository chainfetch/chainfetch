class Payment < ApplicationRecord
  belongs_to :user
  enum :status, { pending: 0, succeeded: 1, failed: 2 }
end
