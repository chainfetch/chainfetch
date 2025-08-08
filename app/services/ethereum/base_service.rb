class Ethereum::BaseService
  require 'uri'
  require 'json'
  require 'net/http'
  require 'openssl'

  # Error classes
  class InvalidAddressError < StandardError; end
  class ApiError < StandardError; end
  class NotFoundError < ApiError; end

  BASE_URL = Rails.env.production? ? "https://www.chainfetch.app" : "http://localhost:3000"
  BEARER_TOKEN = Rails.env.production? ? "VDMUNS919mKXJGujkGQWwXZMEVPAWea2Xvqw" : "VDMUNS919mKXJGujkGQWwXZMEVPAWea2Xvqw"

end