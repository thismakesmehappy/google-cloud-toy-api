#!/bin/bash

# Rollback Script for Toy API
# Usage: ./rollback.sh [dev|staging|prod] [revision_name]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ENVIRONMENT=${1:-dev}
TARGET_REVISION="$2"

# Configuration for each environment
case $ENVIRONMENT in
  dev)
    PROJECT_ID="toy-api-dev"
    SERVICE_NAME="toy-api-service-dev"
    API_KEY="dev-api-key-123"
    ;;
  staging)
    PROJECT_ID="toy-api-staging"  
    SERVICE_NAME="toy-api-service-staging"
    API_KEY="staging-api-key-456"
    ;;
  prod)
    PROJECT_ID="toy-api-prod"
    SERVICE_NAME="toy-api-service-prod"
    API_KEY="prod-api-key-789"
    ;;
  *)
    echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
    echo "Usage: $0 [dev|staging|prod] [revision_name]"
    exit 1
    ;;
esac

echo -e "${BLUE}🔄 Rollback for $ENVIRONMENT environment${NC}"
echo -e "${BLUE}Project: $PROJECT_ID${NC}"

# Set the active project
gcloud config set project $PROJECT_ID

# Show current revisions
echo -e "${YELLOW}📋 Current revisions:${NC}"
gcloud run revisions list \
    --service=$SERVICE_NAME \
    --region=us-central1 \
    --format="table(metadata.name,status.conditions[0].lastTransitionTime.date('%Y-%m-%d %H:%M'),spec.template.spec.containers[0].image.split('/')[-1],status.conditions[0].status)" \
    --limit=10

# If no specific revision provided, get the previous one
if [ -z "$TARGET_REVISION" ]; then
    echo -e "${YELLOW}🔍 No revision specified, finding previous revision...${NC}"
    
    # Get the second most recent revision (previous to current)
    TARGET_REVISION=$(gcloud run revisions list \
        --service=$SERVICE_NAME \
        --region=us-central1 \
        --format="value(metadata.name)" \
        --limit=2 | tail -n 1)
    
    if [ -z "$TARGET_REVISION" ]; then
        echo -e "${RED}❌ No previous revision found to rollback to${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Found previous revision: $TARGET_REVISION${NC}"
else
    echo -e "${BLUE}🎯 Rolling back to specified revision: $TARGET_REVISION${NC}"
    
    # Verify the revision exists
    if ! gcloud run revisions describe "$TARGET_REVISION" \
        --service=$SERVICE_NAME \
        --region=us-central1 &>/dev/null; then
        echo -e "${RED}❌ Revision $TARGET_REVISION not found${NC}"
        exit 1
    fi
fi

# Confirm rollback
echo -e "${YELLOW}⚠️  This will rollback the service to revision: $TARGET_REVISION${NC}"
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}🛑 Rollback cancelled${NC}"
    exit 0
fi

# Perform rollback
echo -e "${YELLOW}🔄 Rolling back to revision: $TARGET_REVISION${NC}"

if gcloud run services update-traffic $SERVICE_NAME \
    --to-revisions="$TARGET_REVISION=100" \
    --region=us-central1; then
    
    echo -e "${GREEN}✅ Rollback completed successfully${NC}"
    
    # Get the service URL
    SERVICE_URL=$(gcloud run services describe $SERVICE_NAME \
        --region=us-central1 \
        --format='value(status.url)')
    
    echo -e "${GREEN}🌐 Service URL: $SERVICE_URL${NC}"
    
    # Wait a moment and test the rollback
    echo -e "${YELLOW}⏳ Waiting for rollback to take effect...${NC}"
    sleep 15
    
    echo -e "${BLUE}🧪 Testing rolled back service...${NC}"
    if ./test-integration.sh "$SERVICE_URL" "$API_KEY" "$ENVIRONMENT"; then
        echo -e "${GREEN}🎉 Rollback successful and tests passed!${NC}"
    else
        echo -e "${YELLOW}⚠️  Rollback completed but some tests failed${NC}"
        echo -e "${YELLOW}This might be expected depending on the revision${NC}"
    fi
    
else
    echo -e "${RED}❌ Rollback failed${NC}"
    exit 1
fi

# Show current traffic distribution
echo -e "\n${BLUE}📊 Current traffic distribution:${NC}"
gcloud run services describe $SERVICE_NAME \
    --region=us-central1 \
    --format="table(status.traffic[].revisionName,status.traffic[].percent)"

echo -e "\n${GREEN}🎉 Rollback to $ENVIRONMENT completed!${NC}"