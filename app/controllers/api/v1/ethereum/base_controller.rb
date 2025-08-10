class Api::V1::Ethereum::BaseController < Api::V1::BaseController
  def blockscout_api_get(endpoint)
    blockscout_api_url = "https://eth.blockscout.com/api/v2"
    uri = URI("#{blockscout_api_url}#{endpoint}")
    
    retries = 0
    max_retries = 3
    
    begin
      proxy = proxy_config
      
      http = Net::HTTP.new(
        uri.host, 
        uri.port,
        proxy[:server].split(':')[0],
        proxy[:server].split(':')[1].to_i,
        proxy[:username],
        proxy[:password]
      )
      
      # Configure timeouts - more conservative values
      http.open_timeout = 15
      http.read_timeout = 45
      http.write_timeout = 15
      
      if uri.scheme == 'https'
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.ssl_version = :TLSv1_2
      end
      
      response = http.start do |connection|
        request = Net::HTTP::Get.new(uri)
        request['User-Agent'] = 'Chainfetch/1.0'
        request['Connection'] = 'close'
        connection.request(request)
      end
      
      if response.code.to_i >= 200 && response.code.to_i < 300
        JSON.parse(response.body)
      else
        Rails.logger.warn "API returned status #{response.code}: #{response.body}"
        { error: "API returned status #{response.code}" }
      end
      
    rescue Net::ReadTimeout => e
      retries += 1
      if retries <= max_retries
        Rails.logger.warn "Read timeout on attempt #{retries}/#{max_retries} for #{endpoint}: #{e.message}"
        sleep(1 * retries) # Progressive backoff: 1s, 2s, 3s
        retry
      else
        Rails.logger.error "Read timeout after #{max_retries} retries for #{endpoint}: #{e.message}"
        { error: "Request timed out after #{max_retries} retries" }
      end
    rescue Net::OpenTimeout => e
      retries += 1
      if retries <= max_retries
        Rails.logger.warn "Open timeout on attempt #{retries}/#{max_retries} for #{endpoint}: #{e.message}"
        sleep(1 * retries)
        retry
      else
        Rails.logger.error "Open timeout after #{max_retries} retries for #{endpoint}: #{e.message}"
        { error: "Connection timeout after #{max_retries} retries" }
      end
    rescue Net::WriteTimeout => e
      retries += 1
      if retries <= max_retries
        Rails.logger.warn "Write timeout on attempt #{retries}/#{max_retries} for #{endpoint}: #{e.message}"
        sleep(1 * retries)
        retry
      else
        Rails.logger.error "Write timeout after #{max_retries} retries for #{endpoint}: #{e.message}"
        { error: "Write timeout after #{max_retries} retries" }
      end
    rescue SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::ENETUNREACH => e
      retries += 1
      if retries <= max_retries
        Rails.logger.warn "Network error on attempt #{retries}/#{max_retries} for #{endpoint}: #{e.message}"
        sleep(2 * retries) # Longer backoff for network issues: 2s, 4s, 6s
        retry
      else
        Rails.logger.error "Network error after #{max_retries} retries for #{endpoint}: #{e.message}"
        { error: "Network connection failed after #{max_retries} retries" }
      end
    rescue OpenSSL::SSL::SSLError => e
      retries += 1
      if retries <= max_retries
        Rails.logger.warn "SSL error on attempt #{retries}/#{max_retries} for #{endpoint}: #{e.message}"
        sleep(1 * retries)
        retry
      else
        Rails.logger.error "SSL error after #{max_retries} retries for #{endpoint}: #{e.message}"
        { error: "SSL connection failed after #{max_retries} retries" }
      end
    rescue JSON::ParserError => e
      Rails.logger.error "JSON parse error for #{endpoint}: #{e.message}"
      { error: "Failed to parse response from Block explorer API" }
    rescue => e
      Rails.logger.error "Unexpected error for #{endpoint}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { error: "Unexpected error: #{e.message}" }
    end
  end

  def proxy_config
    {
      server: "ddc.oxylabs.io:#{rand(8001..8020)}",
      username: "#{Rails.application.credentials.datacenter_proxy_username}",
      password: "#{Rails.application.credentials.proxy_password}"
    }
  end
end