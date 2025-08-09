class Api::V1::Ethereum::BaseController < Api::V1::BaseController
  def blockscout_api_get(endpoint)
    blockscout_api_url = "https://eth.blockscout.com/api/v2"
    uri = URI("#{blockscout_api_url}#{endpoint}")
    
    retries = 0
    max_retries = 3
    
    begin
      proxy = proxy_config
      
      response = Thread.new do
        Net::HTTP.start(
          uri.host, 
          uri.port,
          proxy[:server].split(':')[0],
          proxy[:server].split(':')[1].to_i,
          proxy[:username],
          proxy[:password],
          use_ssl: uri.scheme == 'https'
        ) do |http|
          request = Net::HTTP::Get.new(uri)
          http.request(request)
        end
      end.value
      
      JSON.parse(response.body)
    rescue OpenSSL::SSL::SSLError => e
      retries += 1
      if retries <= max_retries
        Rails.logger.warn "SSL error on attempt #{retries}/#{max_retries}: #{e.message}"
        sleep(0.5 * retries) # Progressive backoff: 0.5s, 1s, 1.5s
        retry
      else
        Rails.logger.error "SSL error after #{max_retries} retries: #{e.message}"
        { error: "SSL connection failed after #{max_retries} retries: #{e.message}" }
      end
    rescue JSON::ParserError
      { error: "Failed to parse response from Block explorer API" }
    rescue => e
      { error: e.message }
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