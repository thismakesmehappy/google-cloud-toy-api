#!/bin/bash

# Activate Cloud Build CI/CD Pipeline
# This script connects GitHub and creates build triggers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - UPDATE THESE VALUES
PROJECT_ID_DEV="toy-api-dev"
PROJECT_ID_STAGING="toy-api-staging" 
PROJECT_ID_PROD="toy-api-prod"
REPO_NAME="TestGoogleAPI"
GITHUB_OWNER=""  # REQUIRED: Set your GitHub username
REGION="us-central1"

echo -e "${BLUE}🚀 Activating Cloud Build CI/CD Pipeline${NC}"
echo -e "${BLUE}=======================================${NC}"

# Check if GitHub owner is set
if [ -z "$GITHUB_OWNER" ]; then
    echo -e "${RED}❌ Error: GITHUB_OWNER is not set${NC}"
    echo -e "${YELLOW}Please edit this script and set your GitHub username:${NC}"
    echo -e "${YELLOW}GITHUB_OWNER=\"your-github-username\"${NC}"
    exit 1
fi

# Check prerequisites
check_prerequisites() {
    echo -e "${BLUE}🔍 Checking prerequisites...${NC}"
    
    # Check gcloud CLI
    if ! command -v gcloud &> /dev/null; then
        echo -e "${RED}❌ gcloud CLI not found. Please install Google Cloud SDK.${NC}"
        exit 1
    fi
    
    # Check authentication
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        echo -e "${RED}❌ Not authenticated with gcloud. Please run 'gcloud auth login'${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Prerequisites check passed${NC}"
}

# Setup Cloud Build for a project
setup_cloud_build() {
    local project_id=$1
    local environment=$2
    
    echo -e "\n${YELLOW}📋 Setting up Cloud Build for $environment environment${NC}"
    echo -e "${YELLOW}Project: $project_id${NC}"
    
    # Set current project
    gcloud config set project $project_id
    
    # Enable required APIs
    echo -e "${BLUE}🔧 Enabling required APIs...${NC}"
    gcloud services enable cloudbuild.googleapis.com --quiet
    gcloud services enable run.googleapis.com --quiet
    gcloud services enable containerregistry.googleapis.com --quiet
    gcloud services enable sourcerepo.googleapis.com --quiet
    
    # Get project number for IAM binding
    PROJECT_NUMBER=$(gcloud projects describe $project_id --format="value(projectNumber)")
    CLOUD_BUILD_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"
    
    # Grant Cloud Build service account permissions
    echo -e "${BLUE}🔐 Setting up IAM permissions...${NC}"
    
    # Cloud Run Admin role
    gcloud projects add-iam-policy-binding $project_id \
        --member="serviceAccount:${CLOUD_BUILD_SA}" \
        --role="roles/run.admin" \
        --quiet
    
    # Service Account User role
    gcloud projects add-iam-policy-binding $project_id \
        --member="serviceAccount:${CLOUD_BUILD_SA}" \
        --role="roles/iam.serviceAccountUser" \
        --quiet
    
    # Storage Admin role for Container Registry
    gcloud projects add-iam-policy-binding $project_id \
        --member="serviceAccount:${CLOUD_BUILD_SA}" \
        --role="roles/storage.admin" \
        --quiet
    
    # Secret Manager Secret Accessor (for future secret management)
    gcloud projects add-iam-policy-binding $project_id \
        --member="serviceAccount:${CLOUD_BUILD_SA}" \
        --role="roles/secretmanager.secretAccessor" \
        --quiet
    
    echo -e "${GREEN}✅ IAM permissions configured for $environment${NC}"
}

# Create build trigger
create_build_trigger() {
    local project_id=$1
    local environment=$2
    local api_key=$3
    
    echo -e "\n${YELLOW}🎯 Creating Cloud Build trigger for $environment${NC}"
    
    # Set current project
    gcloud config set project $project_id
    
    # Check if trigger already exists
    if gcloud builds triggers list --filter="name:deploy-${environment}" --format="value(name)" | grep -q "deploy-${environment}"; then
        echo -e "${YELLOW}⚠️  Trigger deploy-${environment} already exists, skipping...${NC}"
        return 0
    fi
    
    # Set branch pattern based on environment
    local branch_pattern=""
    local description=""
    case $environment in
        "dev")
            branch_pattern="^develop$"
            description="Deploy to dev environment on develop branch push"
            ;;
        "staging")
            branch_pattern="^main$"
            description="Deploy to staging environment on main branch push"
            ;;
        "prod")
            # Production deployments should be manual only
            echo -e "${BLUE}Skipping automatic trigger for production - use manual deployment${NC}"
            return 0
            ;;
    esac

    # Set environment-specific resource configurations
    local memory cpu min_instances max_instances
    case $environment in
        "dev")
            memory="512Mi"
            cpu="1"
            min_instances="0"
            max_instances="10"
            ;;
        "staging")
            memory="1Gi"
            cpu="1"
            min_instances="1"
            max_instances="20"
            ;;
        "prod")
            memory="2Gi"
            cpu="2"
            min_instances="2"
            max_instances="100"
            ;;
    esac

    # Create the trigger
    gcloud builds triggers create github \
        --repo-name=$REPO_NAME \
        --repo-owner=$GITHUB_OWNER \
        --branch-pattern="$branch_pattern" \
        --build-config="google-cloud-toy-api/cloudbuild.yaml" \
        --name="deploy-${environment}" \
        --description="$description" \
        --substitutions="_ENVIRONMENT=${environment},_API_KEY=${api_key},_MEMORY=${memory},_CPU=${cpu},_MIN_INSTANCES=${min_instances},_MAX_INSTANCES=${max_instances}" \
        --included-files="google-cloud-toy-api/**" \
        --quiet
    
    echo -e "${GREEN}✅ Build trigger created for $environment${NC}"
}

# Test the build trigger
test_build_trigger() {
    local project_id=$1
    local environment=$2
    
    echo -e "\n${YELLOW}🧪 Testing build trigger for $environment${NC}"
    
    gcloud config set project $project_id
    
    # Run a manual build to test
    echo -e "${BLUE}Starting manual build to test the pipeline...${NC}"
    
    BUILD_ID=$(gcloud builds submit \
        --config="google-cloud-toy-api/cloudbuild.yaml" \
        --substitutions="_API_KEY_DEV=dev-api-key-123,_ENVIRONMENT=${environment}" \
        --format="value(id)" \
        --quiet)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Build triggered successfully${NC}"
        echo -e "${BLUE}Build ID: $BUILD_ID${NC}"
        echo -e "${BLUE}Monitor at: https://console.cloud.google.com/cloud-build/builds/$BUILD_ID?project=$project_id${NC}"
    else
        echo -e "${RED}❌ Build trigger test failed${NC}"
        return 1
    fi
}

# Main activation process
main() {
    echo -e "${BLUE}Starting Cloud Build CI/CD activation...${NC}\n"
    
    # Check prerequisites
    check_prerequisites
    
    # Show configuration
    echo -e "\n${BLUE}Configuration:${NC}"
    echo -e "GitHub Owner: ${YELLOW}$GITHUB_OWNER${NC}"
    echo -e "Repository: ${YELLOW}$REPO_NAME${NC}"
    echo -e "Dev Project: ${YELLOW}$PROJECT_ID_DEV${NC}"
    
    read -p "Press Enter to continue or Ctrl+C to abort..."
    
    # Setup dev environment first
    echo -e "\n${BLUE}=== Setting up DEV environment ===${NC}"
    setup_cloud_build $PROJECT_ID_DEV "dev"
    create_build_trigger $PROJECT_ID_DEV "dev" "dev-api-key-123"
    
    # Ask about testing
    echo -e "\n${BLUE}Do you want to test the build trigger now? (y/n)${NC}"
    read -r test_build
    if [[ $test_build == "y" || $test_build == "Y" ]]; then
        test_build_trigger $PROJECT_ID_DEV "dev"
    fi
    
    # Ask about staging
    echo -e "\n${BLUE}Do you want to setup staging environment CI/CD? (y/n)${NC}"
    read -r setup_staging
    if [[ $setup_staging == "y" || $setup_staging == "Y" ]]; then
        echo -e "\n${BLUE}=== Setting up STAGING environment ===${NC}"
        setup_cloud_build $PROJECT_ID_STAGING "staging"
        create_build_trigger $PROJECT_ID_STAGING "staging" "staging-api-key-456"
    fi
    
    # Ask about production
    echo -e "\n${BLUE}Do you want to setup production environment CI/CD? (y/n)${NC}"
    read -r setup_prod
    if [[ $setup_prod == "y" || $setup_prod == "Y" ]]; then
        echo -e "\n${BLUE}=== Setting up PRODUCTION environment ===${NC}"
        setup_cloud_build $PROJECT_ID_PROD "prod"
        create_build_trigger $PROJECT_ID_PROD "prod" "prod-api-key-789"
    fi
    
    echo -e "\n${GREEN}🎉 Cloud Build CI/CD activation completed!${NC}"
    echo -e "${GREEN}=======================================${NC}"
    echo -e "${BLUE}Deployment Workflow:${NC}"
    echo -e "📋 ${YELLOW}develop branch${NC} → Automatic deployment to ${YELLOW}dev environment${NC}"
    echo -e "📋 ${YELLOW}main branch${NC} → Automatic deployment to ${YELLOW}staging environment${NC}"  
    echo -e "📋 ${YELLOW}production${NC} → Manual deployment only"
    echo -e "\n${BLUE}Next steps:${NC}"
    echo -e "1. Create/push to ${YELLOW}develop${NC} branch to trigger dev deployment"
    echo -e "2. Merge ${YELLOW}develop${NC} → ${YELLOW}main${NC} to trigger staging deployment"
    echo -e "3. Use manual scripts for production deployment"
    echo -e "\n${BLUE}Monitor builds at:${NC}"
    echo -e "   ${YELLOW}https://console.cloud.google.com/cloud-build/builds?project=$PROJECT_ID_DEV${NC}"
    echo -e "\n${BLUE}GitHub repository connection:${NC}"
    echo -e "If this is your first time using Cloud Build with GitHub,"
    echo -e "you may need to authorize the connection at:"
    echo -e "${YELLOW}https://console.cloud.google.com/cloud-build/triggers${NC}"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi