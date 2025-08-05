class AddressSearchService
  def initialize(query, semantic_search_results, json_search_results)
    @query = query
    @semantic_results = semantic_search_results
    @json_results = json_search_results
    @client = Anthropic::Client.new(api_key: Rails.application.credentials.anthropic_api_key)
  end

  def call
    return "No relevant blockchain data found" if @semantic_results.empty? && @json_results.empty?
    
    response = @client.messages.create(
      model: "claude-opus-4-1-20250805",
      max_tokens: 1500,
      messages: [
        {
          role: "user",
          content: build_prompt
        }
      ]
    )
    
    # Extract text from the Anthropic response
    text_content = response.content.find { |c| c.type == :text }
    text_content&.text || "Unable to process search results"
  rescue => e
    Rails.logger.error("AddressSearchService error: #{e.message}")
    "Error processing blockchain data query"
  end

  private

  def build_prompt
    <<~PROMPT
      You are analyzing search results from a blockchain address database to answer a specific user query.

      USER QUERY: "#{@query}"

      SEARCH RESULTS:

      SEMANTIC SEARCH (from Qdrant vector embeddings of address biographies):
      #{format_results(@semantic_results, "Vector Search")}

      JSON SEARCH (from PostgreSQL JSONB queries):
      #{format_results(@json_results, "JSON Search")}

      INSTRUCTIONS:
      1. ONLY use the provided search results - do not make up or hallucinate any information
      2. Focus specifically on answering the user's query: "#{@query}"
      3. If no relevant results are found, clearly state this
      4. If results are found, provide a concise summary focusing on:
         - Exact addresses that match the query criteria
         - Relevant token holdings, balances, or transaction data
         - Key patterns or insights directly related to the query

      RESPONSE FORMAT:
      - Start with a direct answer to the query
      - List specific addresses with relevant details
      - Keep the response focused and factual
      - Do not include unrelated information

      Answer the user's query based solely on the search results provided.
    PROMPT
  end

  def format_results(results, source_type)
    return "No results found" if results.empty?
    
    results.map.with_index do |result, index|
      "#{index + 1}. [#{source_type}] #{result.inspect}"
    end.join("\n")
  end
end