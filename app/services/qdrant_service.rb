class QdrantService < BaseService
  BASE_URL = Rails.env.production? ? 'http://qdrant-cluster.qdrant.svc.cluster.local:6333' : 'http://localhost:6333'

  def initialize
    @base_uri = URI(BASE_URL)
    @headers = { "Content-Type" => "application/json" }
  end

  # Creates a new collection in Qdrant.
  #
  # @param name [String] The name of the collection.
  # @param vector_size [Integer] The dimensionality of the vectors.
  # @return [Hash] The parsed JSON response from the API.
  # QdrantService.new.create_collection(name: "addresses", vector_size: 1024)
  def create_collection(name:, vector_size:)
    uri = @base_uri.dup
    uri.path = "/collections/#{name}"

    payload = {
      vectors: {
        size: vector_size,
        distance: 'Cosine' # Or 'Dot', 'Euclid'
      },
      hnsw_config: {
        m: 16,
        ef_construct: 100,
        full_scan_threshold: 10
      }
    }

    response = http_request(uri, Net::HTTP::Put, payload)
    handle_response(response)
  end

  # Upserts (updates or inserts) a point in a collection.
  #
  # @param collection [String] The name of the collection.
  # @param id [String, Integer] The unique ID of the point.
  # @param vector [Array<Float>] The vector embedding.
  # @param payload [Hash] Additional data associated with the point.
  # @return [Hash] The parsed JSON response from the API.
  def upsert_point(collection:, id:, vector:, payload: {})
    uri = @base_uri.dup
    uri.path = "/collections/#{collection}/points"
    uri.query = 'wait=true' # Ensure the operation is completed before returning.

    payload_data = {
      points: [
        { id: id, vector: vector, payload: payload }
      ]
    }

    response = http_request(uri, Net::HTTP::Put, payload_data)
    handle_response(response)
  end


  def retrieve_point(collection:, id:)
    uri = @base_uri.dup
    uri.path = "/collections/#{collection}/points/#{id}"
    response = http_request(uri, Net::HTTP::Get)
    handle_response(response)
  end

  def query_points(collection:, query:, prefetch: nil, limit: 10)
    uri = @base_uri.dup
    uri.path = "/collections/#{collection}/points/query"
  
    body = {
      query: query,
      limit: limit,
      with_payload: true
    }
    body[:prefetch] = prefetch if prefetch
  
    response = http_request(uri, Net::HTTP::Post, body)
    handle_response(response)
  end

  def collection_info(name)
    uri = @base_uri.dup
    uri.path = "/collections/#{name}"

    response = http_request(uri, Net::HTTP::Get)
    handle_response(response)
  end

  # Deletes a collection in Qdrant.
  #
  # @param name [String] The name of the collection.
  # @return [Hash] The parsed JSON response from the API.
  def delete_collection(name)
    uri = @base_uri.dup
    uri.path = "/collections/#{name}"

    response = http_request(uri, Net::HTTP::Delete)
    handle_response(response)
  end


  private

  def http_request(uri, request_class, payload = nil)
    request = request_class.new(uri)
    @headers.each { |key, value| request[key] = value }
    request.body = payload.to_json if payload

    Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end
  rescue => e
    error_message = "Qdrant Connection Error: #{e.class.name} - #{e.message}"
    Rails.logger.error(error_message) if defined?(Rails)
    raise error_message
  end

  def handle_response(response)
    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      error_message = "Qdrant API Error: #{response.code} #{response.message} - #{response.body}"
      Rails.logger.error(error_message) if defined?(Rails)
      raise error_message
    end
  rescue JSON::ParserError => e
    error_message = "Qdrant JSON Parse Error: #{e.message} - Body: #{response.body}"
    Rails.logger.error(error_message) if defined?(Rails)
    raise error_message
  end

end