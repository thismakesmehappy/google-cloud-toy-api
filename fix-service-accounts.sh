#!/bin/bash

# Fix Service Account Issues
# Run this if you encounter IAM binding errors during setup

set -e

echo "🔧 Fixing Service Account IAM Issues"
echo "===================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Project IDs
DEV_PROJECT="toy-api-dev"
STAGING_PROJECT="toy-api-stage" 
PROD_PROJECT="toy-api-prod"

# Function to fix IAM bindings for a service account
fix_service_account() {
    local project=$1
    local env=$2
    local sa_name="github-actions-$env"
    local sa_email="$sa_name@$project.iam.gserviceaccount.com"
    
    echo -e "\n${YELLOW}🔧 Fixing service account for $env environment...${NC}"
    
    # Check if service account exists
    if ! gcloud iam service-accounts describe $sa_email --project=$project >/dev/null 2>&1; then
        echo -e "${RED}❌ Service account $sa_email does not exist${NC}"
        echo "Creating service account..."
        
        gcloud iam service-accounts create $sa_name \
            --display-name="GitHub Actions $env" \
            --project=$project
        
        echo "  ⏳ Waiting for service account to propagate..."
        sleep 15
    else
        echo -e "${GREEN}✅ Service account exists${NC}"
    fi
    
    # Grant roles with retry logic
    local roles=(
        "roles/cloudfunctions.admin"
        "roles/storage.admin" 
        "roles/apigateway.admin"
        "roles/datastore.owner"
        "roles/serviceusage.serviceUsageAdmin"
        "roles/iam.serviceAccountAdmin"
        "roles/run.admin"
    )
    
    echo "  🔑 Granting IAM roles..."
    for role in "${roles[@]}"; do
        echo "    Checking $role..."
        
        # Check if role is already granted
        if gcloud projects get-iam-policy $project \
            --flatten="bindings[].members" \
            --format="table(bindings.role)" \
            --filter="bindings.members:serviceAccount:$sa_email AND bindings.role:$role" | grep -q "$role"; then
            echo "      ✅ Already has $role"
        else
            echo "      🔄 Granting $role..."
            local retries=0
            while [ $retries -lt 3 ]; do
                if gcloud projects add-iam-policy-binding $project \
                    --member="serviceAccount:$sa_email" \
                    --role="$role" >/dev/null 2>&1; then
                    echo "      ✅ Successfully granted $role"
                    break
                else
                    echo "      ⏳ Retry $((retries+1))/3 for $role..."
                    sleep 5
                    ((retries++))
                fi
            done
            
            if [ $retries -eq 3 ]; then
                echo -e "      ${RED}❌ Failed to grant $role after 3 attempts${NC}"
            fi
        fi
    done
    
    echo -e "${GREEN}✅ Service account for $env environment fixed${NC}"
}

# Fix service accounts for existing projects
echo -e "\n${YELLOW}🔍 Checking projects...${NC}"

for project in $DEV_PROJECT $STAGING_PROJECT $PROD_PROJECT; do
    env=$(echo $project | cut -d'-' -f3)
    
    if gcloud projects describe $project >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Project $project exists${NC}"
        fix_service_account $project $env
    else
        echo -e "${YELLOW}⚠️  Project $project doesn't exist${NC}"
        if [ "$project" = "$DEV_PROJECT" ]; then
            echo -e "${RED}❌ Dev project is required but missing!${NC}"
            exit 1
        fi
    fi
done

echo -e "\n${GREEN}🎉 Service account issues fixed!${NC}"
echo ""
echo "Now you can:"
echo "1. Generate keys: gcloud iam service-accounts keys create github-actions-dev-key.json --iam-account=github-actions-dev@toy-api-dev.iam.gserviceaccount.com"
echo "2. Add the key contents to GitHub Secrets"
echo "3. Test the pipeline!"