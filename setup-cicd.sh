#!/bin/bash

# CI/CD Setup Script for Google Cloud Toy API
# Run this script to set up service accounts and permissions for GitHub Actions

set -e

echo "🚀 Setting up CI/CD for Google Cloud Toy API"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if gcloud is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo -e "${RED}❌ Error: gcloud is not authenticated${NC}"
    echo "Please run: gcloud auth login"
    exit 1
fi

echo -e "${GREEN}✅ gcloud authentication verified${NC}"

# Set project IDs
DEV_PROJECT="toy-api-dev"
STAGING_PROJECT="toy-api-stage" 
PROD_PROJECT="toy-api-prod"

echo "📋 Project IDs:"
echo "  Dev: $DEV_PROJECT"
echo "  Staging: $STAGING_PROJECT" 
echo "  Prod: $PROD_PROJECT"

# Function to create service account and grant permissions
create_service_account() {
    local project=$1
    local env=$2
    local sa_name="github-actions-$env"
    local sa_email="$sa_name@$project.iam.gserviceaccount.com"
    
    echo -e "\n${YELLOW}🔧 Setting up service account for $env environment...${NC}"
    
    # Create service account
    gcloud iam service-accounts create $sa_name \
        --display-name="GitHub Actions $env" \
        --project=$project || echo "Service account may already exist"
    
    # Grant necessary roles
    local roles=(
        "roles/cloudfunctions.admin"
        "roles/storage.admin"
        "roles/apigateway.admin"
        "roles/datastore.owner"
        "roles/serviceusage.serviceUsageAdmin"
        "roles/iam.serviceAccountAdmin"
        "roles/run.admin"
    )
    
    for role in "${roles[@]}"; do
        echo "  Granting $role..."
        gcloud projects add-iam-policy-binding $project \
            --member="serviceAccount:$sa_email" \
            --role="$role"
    done
    
    echo -e "${GREEN}✅ Service account for $env environment created${NC}"
}

# Function to generate service account keys
generate_keys() {
    local project=$1
    local env=$2
    local sa_name="github-actions-$env"
    local sa_email="$sa_name@$project.iam.gserviceaccount.com"
    local key_file="github-actions-$env-key.json"
    
    echo -e "\n${YELLOW}🔑 Generating key for $env environment...${NC}"
    
    gcloud iam service-accounts keys create $key_file \
        --iam-account=$sa_email \
        --project=$project
    
    echo -e "${GREEN}✅ Key saved to $key_file${NC}"
}

# Create service accounts for dev environment (we know this project exists)
echo -e "\n${YELLOW}🏗️  Creating service accounts...${NC}"
create_service_account $DEV_PROJECT "dev"

# Check if staging and prod projects exist, create service accounts if they do
for project in $STAGING_PROJECT $PROD_PROJECT; do
    env=$(echo $project | cut -d'-' -f3)
    if gcloud projects describe $project >/dev/null 2>&1; then
        create_service_account $project $env
    else
        echo -e "${YELLOW}⚠️  Project $project doesn't exist. Skipping for now.${NC}"
        echo "   You can create it later with: gcloud projects create $project"
    fi
done

# Generate keys
echo -e "\n${YELLOW}🔑 Generating service account keys...${NC}"
generate_keys $DEV_PROJECT "dev"

# Only generate keys for staging/prod if projects exist
for project in $STAGING_PROJECT $PROD_PROJECT; do
    env=$(echo $project | cut -d'-' -f3)
    if gcloud projects describe $project >/dev/null 2>&1; then
        generate_keys $project $env
    fi
done

echo -e "\n${GREEN}🎉 CI/CD setup complete!${NC}"
echo ""
echo "📝 Next steps:"
echo "1. Create a GitHub repository for this project"
echo "2. Add the following secrets to your GitHub repository:"
echo "   Settings > Secrets and variables > Actions"
echo ""
echo "   Required secrets:"
echo "   - GCP_SA_KEY_DEV: Contents of github-actions-dev-key.json"
echo "   - GCP_PROJECT_ID_DEV: $DEV_PROJECT"
echo "   - DEV_API_KEY: dev-api-key-123"

if gcloud projects describe $STAGING_PROJECT >/dev/null 2>&1; then
    echo "   - GCP_SA_KEY_STAGING: Contents of github-actions-staging-key.json"
    echo "   - GCP_PROJECT_ID_STAGING: $STAGING_PROJECT"
    echo "   - STAGING_API_KEY: staging-api-key-456"
fi

if gcloud projects describe $PROD_PROJECT >/dev/null 2>&1; then
    echo "   - GCP_SA_KEY_PROD: Contents of github-actions-prod-key.json"
    echo "   - GCP_PROJECT_ID_PROD: $PROD_PROJECT"
fi

echo ""
echo "3. Push your code to GitHub:"
echo "   git add ."
echo "   git commit -m 'Add CI/CD pipeline and modular infrastructure'"
echo "   git push origin main"
echo ""
echo "4. The GitHub Actions workflow will automatically run on the next push!"

# Clean up - move keys to a secure location
if [ -f "github-actions-dev-key.json" ]; then
    mkdir -p .github-keys
    mv *.json .github-keys/ 2>/dev/null || true
    echo ""
    echo -e "${YELLOW}🔒 Service account keys moved to .github-keys/ directory${NC}"
    echo -e "${RED}⚠️  IMPORTANT: Keep these keys secure and add .github-keys/ to .gitignore${NC}"
fi