class EmbeddingService < BaseService
  
  def initialize(text)
    @text = text
  end

  def call
    uri = URI("http://localhost:11434/v1/embeddings")
    
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    
    payload = {
      model: "dengcao/Qwen3-Embedding-4B:F16",
      input: @text
    }
    request.body = payload.to_json
    
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end
    
    if response.is_a?(Net::HTTPSuccess)
      result = JSON.parse(response.body)
      embedding = result.dig("data", 0, "embedding")
      
      unless embedding
        error_message = "Embedding not found in Ollama response: #{response.body}"
        Rails.logger.error(error_message) if defined?(Rails)
        raise error_message
      end
      
      return embedding
    else
      error_message = "Ollama API Error: #{response.code} #{response.message} - #{response.body}"
      Rails.logger.error(error_message) if defined?(Rails)
      raise error_message
    end
  rescue => e
    error_message = "Ollama Embedding Error: #{e.class.name} - #{e.message}"
    Rails.logger.error(error_message) if defined?(Rails)
    raise error_message
  end
end