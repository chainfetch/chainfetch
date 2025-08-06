Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'  # For development, allow all origins. Restrict this in production.
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true  # Set to `true` if using cookies or authentication headers.
  end
end
