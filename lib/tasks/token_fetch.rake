namespace :tokens do
  desc "Fetch and create Ethereum tokens from Blockscout API"
  task fetch: :environment do
    puts "Starting token fetch from Blockscout API..."
    
    service = Ethereum::TokenFetchService.new
    result = service.fetch_and_create_tokens
    
    puts "✅ Token fetch completed!"
    puts "📊 Processed: #{result[:total_processed]} tokens"
    puts "🆕 Created: #{result[:created_count]} new tokens"
    puts "⏭️  Next page token: #{result[:next_page_token]}" if result[:next_page_token]
    
  rescue => e
    puts "❌ Error: #{e.message}"
    puts e.backtrace.first(5).join("\n") if e.backtrace
  end

  desc "Fetch tokens asynchronously using background jobs"
  task fetch_async: :environment do
    puts "Starting asynchronous token fetch..."
    TokenFetchJob.perform_later
    puts "✅ Token fetch job queued!"
  end

  desc "Fetch tokens with custom parameters"
  task :fetch_custom, [:limit, :types] => :environment do |t, args|
    options = {}
    options[:limit] = args[:limit].to_i if args[:limit].present?
    options[:types] = args[:types] if args[:types].present?
    
    puts "Starting token fetch with options: #{options}"
    
    service = Ethereum::TokenFetchService.new(options)
    result = service.fetch_and_create_tokens
    
    puts "✅ Token fetch completed!"
    puts "📊 Processed: #{result[:total_processed]} tokens"
    puts "🆕 Created: #{result[:created_count]} new tokens"
    puts "⏭️  Next page token: #{result[:next_page_token]}" if result[:next_page_token]
    
  rescue => e
    puts "❌ Error: #{e.message}"
    puts e.backtrace.first(5).join("\n") if e.backtrace
  end
end