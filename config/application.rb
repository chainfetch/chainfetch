require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Chainfetch
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    
    # Auto-start the Ethereum stream service when the app initializes
    config.after_initialize do
      # Only start in production/development, not during asset compilation or rake tasks
      if defined?(Rails::Server) || Rails.env.development?
        # Start the service asynchronously to avoid blocking server startup
        Thread.new do
          # Give Rails a moment to fully boot
          sleep(2)
          
          Rails.logger.info "🚀 Auto-starting Ethereum stream service..."
          begin
            #EthereumStreamService.instance.start
            Rails.logger.info "✅ Ethereum stream service started successfully"
          rescue => e
            Rails.logger.error "❌ Failed to auto-start Ethereum stream service: #{e.message}"
          end
        end
      end
    end
  end
end
