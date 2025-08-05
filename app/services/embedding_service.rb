
class EmbeddingService < BaseService
  OLLAMA_URL = "https://ollama.chainfetch.app"

  def initialize(text)
    @text = text
  end

  def call
    uri = URI("#{OLLAMA_URL}/api/embeddings")
    
    # Create HTTPS connection
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    
    # Create request with correct headers
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{Rails.application.credentials.auth_bearer_token}"
    request['Content-Type'] = 'application/json'
    
    # Correct payload format (matches working curl)
    payload = {
      model: "dengcao/Qwen3-Embedding-0.6B:Q8_0",
      prompt: @text
    }
    request.body = payload.to_json
    
    # Make request
    response = http.request(request)
    
    if response.code == '200'
      result = JSON.parse(response.body)
      result['embedding']  # Return the embedding array
    else
      raise "Ollama API Error: #{response.code} #{response.message} - #{response.body}"
    end
  rescue => e
    raise "Ollama Embedding Error: #{e.class} - #{e.message}"
  end
end