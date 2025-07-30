#!/bin/bash

# Simple deployment script for toy API
# Usage: ./deploy.sh [dev|staging|prod]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default to dev if no environment specified
ENVIRONMENT=${1:-dev}

# Project IDs for each environment
case $ENVIRONMENT in
  dev)
    PROJECT_ID="toy-api-dev"
    SERVICE_NAME="toy-api-service-dev"
    ;;
  staging)
    PROJECT_ID="toy-api-staging"  
    SERVICE_NAME="toy-api-service-staging"
    ;;
  prod)
    PROJECT_ID="toy-api-prod"
    SERVICE_NAME="toy-api-service-prod"
    ;;
  *)
    echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
    echo "Usage: $0 [dev|staging|prod]"
    exit 1
    ;;
esac

echo -e "${BLUE}🚀 Deploying to $ENVIRONMENT environment${NC}"
echo -e "${BLUE}Project: $PROJECT_ID${NC}"

# Set the active project
echo -e "${YELLOW}🔧 Setting active project...${NC}"
gcloud config set project $PROJECT_ID

# Build and deploy in one command using Cloud Build
echo -e "${YELLOW}🏗️ Building and deploying with Cloud Build...${NC}"
cd google-cloud-toy-api

gcloud run deploy $SERVICE_NAME \
  --source . \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --memory 512Mi \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 10 \
  --port 8080 \
  --set-env-vars NODE_ENV=$ENVIRONMENT,API_KEY=dev-api-key-123

echo -e "${GREEN}✅ Deployment complete!${NC}"

# Get the service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region us-central1 --format 'value(status.url)')
echo -e "${GREEN}🌐 Service URL: $SERVICE_URL${NC}"

# Test the deployment
echo -e "${YELLOW}🧪 Testing deployment...${NC}"
if curl -s -f "$SERVICE_URL/public" > /dev/null; then
  echo -e "${GREEN}✅ Service is responding!${NC}"
  echo -e "${BLUE}Try: curl $SERVICE_URL/public${NC}"
else
  echo -e "${RED}❌ Service test failed${NC}"
  exit 1
fi

echo -e "${GREEN}🎉 Deployment to $ENVIRONMENT completed successfully!${NC}"