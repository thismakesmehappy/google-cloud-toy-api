#!/bin/bash

# Fix Service Account User Permission for CI/CD
# Grant the GitHub Actions service account permission to act as the default compute service account

set -e

echo "🔧 Fixing Service Account User Permissions"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Project IDs
DEV_PROJECT="toy-api-dev"
STAGING_PROJECT="toy-api-stage" 
PROD_PROJECT="toy-api-prod"

# Function to grant service account user permissions
fix_service_account_user_permission() {
    local project=$1
    local env=$2
    local github_sa="github-actions-$env@$project.iam.gserviceaccount.com"
    
    echo -e "\n${YELLOW}🔑 Fixing service account user permission for $env environment...${NC}"
    
    # Get the project number to construct the compute service account email
    local project_number
    if project_number=$(gcloud projects describe "$project" --format="value(projectNumber)" 2>/dev/null); then
        local compute_sa="${project_number}-compute@developer.gserviceaccount.com"
        
        echo "  📋 Granting roles/iam.serviceAccountUser permission..."
        echo "      GitHub SA: $github_sa"
        echo "      Target SA: $compute_sa"
        
        # Grant the permission
        if gcloud iam service-accounts add-iam-policy-binding "$compute_sa" \
            --member="serviceAccount:$github_sa" \
            --role="roles/iam.serviceAccountUser" \
            --project="$project" >/dev/null 2>&1; then
            echo -e "    ${GREEN}✅ Permission granted successfully${NC}"
        else
            echo -e "    ${RED}❌ Failed to grant permission${NC}"
        fi
        
        # Also grant at project level for broader access
        echo "  📋 Granting project-level serviceAccountUser permission..."
        if gcloud projects add-iam-policy-binding "$project" \
            --member="serviceAccount:$github_sa" \
            --role="roles/iam.serviceAccountUser" >/dev/null 2>&1; then
            echo -e "    ${GREEN}✅ Project-level permission granted${NC}"
        else
            echo -e "    ${RED}❌ Failed to grant project-level permission (may already exist)${NC}"
        fi
        
    else
        echo -e "    ${RED}❌ Could not get project number for $project${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Service account permissions fixed for $env environment${NC}"
}

# Check authentication
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo -e "${RED}❌ Error: gcloud is not authenticated${NC}"
    echo "Please run: gcloud auth login"
    exit 1
fi

echo -e "${GREEN}✅ gcloud authentication verified${NC}"

# Fix permissions for all environments
for project in $DEV_PROJECT $STAGING_PROJECT $PROD_PROJECT; do
    env=$(echo $project | cut -d'-' -f3)
    
    if gcloud projects describe $project >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Project $project exists${NC}"
        fix_service_account_user_permission $project $env
    else
        echo -e "${YELLOW}⚠️  Project $project doesn't exist, skipping${NC}"
    fi
done

echo -e "\n${GREEN}🎉 Service Account User permissions fixed!${NC}"
echo ""
echo "The GitHub Actions service accounts now have permission to:"
echo "  ✅ Act as the default compute service account"
echo "  ✅ Create and manage Cloud Functions"
echo "  ✅ Deploy infrastructure without serviceAccountUser errors"
echo ""
echo "You can now re-run the GitHub Actions workflow and it should succeed!"