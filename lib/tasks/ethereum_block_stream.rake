namespace :ethereum do
  desc 'Start Ethereum Block Stream Service in Background'
  task start_block_stream: :environment do
    puts "🚀 Starting Ethereum Block Stream Service..."
    
    # Simple background process without fork() to avoid macOS issues
    log_file = Rails.root.join('log', 'ethereum_block_stream.log')
    pid_file = Rails.root.join('tmp', 'pids', 'ethereum_block_stream.pid')
    
    # Use system with background operator - simple and reliable
    system("nohup rails runner 'EthereumBlockStreamService.instance.start' > #{log_file} 2>&1 & echo $! > #{pid_file}")
    
    pid = File.read(pid_file).to_i
    puts "Ethereum Block Stream Service started with PID #{pid}"
  end

  desc 'Stop Ethereum Block Stream Service'
  task stop_block_stream: :environment do
    pid_file = Rails.root.join('tmp', 'pids', 'ethereum_block_stream.pid')
    if File.exist?(pid_file)
      pid = File.read(pid_file).to_i
      Process.kill("TERM", pid)
      File.delete(pid_file)
      puts "Ethereum Block Stream Service stopped (PID #{pid})"
    else
      puts "No PID file found. Is the service running?"
    end
  end
end
