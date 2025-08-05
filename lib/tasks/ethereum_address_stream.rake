namespace :ethereum do
  desc 'Start Ethereum Address Stream Service in Background'
  task start_address_stream: :environment do
    puts "🚀 Starting Ethereum Address Stream Service..."
    
    # Simple background process without fork() to avoid macOS issues
    log_file = Rails.root.join('log', 'ethereum_address_stream.log')
    pid_file = Rails.root.join('tmp', 'pids', 'ethereum_address_stream.pid')
    
    # Use system with background operator - simple and reliable
    system("nohup rails runner 'EthereumAddressStreamService.instance.start' > #{log_file} 2>&1 & echo $! > #{pid_file}")
    
    pid = File.read(pid_file).to_i
    puts "Ethereum Address Stream Service started with PID #{pid}"
  end

  desc 'Stop Ethereum Address Stream Service'
  task stop_address_stream: :environment do
    pid_file = Rails.root.join('tmp', 'pids', 'ethereum_address_stream.pid')
    if File.exist?(pid_file)
      pid = File.read(pid_file).to_i
      Process.kill("TERM", pid)
      File.delete(pid_file)
      puts "Ethereum Address Stream Service stopped (PID #{pid})"
    else
      puts "No PID file found. Is the service running?"
    end
  end
end
