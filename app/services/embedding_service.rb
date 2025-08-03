class EmbeddingService < BaseService
  def initialize(text)
    @text = text
  end

  def call
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent")
    api_key = Rails.application.credentials.gemini_api_key

    request = Net::HTTP::Post.new(uri)
    request["x-goog-api-key"] = api_key
    request["Content-Type"] = "application/json"

    payload = {
      model: "models/gemini-embedding-001",
      content: {
        parts: [{ text: @text }]
      },
      task_type: "RETRIEVAL_DOCUMENT"
    }
    request.body = payload.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      result = JSON.parse(response.body)
      embedding = result.dig("embedding", "values")

      unless embedding
        error_message = "Embedding not found in Gemini API response: #{response.body}"
        Rails.logger.error(error_message) if defined?(Rails)
        raise error_message
      end

      return embedding
    else
      error_message = "Gemini API Error: #{response.code} #{response.message} - #{response.body}"
      Rails.logger.error(error_message) if defined?(Rails)
      raise error_message
    end
  end
end