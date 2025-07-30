#!/bin/bash

# Smart Deployment Script with Integration Tests and Rollbacks
# Usage: ./deploy-with-tests.sh [dev|staging|prod]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Default to dev if no environment specified
ENVIRONMENT=${1:-dev}

# Configuration for each environment
case $ENVIRONMENT in
  dev)
    PROJECT_ID="toy-api-dev"
    SERVICE_NAME="toy-api-service-dev"
    API_KEY="dev-api-key-123"
    REQUIRES_TESTS=true
    ROLLBACK_ON_FAILURE=true
    ;;
  staging)
    PROJECT_ID="toy-api-staging"  
    SERVICE_NAME="toy-api-service-staging"
    API_KEY="staging-api-key-456"
    REQUIRES_TESTS=true
    ROLLBACK_ON_FAILURE=true
    ;;
  prod)
    PROJECT_ID="toy-api-prod"
    SERVICE_NAME="toy-api-service-prod"
    API_KEY="prod-api-key-789"
    REQUIRES_TESTS=true
    ROLLBACK_ON_FAILURE=true
    ;;
  *)
    echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
    echo "Usage: $0 [dev|staging|prod]"
    exit 1
    ;;
esac

echo -e "${BLUE}🚀 Smart Deployment to $ENVIRONMENT environment${NC}"
echo -e "${BLUE}Project: $PROJECT_ID${NC}"

# Function to capture current revision for rollback
capture_current_revision() {
    echo -e "${YELLOW}📸 Capturing current revision for rollback...${NC}"
    CURRENT_REVISION=$(gcloud run revisions list \
        --service=$SERVICE_NAME \
        --region=us-central1 \
        --project=$PROJECT_ID \
        --format="value(metadata.name)" \
        --limit=1 2>/dev/null || echo "")
    
    if [ -n "$CURRENT_REVISION" ]; then
        echo -e "${GREEN}✅ Current revision captured: $CURRENT_REVISION${NC}"
    else
        echo -e "${YELLOW}⚠️  No previous revision found (first deployment)${NC}"
    fi
}

# Function to rollback to previous revision
rollback_deployment() {
    echo -e "${RED}🔄 Rolling back deployment...${NC}"
    
    if [ -z "$CURRENT_REVISION" ]; then
        echo -e "${RED}❌ No revision to rollback to${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}⏪ Rolling back to revision: $CURRENT_REVISION${NC}"
    
    gcloud run services update-traffic $SERVICE_NAME \
        --to-revisions="$CURRENT_REVISION=100" \
        --region=us-central1 \
        --project=$PROJECT_ID
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Rollback completed successfully${NC}"
        return 0
    else
        echo -e "${RED}❌ Rollback failed${NC}"
        return 1
    fi
}

# Function to run integration tests
run_integration_tests() {
    local service_url="$1"
    
    echo -e "${PURPLE}🧪 Running integration tests...${NC}"
    
    if ./test-integration.sh "$service_url" "$API_KEY" "$ENVIRONMENT"; then
        echo -e "${GREEN}✅ All integration tests passed${NC}"
        return 0
    else
        echo -e "${RED}❌ Integration tests failed${NC}"
        return 1
    fi
}

# Function to get service URL
get_service_url() {
    gcloud run services describe $SERVICE_NAME \
        --region=us-central1 \
        --project=$PROJECT_ID \
        --format='value(status.url)' 2>/dev/null || echo ""
}

# Main deployment process
main() {
    # Set the active project
    echo -e "${YELLOW}🔧 Setting active project...${NC}"
    gcloud config set project $PROJECT_ID
    
    # Capture current revision for rollback
    capture_current_revision
    
    # Build and deploy
    echo -e "${YELLOW}🏗️ Building and deploying...${NC}"
    cd google-cloud-toy-api
    
    # Generate unique image tag
    IMAGE_TAG="gcr.io/$PROJECT_ID/toy-api:$(date +%Y%m%d-%H%M%S)-$(git rev-parse --short HEAD)"
    
    # Deploy with Cloud Build
    if gcloud run deploy $SERVICE_NAME \
        --source . \
        --platform managed \
        --region us-central1 \
        --allow-unauthenticated \
        --memory 512Mi \
        --cpu 1 \
        --min-instances 0 \
        --max-instances 10 \
        --port 8080 \
        --tag="v$(date +%Y%m%d-%H%M%S)" \
        --set-env-vars NODE_ENV=$ENVIRONMENT,API_KEY=$API_KEY; then
        
        echo -e "${GREEN}✅ Deployment completed successfully${NC}"
    else
        echo -e "${RED}❌ Deployment failed${NC}"
        exit 1
    fi
    
    # Get the service URL
    SERVICE_URL=$(get_service_url)
    if [ -z "$SERVICE_URL" ]; then
        echo -e "${RED}❌ Could not get service URL${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}🌐 Service deployed at: $SERVICE_URL${NC}"
    
    # Run integration tests if required
    if [ "$REQUIRES_TESTS" = true ]; then
        cd ..
        
        echo -e "${PURPLE}⏳ Waiting for service to stabilize before testing...${NC}"
        sleep 30
        
        if run_integration_tests "$SERVICE_URL"; then
            echo -e "${GREEN}🎉 Deployment and tests successful!${NC}"
        else
            echo -e "${RED}💥 Integration tests failed${NC}"
            
            if [ "$ROLLBACK_ON_FAILURE" = true ]; then
                echo -e "${YELLOW}🔄 Initiating automatic rollback...${NC}"
                cd google-cloud-toy-api
                
                if rollback_deployment; then
                    echo -e "${YELLOW}⚠️  Deployment rolled back due to test failures${NC}"
                    exit 2  # Exit with code 2 to indicate rollback
                else
                    echo -e "${RED}❌ Rollback failed - manual intervention required${NC}"
                    exit 3  # Exit with code 3 to indicate rollback failure
                fi
            else
                echo -e "${RED}❌ Tests failed but rollback disabled${NC}"
                exit 1
            fi
        fi
    else
        echo -e "${YELLOW}ℹ️  Integration tests skipped for this environment${NC}"
    fi
    
    # Final success message
    echo -e "${GREEN}🎉 Deployment to $ENVIRONMENT completed successfully!${NC}"
    echo -e "${BLUE}🌐 Service URL: $SERVICE_URL${NC}"
    echo -e "${BLUE}📊 Try: curl '$SERVICE_URL/public'${NC}"
    
    # Show recent revisions
    echo -e "\n${BLUE}📋 Recent revisions:${NC}"
    gcloud run revisions list \
        --service=$SERVICE_NAME \
        --region=us-central1 \
        --project=$PROJECT_ID \
        --limit=3 \
        --format="table(metadata.name,status.conditions[0].lastTransitionTime.date('%Y-%m-%d %H:%M'),spec.template.spec.containers[0].image.split('/')[-1])"
}

# Trap to handle interruption
trap 'echo -e "\n${RED}🛑 Deployment interrupted${NC}"; exit 130' INT

# Run main function
main

exit 0