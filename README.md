# 🚀 Google Cloud Toy API

A serverless REST API built with **Cloud Run**, **Firestore**, and **TypeScript**. Features enterprise-grade deployment with automatic testing and rollbacks.

[![Architecture](https://img.shields.io/badge/Architecture-Cloud%20Run-blue)](https://cloud.google.com/run)
[![Language](https://img.shields.io/badge/Language-TypeScript-blue)](https://www.typescriptlang.org/)
[![Database](https://img.shields.io/badge/Database-Firestore-orange)](https://firebase.google.com/products/firestore)
[![Container](https://img.shields.io/badge/Container-Docker-blue)](https://www.docker.com/)

## 🏗️ Architecture

```
Express.js App → Docker Container → Cloud Run Service → Firestore Database
```

**Key Features:**
- ✅ **Containerized deployment** with Docker
- ✅ **Multi-environment support** (dev/staging/prod)
- ✅ **Integration testing** with automatic rollbacks
- ✅ **Free tier compliant** ($0/month operating cost)
- ✅ **Enterprise reliability** with simple commands

## 🚀 Quick Start

### Prerequisites
- [Google Cloud CLI](https://cloud.google.com/sdk/docs/install) installed and authenticated
- [Docker](https://docs.docker.com/get-docker/) installed
- [Node.js 20+](https://nodejs.org/) installed

### Local Development
```bash
# Clone and setup
git clone <your-repo>
cd TestGoogleAPI/google-cloud-toy-api

# Install dependencies
npm install

# Run locally
npm run dev

# Or with Docker
docker-compose up
```

### Deploy to Google Cloud
```bash
# Deploy to development
./deploy-with-tests.sh dev

# Deploy to staging  
./deploy-with-tests.sh staging

# Deploy to production
./deploy-with-tests.sh prod
```

## 📖 API Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| `GET` | `/` | Health check | No |
| `GET` | `/public` | Public message | No |
| `GET` | `/private` | Protected message | Yes (API key) |
| `POST` | `/auth/token` | Generate Firebase token | No |
| `GET` | `/items` | List user items | Yes (API key) |
| `POST` | `/items` | Create new item | Yes (API key) |
| `GET` | `/items/:id` | Get specific item | Yes (API key) |
| `PUT` | `/items/:id` | Update item | Yes (API key) |
| `DELETE` | `/items/:id` | Delete item | Yes (API key) |

### Authentication
Use the `x-api-key` header with environment-specific keys:
- **Dev**: `dev-api-key-123`
- **Staging**: `staging-api-key-456`  
- **Production**: `prod-api-key-789`

## 🧪 Testing

### Integration Tests
```bash
# Run full integration test suite
./test-integration.sh <service-url> <api-key> <environment>

# Example
./test-integration.sh https://toy-api-service-dev-xxx.run.app dev-api-key-123 dev
```

### Manual Testing
```bash
# Test public endpoint
curl https://your-service-url.run.app/public

# Test authenticated endpoint
curl -H "x-api-key: dev-api-key-123" https://your-service-url.run.app/items
```

## 🔄 Deployment & Operations

### Smart Deployment
The deployment system includes:
- ✅ **Pre-deployment validation** and revision capture
- ✅ **Container build and deployment** via Cloud Build
- ✅ **Integration testing** (10 comprehensive tests)
- ✅ **Automatic rollback** if tests fail

```bash
# Deploy with testing
./deploy-with-tests.sh dev

# Emergency rollback
./rollback.sh dev

# Rollback to specific revision
./rollback.sh dev toy-api-service-dev-00042-abc
```

### Environment Configuration

| Environment | Resources | Access | Min Instances |
|-------------|-----------|--------|---------------|
| **Dev** | 512Mi RAM, 1 CPU | Public | 0 (cost optimized) |
| **Staging** | 1Gi RAM, 1 CPU | Authenticated | 0 |
| **Production** | 2Gi RAM, 2 CPU | Authenticated | 1 (always warm) |

## 🏗️ Infrastructure

### Terraform Modules
- **`cloud-run/`** - Cloud Run service configuration
- **`firestore/`** - Firestore database setup
- **`shared/`** - Shared resources (APIs, IAM)

### Local Development Stack
```bash
# Full stack with Firestore emulator
docker-compose up

# Services available:
# - API: http://localhost:8080
# - Firestore Emulator: http://localhost:8181
```

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| [`DEPLOYMENT_GUIDE.md`](DEPLOYMENT_GUIDE.md) | Complete deployment instructions |
| [`MANUAL_DEPLOYMENT.md`](MANUAL_DEPLOYMENT.md) | Manual deployment options |
| [`CI_CD_RECOMMENDATION.md`](CI_CD_RECOMMENDATION.md) | CI/CD strategy analysis |
| [`ARCHITECTURE_MIGRATION.md`](ARCHITECTURE_MIGRATION.md) | Migration from Cloud Functions |

## 💰 Cost Analysis

**Monthly Costs (Free Tier):**
- **Cloud Run**: $0 (2M requests/month free)
- **Firestore**: $0 (1GB storage free)
- **Container Registry**: $0 (0.5GB storage free)

**Total: $0/month** for typical development usage

## 🔧 Development

### Project Structure
```
google-cloud-toy-api/
├── src/                    # TypeScript source code
│   ├── index.ts           # Main Express server
│   ├── functions/         # Route handlers
│   ├── services/          # Business logic
│   └── types/             # Type definitions
├── terraform/             # Infrastructure as code
│   ├── environments/      # Environment-specific configs
│   └── modules/           # Reusable Terraform modules
├── Dockerfile             # Container configuration
├── docker-compose.yml     # Local development stack
└── package.json          # Node.js dependencies
```

### Tech Stack
- **Runtime**: Node.js 20 + TypeScript
- **Framework**: Express.js
- **Database**: Google Firestore
- **Container**: Docker
- **Infrastructure**: Terraform
- **Deployment**: Google Cloud Build + Cloud Run

## 🛡️ Security

- ✅ **API key authentication** for development simplicity
- ✅ **Environment isolation** (separate GCP projects)
- ✅ **Service account permissions** (least privilege)
- ✅ **Container security** (non-root user)
- ✅ **Secret management** (Google Secret Manager ready)

## 🤝 Contributing

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Make your changes** and test locally
4. **Run integration tests**: `./test-integration.sh`
5. **Submit a pull request**

## 📄 License

This project is for educational purposes. See individual dependencies for their licenses.

## 🎯 Status

**Current Status**: ✅ **Production Ready**
- All environments deployed and tested
- Integration testing with automatic rollbacks
- Documentation complete
- Cost optimized for free tier

---

*Built with ❤️ using Google Cloud serverless technologies*