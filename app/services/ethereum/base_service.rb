class Ethereum::BaseService
  # Error classes
  class InvalidAddressError < StandardError; end
  class ApiError < StandardError; end
  class NotFoundError < ApiError; end

  BASE_URL = Rails.env.production? ? "https://www.chainfetch.app/api/v1" : "http://localhost:3000/api/v1"

  # Centralized helper to make all GET requests using Net::HTTP.
  def make_request(uri_string)
    uri = URI.parse(uri_string)
    http = Net::HTTP.new(uri.host, uri.port)
    # The following line should be enabled if your local API uses HTTPS
    # http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = 5  # Timeout for establishing a connection
    http.read_timeout = 15 # Timeout for receiving data

    request = Net::HTTP::Get.new(uri.request_uri)

    response = http.request(request)

    case response
    when Net::HTTPSuccess
      JSON.parse(response.body)
    when Net::HTTPNotFound
      raise NotFoundError, "Resource not found at #{uri_string}"
    else
      raise ApiError, "Internal API request to #{uri.host} failed with status #{response.code}: #{response.body}"
    end
  rescue JSON::ParserError => e
    raise ApiError, "Failed to parse JSON response from #{uri.host}: #{e.message}"
  rescue SocketError, Errno::ECONNREFUSED => e
    raise ApiError, "Network error connecting to internal API at #{uri.host}: #{e.message}"
  end
end