class ApplicationJob < ActiveJob::Base
  BASE_URL = Rails.env.production? ? "https://www.chainfetch.app" : "http://localhost:3000"

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError
end
