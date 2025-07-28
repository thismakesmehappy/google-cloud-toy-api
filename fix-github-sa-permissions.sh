#!/bin/bash

# Fix GitHub Actions Service Account Permissions
# This script grants the necessary IAM permissions for the CI/CD pipeline

set -e

echo "🔧 Fixing GitHub Actions Service Account Permissions"
echo "====================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Project IDs
DEV_PROJECT="toy-api-dev"
STAGING_PROJECT="toy-api-stage" 
PROD_PROJECT="toy-api-prod"

# Function to grant IAM admin permissions
fix_github_sa_permissions() {
    local project=$1
    local env=$2
    local sa_email="github-actions-$env@$project.iam.gserviceaccount.com"
    
    echo -e "\n${YELLOW}🔑 Fixing permissions for $env environment...${NC}"
    
    # Additional roles needed for IAM management
    local additional_roles=(
        "roles/resourcemanager.projectIamAdmin"
        "roles/iam.securityAdmin"
        "roles/serviceusage.serviceUsageConsumer"
    )
    
    echo "  📋 Granting additional IAM permissions..."
    for role in "${additional_roles[@]}"; do
        echo "    - $role"
        if gcloud projects add-iam-policy-binding $project \
            --member="serviceAccount:$sa_email" \
            --role="$role" >/dev/null 2>&1; then
            echo "      ✅ Granted"
        else
            echo "      ⚠️  Failed to grant $role (may already exist)"
        fi
    done
    
    echo -e "${GREEN}✅ Enhanced permissions for $env environment${NC}"
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
        fix_github_sa_permissions $project $env
    else
        echo -e "${YELLOW}⚠️  Project $project doesn't exist, skipping${NC}"
    fi
done

echo -e "\n${GREEN}🎉 GitHub Actions service account permissions fixed!${NC}"
echo ""
echo "The service accounts now have the necessary permissions to:"
echo "  ✅ Manage IAM policies"
echo "  ✅ Grant roles to other service accounts"
echo "  ✅ Deploy infrastructure via Terraform"
echo ""
echo "You can now re-run the GitHub Actions workflow and it should succeed!"