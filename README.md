# ChainFetch - AI-Powered Ethereum Blockchain Intelligence API

ChainFetch is an advanced Ethereum blockchain intelligence platform that combines real-time blockchain data streaming with AI-powered semantic search capabilities. Built on Ruby on Rails and deployed on Kubernetes, it provides developers with intelligent blockchain insights through natural language queries and vector-based search.

## 🚀 Overview

ChainFetch transforms how developers interact with Ethereum blockchain data by offering:

- **Real-time WebSocket streaming** of Ethereum blocks and transactions
- **AI-powered semantic search** using vector embeddings and LLM processing
- **Multi-modal search capabilities** (semantic, LLM-assisted, JSON parameter-based)
- **Comprehensive blockchain data coverage** (addresses, transactions, blocks, smart contracts, tokens)
- **Production-ready Kubernetes deployment** with auto-scaling and monitoring
- **RESTful API** with comprehensive OpenAPI 3.1 documentation

## 🏗️ Application Architecture

### Core Technologies

- **Backend**: Ruby on Rails 8.0.2 with Ruby 3.x
- **Database**: PostgreSQL 17 with pgvector extension for vector storage
- **Vector Database**: Qdrant for semantic search capabilities
- **AI Models**: 
  - Qwen3-Embedding-0.6B (Q8_0) for text embeddings
  - LLaMA 3.2 3B for LLM-powered query processing
- **Real-time Processing**: Async WebSocket connections with Ruby Async library
- **Background Jobs**: SolidQueue for asynchronous job processing
- **Frontend**: Hotwire (Turbo + Stimulus) with Tailwind CSS
- **Container Runtime**: Docker with NVIDIA GPU support for AI models
- **Orchestration**: Kubernetes (k0s) with custom deployments

### Database Schema

The application uses a sophisticated database schema designed for blockchain data:

```ruby
# Core Ethereum Data Models
ethereum_blocks           # Block headers and metadata (JSONB data field)
ethereum_transactions      # Transaction details with block relationships
ethereum_addresses        # Address profiles and activity data
ethereum_smart_contracts  # Smart contract information and ABI data
ethereum_tokens           # ERC-20/721 token metadata
ethereum_address_transactions  # Many-to-many relationships

# Application Models
users                     # API users with credit system
api_sessions             # API usage tracking and billing
payments                 # Stripe integration for credit purchases
sessions                 # User authentication sessions
```

### AI & Search Architecture

#### Vector Embeddings Pipeline
```
Blockchain Data → AI Summary Generation → Text Embedding → Qdrant Storage → Semantic Search
```

1. **Text Embedding Service**: Uses Qwen3-Embedding-0.6B model via Ollama
2. **Vector Storage**: Qdrant collections for each data type (addresses, blocks, transactions, etc.)
3. **Similarity Search**: Cosine similarity matching for semantic queries

#### LLM-Powered Search
```
Natural Language Query → LLaMA 3.2 3B → Parameter Extraction → API Call → Enriched Results
```

- **Smart Parameter Selection**: AI automatically chooses optimal search parameters
- **Tool-based Architecture**: LLM uses predefined tools to execute searches
- **Multi-step Processing**: Complex queries broken down into executable API calls

### Real-time Data Pipeline

#### Blockchain Streaming Architecture
```
Ethereum WebSocket → Block Detection → Database Storage → Background Processing → AI Enhancement
```

1. **WebSocket Connection**: Persistent connection to `wss://ethereum-rpc.publicnode.com`
2. **Block Stream Service**: Singleton service managing real-time block subscriptions
3. **Async Processing**: Non-blocking job queue for data enrichment
4. **Probabilistic AI Enhancement**: Cost-optimized embedding generation (2-6.7% of records)

#### Data Flow Sequence
1. **Block Detection**: New block headers received via WebSocket (~12 second intervals)
2. **Record Creation**: `EthereumBlock` records created in database
3. **Background Jobs**: Triggered via `after_create_commit` callbacks
4. **Data Enrichment**: Full block/transaction data fetched from APIs
5. **AI Processing**: Summaries generated and embeddings created
6. **Vector Storage**: Embeddings stored in Qdrant for semantic search
7. **Relationship Mapping**: Address-transaction relationships established

## 🔍 API Capabilities

### Search Endpoints

#### Semantic Search
```bash
GET /api/v1/ethereum/addresses/semantic_search?query=whale addresses with DeFi activity&limit=10
```

#### LLM-Powered Search
```bash
GET /api/v1/ethereum/transactions/llm_search?query=high gas transactions from yesterday
```

#### JSON Parameter Search
```bash
GET /api/v1/ethereum/blocks/json_search?gas_used_gte=15000000&limit=5
```

### Data Access Endpoints

- **Addresses**: `/api/v1/ethereum/addresses/:address`
- **Transactions**: `/api/v1/ethereum/transactions/:transaction`
- **Blocks**: `/api/v1/ethereum/blocks/:block`
- **Smart Contracts**: `/api/v1/ethereum/smart-contracts/:address`
- **Tokens**: `/api/v1/ethereum/tokens/:token`
- **Token Instances**: `/api/v1/ethereum/token-instances/:token/:instance_id`

### AI Summary Endpoints

- **Address Summary**: `/api/v1/ethereum/addresses/summary?address=0x...`
- **Transaction Summary**: `/api/v1/ethereum/transactions/summary?transaction=0x...`
- **Block Summary**: `/api/v1/ethereum/blocks/summary?block=12345`
- **Smart Contract Summary**: `/api/v1/ethereum/smart-contracts/summary?address=0x...`

## 🚢 Kubernetes Architecture

### Deployment Overview

The application runs on a multi-component Kubernetes architecture:

```yaml
Namespace: chainfetch
├── PostgreSQL (pgvector/pgvector:pg17)
│   ├── 400Gi Persistent Storage (Longhorn)
│   ├── 4-6GB RAM allocation
│   └── max_connections=1000
├── Rails Web Application (5 replicas)
│   ├── Puma server on port 3000
│   ├── 2-4GB RAM per pod
│   └── Auto-scaling based on CPU/memory
├── Background Jobs (4 replicas)
│   ├── SolidQueue workers
│   ├── Async blockchain data processing
│   └── 2-6GB RAM per pod
├── AI Services
│   ├── Ollama Qwen Embedding (2 replicas)
│   │   ├── NVIDIA GPU acceleration
│   │   ├── 8GB RAM per pod
│   │   └── 25Gi model storage
│   └── Ollama LLaMA (1 replica)
│       ├── LLaMA 3.2 3B model
│       ├── 6-8GB RAM allocation
│       └── 25Gi model storage
└── Qdrant Vector Database
    ├── Vector similarity search
    ├── Multiple collections (addresses, blocks, transactions)
    └── Persistent storage for embeddings
```

### Service Architecture

```yaml
Services:
├── chainfetch-web (ClusterIP:80 → 3000)
├── postgres (ClusterIP:5432)
├── ollama-qwen-embedding (ClusterIP:11434)
├── ollama-llama (ClusterIP:11434)
└── qdrant (ClusterIP:6333)

Ingress:
├── chainfetch.app (TLS via Let's Encrypt)
├── api.chainfetch.app
├── qwen.chainfetch.app (Bearer auth protected)
└── llama.chainfetch.app (Bearer auth protected)
```

### Storage & Persistence

- **PostgreSQL**: 400GB Longhorn persistent storage
- **AI Models**: 25GB per Ollama deployment (Longhorn)
- **Vector Data**: Qdrant persistent volumes
- **Application Logs**: Centralized logging with retention policies

### Networking & Security

- **Load Balancing**: NGINX Ingress Controller with MetalLB
- **TLS Termination**: cert-manager with Let's Encrypt
- **Authentication**: Bearer token-based API access
- **Network Policies**: Secure inter-pod communication
- **Resource Limits**: CPU and memory constraints per pod

## 🛠️ Development Setup

### Prerequisites

- Ruby 3.x
- Node.js (for asset compilation)
- PostgreSQL with pgvector extension
- Docker (for AI services)
- Kubernetes cluster (for production deployment)

### Local Development

```bash
# Clone the repository
git clone https://github.com/your-org/chainfetch.git
cd chainfetch

# Install dependencies
bundle install
yarn install

# Setup database
rails db:create db:migrate db:seed

# Start the application
bin/dev

# start the block stream service
rails ethereum:start_block_stream
```

### Environment Variables

```bash
# Database
DATABASE_URL=postgresql://user:pass@localhost/chainfetch_development

# AI Services
OLLAMA_EMBEDDING_URL=http://localhost:11434
OLLAMA_LLM_URL=http://localhost:11434
QDRANT_URL=http://localhost:6333

# API Keys
AUTH_BEARER_TOKEN=your_api_token
RECAPTCHA_SITE_KEY=your_site_key
RECAPTCHA_SECRET_KEY=your_secret_key
```

## 🚀 Deployment

### Kubernetes Deployment (k0s)

```bash
# 1. Bootstrap k0s cluster
curl --proto '=https' --tlsv1.2 -sSf https://get.k0s.sh | sudo sh
k0s install controller --single
k0s start
```

### Production Configuration

- **Scaling**: Web pods auto-scale based on CPU/memory usage
- **Monitoring**: Prometheus + Grafana stack for observability
- **Logging**: Centralized logging with log aggregation
- **Backups**: Automated database backups with retention policies

## 🎯 Key Features

### Multi-Modal Search
- **Natural Language**: "Find whale addresses that interacted with DeFi protocols"
- **Semantic Similarity**: Vector-based conceptual matching
- **Parameter-Based**: Direct filtering with 150+ address and 120+ block parameters

### Real-time Monitoring
- WebSocket connections for live blockchain data
- ActionCable integration for real-time web updates
- Continuous block and transaction processing

### AI-Enhanced Intelligence
- Automated data summarization using LLaMA 3.2 3B
- Vector embeddings for semantic search
- Smart parameter extraction from natural language

### Enterprise Features
- Rate-limited API access with authentication
- Credit-based billing system with Stripe integration
- Comprehensive API documentation with OpenAPI 3.1
- Production monitoring and observability

## 📄 License

This project is licensed under the [MIT License](LICENSE) - see the LICENSE file for details.

## 🆘 Support

- **Documentation**: [https://docs.chainfetch.app](https://docs.chainfetch.app)
- **API Reference**: [https://chainfetch.app/docs](https://chainfetch.app/docs)
- **Issues**: GitHub Issues for bug reports and feature requests
- **Email**: support@chainfetch.app

---

**Experience the future of blockchain intelligence** - where real-time data meets AI-powered insights. 🚀
