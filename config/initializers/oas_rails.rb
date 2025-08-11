# config/initializers/oas_rails.rb
OasRails.configure do |config|
  # Basic Information about the API
  config.info.title = 'ChainFETCH'
  config.info.version = '1.0.0'
  config.info.summary = 'OasRails: Automatic Interactive API Documentation for Rails'
  config.info.description = <<~HEREDOC
    # Welcome to ChainFetch

    **AI-powered Ethereum blockchain intelligence API** with advanced semantic search capabilities.

    ## Real-Time Blockchain Stream Intelligence

    ChainFetch operates at the heart of Ethereum's blockchain activity, creating a continuous stream of enriched blockchain intelligence:

    **🔥 Live Block Streaming**: WebSocket subscription to Ethereum's public nodes captures new blocks every ~12 seconds, instantly processing each block for comprehensive analysis.

    **⚡ Intelligent Data Pipeline**: Every new block triggers our asynchronous processing engine that:
    - Extracts and analyzes all transactions within each block
    - Discovers and profiles Ethereum addresses involved in transactions  
    - Builds comprehensive address interaction graphs
    - Generates AI-powered summaries for blocks, transactions, and addresses

    ## AI-Powered Semantic Search

    **🧠 Advanced Embedding Technology**: Leveraging Qwen3-Embedding-0.6B (Q8_0 quantized) model to transform blockchain data into high-dimensional vector embeddings that capture semantic meaning.

    **🎯 Qdrant Vector Database**: Ultra-fast vector similarity search across three specialized collections:
    - **Addresses Collection**: Semantic search across millions of Ethereum addresses
    - **Transactions Collection**: Find transactions by intent, pattern, or behavior  
    - **Blocks Collection**: Discover blocks by activity type and characteristics

    **🤖 LLM-Powered Query Processing**: LLaMA 3.2 3B model intelligently translates natural language queries into precise API parameters, supporting 150+ address parameters and 120+ block parameters.

    ## Advanced Search Capabilities

    **Natural Language Search**: Query blockchain data conversationally - "Find whale addresses that interacted with DeFi protocols" or "Show me high-gas transactions from yesterday"

    **Multi-Modal Search Options**:
    - **Semantic Search**: Vector similarity matching for conceptual queries
    - **LLM Search**: AI-assisted parameter selection for complex filtering
    - **JSON Search**: Direct parameter-based filtering with real-time data enrichment

    **Concurrent Processing**: Async/await architecture ensures lightning-fast responses even when processing thousands of data points simultaneously.

    ## Core Technologies

    - **Real-time WebSocket streams** for live blockchain monitoring
    - **Vector embeddings** with cosine similarity search  
    - **Kubernetes-native deployment** with auto-scaling
    - **Rate-limited API access** with authentication
    - **Comprehensive OpenAPI 3.1 documentation**

    Experience the future of blockchain intelligence - where real-time data meets AI-powered insights.

    ## Application Architecture & Data Flow

    ### 🚀 Bootstrap Process
    - **Service Initialization**: `EthereumBlockStreamService` singleton connects to `wss://ethereum-rpc.publicnode.com`
    - **Block Subscription**: Subscribes to `eth_subscribe ["newHeads"]` for real-time block notifications
    - **Continuous Monitoring**: Maintains persistent WebSocket connection for ~12-second block intervals

    ### 🧱 Block Processing Pipeline
    **New Block Detection** → **Database Record Creation** → **Background Job Trigger**
    
    1. **Block Stream**: WebSocket receives new block header → `EthereumBlock.find_or_create_by(block_number)`
    2. **Block Data Job**: `after_create_commit` callback → `BlockDataJob.perform_later`
    3. **Data Enrichment**: Fetches full block data → Generates AI summary → Creates vector embedding
    4. **Vector Storage**: Stores in Qdrant "blocks" collection for semantic search
    5. **Transaction Discovery**: Extracts all transaction hashes → Creates `EthereumTransaction` records

    ### 💸 Transaction Processing Chain
    **Transaction Creation** → **Data Fetching** → **Address Discovery** → **Relationship Mapping**

    1. **Transaction Jobs**: `after_create_commit` → `TransactionDataJob.perform_later` 
    2. **Detail Fetching**: Retrieves complete transaction data via blockchain APIs
    3. **Address Extraction**: Identifies `from_address` and `to_address` participants
    4. **Graph Building**: Creates `EthereumAddressTransaction` join records
    5. **Probabilistic Embedding**: 2% chance (1/50) → AI summary → Vector storage

    ### 🏠 Address Intelligence Network
    **Address Discovery** → **Profile Building** → **Semantic Indexing**

    1. **Address Jobs**: Each transaction triggers `AddressDataJob.perform_later` for involved addresses
    2. **Profile Building**: Fetches comprehensive address data (balances, contracts, token holdings)
    3. **Smart Embedding**: 6.7% chance (1/15) → AI-powered address summary → Qdrant storage
    4. **Relationship Tracking**: Maps address interactions across the entire transaction network

    ### 🔍 Multi-Modal Search Architecture
    **Natural Language** → **AI Processing** → **Vector/Parameter Search** → **Enriched Results**

    - **Semantic Search**: Query embedding → Qdrant vector similarity → Ranked semantic results
    - **LLM Search**: Natural language → LLaMA 3.2 3B → Smart parameter selection (150+ address params, 120+ block params)
    - **JSON Search**: Direct parameter filtering → Real-time data enrichment → Structured responses

    **Key Performance Features:**
    - **Asynchronous Job Processing**: Non-blocking pipeline with retry logic
    - **Probabilistic Optimization**: Cost-efficient embedding generation
    - **Concurrent API Calls**: Async/await for maximum throughput
    - **Vector Similarity Search**: Sub-second semantic query responses
    - **Real-time WebSocket Streams**: Live blockchain monitoring
    - **Kubernetes Auto-scaling**: Production-ready container orchestration

    This creates an intelligent, self-building blockchain knowledge graph where every new block enriches the system's understanding of Ethereum's transaction ecosystem.

    Experience the future of blockchain intelligence - where real-time data meets AI-powered insights.
  HEREDOC
  config.info.contact.name = 'ChainFETCH'
  config.info.contact.email = 'contact@chainfetch.app'
  config.info.contact.url = 'https://www.chainfetch.app'

  # Servers Information. For more details follow: https://spec.openapis.org/oas/latest.html#server-object
  config.servers = Rails.env.production? ? [
    { url: "https://www.chainfetch.app", description: "Production" }
  ] : [
    { url: "http://localhost:3000", description: "Development" }
  ]

  # Tag Information. For more details follow: https://spec.openapis.org/oas/latest.html#tag-object
  # config.tags = [{ name: "Users", description: "Manage the `amazing` Users table." }]

  # Optional Settings (Uncomment to use)

  # Extract default tags of operations from namespace or controller. Can be set to :namespace or :controller
  # config.default_tags_from = :namespace

  # Automatically detect request bodies for create/update methods
  # Default: true
  # config.autodiscover_request_body = false

  # Automatically detect responses from controller renders
  # Default: true
  # config.autodiscover_responses = false

  # API path configuration if your API is under a different namespace
  config.api_path = "/api"

  # Apply your custom layout. Should be the name of your layout file
  # Example: "application" if file named application.html.erb
  # Default: false
  # config.layout = "application"

  # Excluding custom controllers or controllers#action
  # Example: ["projects", "users#new"]
  # config.ignored_actions = []

  # #######################
  # Authentication Settings
  # #######################

  # Whether to authenticate all routes by default
  # Default is true; set to false if you don't want all routes to include security schemas by default
  # config.authenticate_all_routes_by_default = true

  # Default security schema used for authentication
  # Choose a predefined security schema
  # [:api_key_cookie, :api_key_header, :api_key_query, :basic, :bearer, :bearer_jwt, :mutual_tls]
  # config.security_schema = :bearer

  # Custom security schemas
  # You can uncomment and modify to use custom security schemas
  # Please follow the documentation: https://spec.openapis.org/oas/latest.html#security-scheme-object
  #
  # config.security_schemas = {
  #  bearer:{
  #   "type": "apiKey",
  #   "name": "api_key",
  #   "in": "header"
  #  }
  # }

  # ###########################
  # Default Responses (Errors)
  # ###########################

  # The default responses errors are set only if the action allow it.
  # Example, if you add forbidden then it will be added only if the endpoint requires authentication.
  # Example: not_found will be setted to the endpoint only if the operation is a show/update/destroy action.
  # config.set_default_responses = true
  # config.possible_default_responses = [:not_found, :unauthorized, :forbidden, :internal_server_error, :unprocessable_entity]
  # config.response_body_of_default = "Hash{ message: String }"
  # config.response_body_of_unprocessable_entity= "Hash{ errors: Array<String> }"
end
