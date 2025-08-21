class Embedding::GeminiService < BaseService
  GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent"

  def initialize(text)
    @text = text
  end

  def embed_document
    generate_embedding('RETRIEVAL_DOCUMENT')
  end

  def embed_query
    generate_embedding('RETRIEVAL_QUERY')
  end

  private

  def generate_embedding(task_type)
    uri = URI(GEMINI_API_URL)
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    
    request = Net::HTTP::Post.new(uri)
    request["x-goog-api-key"] = Rails.application.credentials.gemini_api_key
    request['Content-Type'] = 'application/json'
    
    payload = {
      "model" => "models/gemini-embedding-001",
      "content" => { "parts" => [{ "text" => @text }] },
      "output_dimensionality" => 3072,
      "task_type" => task_type
    }
    
    request.body = payload.to_json
    response = http.request(request)
    
    if response.code == '200'
      result = JSON.parse(response.body)
      result.dig('embedding', 'values')
    else
      raise "Gemini API Error: #{response.code} #{response.message} - #{response.body}"
    end
  rescue => e
    raise "Gemini Embedding Error: #{e.class} - #{e.message}"
  end
end