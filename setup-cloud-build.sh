#!/bin/bash

# Cloud Build Setup Script
# Sets up automated CI/CD with Google Cloud Build

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID_DEV="toy-api-dev"
PROJECT_ID_STAGING="toy-api-staging" 
PROJECT_ID_PROD="toy-api-prod"
REPO_NAME="TestGoogleAPI"
GITHUB_OWNER="your-github-username"  # Update this
REGION="us-central1"

echo -e "${BLUE}🚀 Setting up Google Cloud Build CI/CD${NC}"
echo -e "${BLUE}=======================================${NC}"

# Function to setup Cloud Build for a project
setup_cloud_build() {
    local project_id=$1
    local environment=$2
    local api_key=$3
    
    echo -e "\n${YELLOW}📋 Setting up Cloud Build for $environment environment${NC}"
    echo -e "${YELLOW}Project: $project_id${NC}"
    
    # Set current project
    gcloud config set project $project_id
    
    # Enable required APIs
    echo -e "${BLUE}🔧 Enabling required APIs...${NC}"
    gcloud services enable cloudbuild.googleapis.com
    gcloud services enable run.googleapis.com
    gcloud services enable containerregistry.googleapis.com
    
    # Grant Cloud Build service account permissions
    echo -e "${BLUE}🔐 Setting up IAM permissions...${NC}"
    PROJECT_NUMBER=$(gcloud projects describe $project_id --format="value(projectNumber)")
    CLOUD_BUILD_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"
    
    # Grant Cloud Run Admin role
    gcloud projects add-iam-policy-binding $project_id \
        --member="serviceAccount:${CLOUD_BUILD_SA}" \
        --role="roles/run.admin"
    
    # Grant Service Account User role (needed to deploy to Cloud Run)
    gcloud projects add-iam-policy-binding $project_id \
        --member="serviceAccount:${CLOUD_BUILD_SA}" \
        --role="roles/iam.serviceAccountUser"
    
    # Grant Storage Admin role (for Container Registry)
    gcloud projects add-iam-policy-binding $project_id \
        --member="serviceAccount:${CLOUD_BUILD_SA}" \
        --role="roles/storage.admin"
    
    echo -e "${GREEN}✅ IAM permissions configured for $environment${NC}"
}

# Function to create Cloud Build trigger
create_build_trigger() {
    local project_id=$1
    local environment=$2
    local api_key=$3
    local branch=${4:-"main"}
    
    echo -e "\n${YELLOW}🎯 Creating Cloud Build trigger for $environment${NC}"
    
    # Set current project
    gcloud config set project $project_id
    
    # Create the trigger
    cat > /tmp/trigger-${environment}.yaml << EOF
name: deploy-${environment}
description: "Deploy to ${environment} environment on ${branch} branch push"
github:
  owner: ${GITHUB_OWNER}
  name: ${REPO_NAME}
  push:
    branch: ^${branch}$
filename: google-cloud-toy-api/cloudbuild.yaml
substitutions:
  _API_KEY_DEV: "${api_key}"
  _ENVIRONMENT: "${environment}"
includedFiles:
  - "google-cloud-toy-api/**"
EOF
    
    # Apply the trigger
    gcloud builds triggers import /tmp/trigger-${environment}.yaml
    
    echo -e "${GREEN}✅ Build trigger created for $environment${NC}"
    rm /tmp/trigger-${environment}.yaml
}

# Main setup process
main() {
    echo -e "${BLUE}Starting Cloud Build setup for all environments...${NC}\n"
    
    # Check if gcloud is installed and authenticated
    if ! command -v gcloud &> /dev/null; then
        echo -e "${RED}❌ gcloud CLI not found. Please install Google Cloud SDK.${NC}"
        exit 1
    fi
    
    # Check if user is authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        echo -e "${RED}❌ Not authenticated with gcloud. Please run 'gcloud auth login'${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}⚠️  IMPORTANT: Update GITHUB_OWNER in this script before running!${NC}"
    echo -e "${YELLOW}Current value: $GITHUB_OWNER${NC}"
    read -p "Press Enter to continue or Ctrl+C to abort..."
    
    # Setup dev environment
    setup_cloud_build $PROJECT_ID_DEV "dev" "dev-api-key-123"
    
    # Setup staging environment (if needed)
    echo -e "\n${BLUE}Do you want to setup staging environment? (y/n)${NC}"
    read -r setup_staging
    if [[ $setup_staging == "y" || $setup_staging == "Y" ]]; then
        setup_cloud_build $PROJECT_ID_STAGING "staging" "staging-api-key-456"
    fi
    
    # Setup production environment (if needed)
    echo -e "\n${BLUE}Do you want to setup production environment? (y/n)${NC}"
    read -r setup_prod
    if [[ $setup_prod == "y" || $setup_prod == "Y" ]]; then
        setup_cloud_build $PROJECT_ID_PROD "prod" "prod-api-key-789"
    fi
    
    echo -e "\n${GREEN}🎉 Cloud Build setup completed!${NC}"
    echo -e "${GREEN}==============================${NC}"
    echo -e "${BLUE}Next steps:${NC}"
    echo -e "1. Connect your GitHub repository to Cloud Build"
    echo -e "2. Update GITHUB_OWNER variable in this script"
    echo -e "3. Run the trigger creation (optional):"
    echo -e "   ${YELLOW}create_build_trigger $PROJECT_ID_DEV dev dev-api-key-123${NC}"
    echo -e "4. Push to main branch to trigger first build"
    echo -e "\n${BLUE}Monitor builds at:${NC}"
    echo -e "https://console.cloud.google.com/cloud-build/builds?project=$PROJECT_ID_DEV"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi