namespace :ethereum do
  desc 'Start Ethereum Transactions Stream Service in Background'
  task start_transactions_stream: :environment do
    puts "🚀 Starting Ethereum Transactions Stream Service..."
    
    # Simple background process without fork() to avoid macOS issues
    log_file = Rails.root.join('log', 'ethereum_transactions_stream.log')
    pid_file = Rails.root.join('tmp', 'pids', 'ethereum_transactions_stream.pid')
    
    # Ensure directories exist
    FileUtils.mkdir_p(File.dirname(log_file))
    FileUtils.mkdir_p(File.dirname(pid_file))
    
    # Use system with background operator - simple and reliable
    # Added stdbuf to disable output buffering for immediate log writes
    system("stdbuf -o0 -e0 nohup rails runner 'EthereumTransactionStreamService.instance.start' > #{log_file} 2>&1 & echo $! > #{pid_file}")
    
    sleep 1 # Give it a moment to start
    
    if File.exist?(pid_file)
      pid = File.read(pid_file).to_i
      puts "Ethereum Transactions Stream Service started with PID #{pid}"
      puts "📋 Log file: #{log_file}"
      puts "🔍 Monitor with: tail -f #{log_file}"
    else
      puts "❌ Failed to start service - no PID file created"
    end
  end

  desc 'Stop Ethereum Transactions Stream Service'
  task stop_transactions_stream: :environment do
    pid_file = Rails.root.join('tmp', 'pids', 'ethereum_transactions_stream.pid')
    if File.exist?(pid_file)
      pid = File.read(pid_file).to_i
      begin
        Process.kill("TERM", pid)
        File.delete(pid_file)
        puts "Ethereum Transactions Stream Service stopped (PID #{pid})"
      rescue Errno::ESRCH
        puts "Process #{pid} not found - cleaning up PID file"
        File.delete(pid_file)
      end
    else
      puts "No PID file found. Is the service running?"
    end
  end

  desc 'Check Ethereum Transactions Stream Service Status'
  task status_transactions_stream: :environment do
    pid_file = Rails.root.join('tmp', 'pids', 'ethereum_transactions_stream.pid')
    log_file = Rails.root.join('log', 'ethereum_transactions_stream.log')
    
    if File.exist?(pid_file)
      pid = File.read(pid_file).to_i
      begin
        Process.kill(0, pid) # Check if process exists
        puts "✅ Ethereum Transactions Stream Service is running (PID #{pid})"
        
        if File.exist?(log_file)
          puts "📋 Log file size: #{File.size(log_file)} bytes"
          puts "🕒 Last modified: #{File.mtime(log_file)}"
          puts "\n📄 Last 10 lines of log:"
          system("tail -10 #{log_file}")
        else
          puts "⚠️  Log file not found at #{log_file}"
        end
      rescue Errno::ESRCH
        puts "❌ Process #{pid} not found - service appears to be stopped"
        puts "🧹 Cleaning up stale PID file"
        File.delete(pid_file)
      end
    else
      puts "🔴 Ethereum Transactions Stream Service is not running (no PID file)"
    end
  end
end
