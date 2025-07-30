# Manual Deployment Guide

## Quick Deploy (Recommended)

Deploy to any environment with a single command:

```bash
# Deploy to development
./deploy.sh dev

# Deploy to staging  
./deploy.sh staging

# Deploy to production
./deploy.sh prod
```

The script automatically:
- ✅ Sets the correct Google Cloud project
- ✅ Builds the container using Cloud Build
- ✅ Deploys to Cloud Run
- ✅ Tests the deployment
- ✅ Returns the service URL

## Prerequisites

1. **Google Cloud CLI installed and authenticated**:
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

2. **Required permissions** for your account:
   - Cloud Run Admin
   - Cloud Build Editor  
   - Storage Admin (for Cloud Build)

3. **Enable required APIs** (done automatically on first deploy):
   - Cloud Run API
   - Cloud Build API
   - Container Registry API

## Manual Step-by-Step (Advanced)

If you prefer manual control:

### 1. Build and Push Container
```bash
cd google-cloud-toy-api

# Set project
gcloud config set project toy-api-dev

# Build and push
gcloud builds submit --tag gcr.io/toy-api-dev/toy-api
```

### 2. Deploy to Cloud Run
```bash
gcloud run deploy toy-api-service-dev \
  --image gcr.io/toy-api-dev/toy-api \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --memory 512Mi \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 10 \
  --port 8080 \
  --set-env-vars NODE_ENV=dev,API_KEY=dev-api-key-123
```

### 3. Test Deployment
```bash
# Get service URL
SERVICE_URL=$(gcloud run services describe toy-api-service-dev --region us-central1 --format 'value(status.url)')

# Test endpoints
curl $SERVICE_URL/public
curl -H "x-api-key: dev-api-key-123" $SERVICE_URL/items
```

## Local Development

### Option 1: Docker (Recommended)
```bash
cd google-cloud-toy-api

# Build and run locally
docker build -t toy-api-local .
docker run -p 8080:8080 toy-api-local

# Test
curl http://localhost:8080/public
```

### Option 2: Node.js Direct
```bash
cd google-cloud-toy-api

# Install dependencies
npm install

# Run locally
npm run dev

# Test
curl http://localhost:8080/public
```

### Option 3: Docker Compose (Full Stack)
```bash
cd google-cloud-toy-api

# Start API + Firestore emulator
docker-compose up

# Test with emulated Firestore
curl http://localhost:8080/public
```

## Rollback

To rollback to a previous version:

```bash
# List previous revisions
gcloud run revisions list --service toy-api-service-dev --region us-central1

# Rollback to specific revision
gcloud run services update-traffic toy-api-service-dev \
  --to-revisions REVISION-NAME=100 \
  --region us-central1
```

## Monitoring

View logs and metrics:

```bash
# View logs
gcloud run services logs read toy-api-service-dev --region us-central1

# View in console
echo "https://console.cloud.google.com/run/detail/us-central1/toy-api-service-dev"
```

## Cost Optimization

For development, use minimal resources:
- **Memory**: 256Mi (minimum)
- **CPU**: 1 vCPU (minimum)  
- **Min instances**: 0 (no idle costs)
- **Max instances**: 5 (prevent runaway costs)

For production, increase as needed:
- **Memory**: 512Mi-2Gi
- **CPU**: 1-4 vCPUs
- **Min instances**: 1 (faster response)
- **Max instances**: 100+ (handle traffic spikes)

## Troubleshooting

### Build Fails
```bash
# Check build logs
gcloud builds log --region us-central1 BUILD-ID

# Common fixes:
# 1. Check Dockerfile syntax
# 2. Ensure package.json is valid
# 3. Check for missing dependencies
```

### Service Won't Start
```bash
# Check service logs
gcloud run services logs read toy-api-service-dev --region us-central1

# Common fixes:
# 1. Check PORT environment variable (should be 8080)
# 2. Ensure app listens on 0.0.0.0, not localhost
# 3. Check for missing environment variables
```

### Can't Access Service
```bash
# Check IAM permissions
gcloud run services get-iam-policy toy-api-service-dev --region us-central1

# Make public (if needed)
gcloud run services add-iam-policy-binding toy-api-service-dev \
  --member="allUsers" \
  --role="roles/run.invoker" \
  --region us-central1
```

---

## Why Cloud Run > Cloud Functions for Manual Deployments

| Factor | Cloud Functions | Cloud Run |
|--------|----------------|-----------|
| **Deploy Command** | 1 command | 1 command (with script) |
| **Build Reliability** | ❌ Runtime compilation | ✅ Local build validation |
| **Local Testing** | ❌ Different environment | ✅ Identical containers |
| **Debugging** | ❌ Cloud-only errors | ✅ Local debugging |
| **Cost** | ✅ Same | ✅ Same |
| **Performance** | ❌ Cold starts | ✅ Faster cold starts |

**Bottom Line**: Cloud Run gives you better reliability and debugging for the same cost and complexity.