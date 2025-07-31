#!/bin/bash

# Advanced Deployment Strategies Setup for Google Cloud Toy API
# Implements staging promotion workflows, blue-green deployments, and canary releases

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
REGION="us-central1"
GITHUB_OWNER="YOUR_GITHUB_USERNAME"  # Update this with your GitHub username
REPO_NAME="TestGoogleAPI"

echo -e "${BLUE}🚀 Setting up Advanced Deployment Strategies${NC}"
echo -e "${BLUE}=============================================${NC}"

# Create staging promotion workflow
create_staging_promotion_workflow() {
    echo -e "\n${YELLOW}📋 Creating staging promotion workflow${NC}"
    
    mkdir -p .github/workflows
    
    cat > .github/workflows/staging-promotion.yml << 'EOF'
name: Staging Promotion Workflow

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to promote from'
        required: true
        default: 'dev'
        type: choice
        options:
        - dev
        - staging
      target_environment:
        description: 'Environment to promote to'
        required: true
        default: 'staging'
        type: choice
        options:
        - staging
        - prod
      image_tag:
        description: 'Image tag to promote (leave empty for latest)'
        required: false
        type: string

jobs:
  promote:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Authenticate to Google Cloud
      uses: google-github-actions/auth@v2
      with:
        credentials_json: ${{ secrets.GCP_SA_KEY }}

    - name: Set up Cloud SDK
      uses: google-github-actions/setup-gcloud@v2

    - name: Determine image tag
      id: image_tag
      run: |
        if [ -z "${{ github.event.inputs.image_tag }}" ]; then
          # Get latest image from source environment
          case "${{ github.event.inputs.environment }}" in
            "dev")
              PROJECT_ID="toy-api-dev"
              ;;
            "staging")
              PROJECT_ID="toy-api-staging"
              ;;
          esac
          
          # Get the latest deployed image
          CURRENT_IMAGE=$(gcloud run services describe toy-api-service-${{ github.event.inputs.environment }} \
            --project=$PROJECT_ID \
            --region=us-central1 \
            --format='value(spec.template.spec.template.spec.containers[0].image)')
          
          IMAGE_TAG=$(echo $CURRENT_IMAGE | cut -d: -f2)
          echo "tag=$IMAGE_TAG" >> $GITHUB_OUTPUT
        else
          echo "tag=${{ github.event.inputs.image_tag }}" >> $GITHUB_OUTPUT
        fi

    - name: Set target project
      id: target_project
      run: |
        case "${{ github.event.inputs.target_environment }}" in
          "staging")
            echo "project=toy-api-staging" >> $GITHUB_OUTPUT
            ;;
          "prod")
            echo "project=toy-api-prod" >> $GITHUB_OUTPUT
            ;;
        esac

    - name: Copy image to target registry
      run: |
        SOURCE_IMAGE="gcr.io/toy-api-dev/toy-api:${{ steps.image_tag.outputs.tag }}"
        TARGET_IMAGE="gcr.io/${{ steps.target_project.outputs.project }}/toy-api:${{ steps.image_tag.outputs.tag }}"
        
        echo "Copying $SOURCE_IMAGE to $TARGET_IMAGE"
        gcloud container images add-tag $SOURCE_IMAGE $TARGET_IMAGE --quiet

    - name: Deploy to target environment
      run: |
        TARGET_IMAGE="gcr.io/${{ steps.target_project.outputs.project }}/toy-api:${{ steps.image_tag.outputs.tag }}"
        
        gcloud run deploy toy-api-service-${{ github.event.inputs.target_environment }} \
          --image=$TARGET_IMAGE \
          --project=${{ steps.target_project.outputs.project }} \
          --region=us-central1 \
          --allow-unauthenticated \
          --quiet

    - name: Run integration tests
      run: |
        # Wait for deployment to stabilize
        sleep 30
        
        # Get service URL
        SERVICE_URL=$(gcloud run services describe toy-api-service-${{ github.event.inputs.target_environment }} \
          --project=${{ steps.target_project.outputs.project }} \
          --region=us-central1 \
          --format='value(status.url)')
        
        # Run integration tests
        ./test-integration.sh $SERVICE_URL "test-api-key" ${{ github.event.inputs.target_environment }}

    - name: Create promotion record
      run: |
        echo "✅ Successfully promoted from ${{ github.event.inputs.environment }} to ${{ github.event.inputs.target_environment }}"
        echo "🏷️  Image tag: ${{ steps.image_tag.outputs.tag }}"
        echo "📅 Promoted at: $(date -u)"
        echo "👤 Promoted by: ${{ github.actor }}"
EOF

    echo -e "${GREEN}✅ Staging promotion workflow created${NC}"
}

# Create blue-green deployment script
create_blue_green_deployment() {
    echo -e "\n${YELLOW}🔵 Creating blue-green deployment script${NC}"
    
    cat > blue-green-deploy.sh << 'EOF'
#!/bin/bash

# Blue-Green Deployment Script for Google Cloud Run
# Provides zero-downtime deployments with automatic rollback capability

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
ENVIRONMENT=${1:-"dev"}
IMAGE_TAG=${2:-"latest"}
PROJECT_ID=""
SERVICE_NAME="toy-api-service-${ENVIRONMENT}"
REGION="us-central1"

# Set project based on environment
case $ENVIRONMENT in
    "dev")
        PROJECT_ID="toy-api-dev"
        ;;
    "staging")
        PROJECT_ID="toy-api-staging"
        ;;
    "prod")
        PROJECT_ID="toy-api-prod"
        ;;
    *)
        echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
        echo "Usage: $0 <environment> [image_tag]"
        echo "Environments: dev, staging, prod"
        exit 1
        ;;
esac

echo -e "${BLUE}🔵 Starting Blue-Green Deployment${NC}"
echo -e "${BLUE}Environment: $ENVIRONMENT${NC}"
echo -e "${BLUE}Project: $PROJECT_ID${NC}"
echo -e "${BLUE}Service: $SERVICE_NAME${NC}"
echo -e "${BLUE}Image Tag: $IMAGE_TAG${NC}"

# Step 1: Get current (blue) service configuration
echo -e "\n${YELLOW}📋 Getting current service configuration...${NC}"
gcloud config set project $PROJECT_ID

# Check if service exists
if ! gcloud run services describe $SERVICE_NAME --region=$REGION &>/dev/null; then
    echo -e "${YELLOW}⚠️  Service doesn't exist, performing initial deployment${NC}"
    gcloud run deploy $SERVICE_NAME \
        --image="gcr.io/$PROJECT_ID/toy-api:$IMAGE_TAG" \
        --region=$REGION \
        --allow-unauthenticated \
        --quiet
    echo -e "${GREEN}✅ Initial deployment completed${NC}"
    exit 0
fi

# Get current service URL
BLUE_URL=$(gcloud run services describe $SERVICE_NAME \
    --region=$REGION \
    --format='value(status.url)')

echo -e "${BLUE}Current (Blue) service URL: $BLUE_URL${NC}"

# Step 2: Deploy green service (new version)
GREEN_SERVICE_NAME="${SERVICE_NAME}-green"
echo -e "\n${YELLOW}🟢 Deploying Green service with new image...${NC}"

gcloud run deploy $GREEN_SERVICE_NAME \
    --image="gcr.io/$PROJECT_ID/toy-api:$IMAGE_TAG" \
    --region=$REGION \
    --allow-unauthenticated \
    --quiet

# Get green service URL
GREEN_URL=$(gcloud run services describe $GREEN_SERVICE_NAME \
    --region=$REGION \
    --format='value(status.url)')

echo -e "${GREEN}Green service deployed: $GREEN_URL${NC}"

# Step 3: Health check on green service
echo -e "\n${YELLOW}🏥 Performing health checks on Green service...${NC}"
sleep 10  # Allow service to stabilize

# Health check
HEALTH_CHECK_PASSED=false
for i in {1..5}; do
    echo -e "${BLUE}Health check attempt $i/5...${NC}"
    if curl -s -f "$GREEN_URL/" > /dev/null; then
        echo -e "${GREEN}✅ Health check passed${NC}"
        HEALTH_CHECK_PASSED=true
        break
    else
        echo -e "${YELLOW}⚠️  Health check failed, retrying in 10 seconds...${NC}"
        sleep 10
    fi
done

if [ "$HEALTH_CHECK_PASSED" = false ]; then
    echo -e "${RED}❌ Health checks failed on Green service${NC}"
    echo -e "${YELLOW}🗑️  Cleaning up failed Green deployment...${NC}"
    gcloud run services delete $GREEN_SERVICE_NAME --region=$REGION --quiet
    exit 1
fi

# Step 4: Run integration tests on green service
echo -e "\n${YELLOW}🧪 Running integration tests on Green service...${NC}"
if ./test-integration.sh "$GREEN_URL" "test-api-key" "$ENVIRONMENT" > /tmp/green-test-results.log 2>&1; then
    echo -e "${GREEN}✅ Integration tests passed on Green service${NC}"
else
    echo -e "${RED}❌ Integration tests failed on Green service${NC}"
    echo -e "${YELLOW}📋 Test results:${NC}"
    cat /tmp/green-test-results.log
    echo -e "${YELLOW}🗑️  Cleaning up failed Green deployment...${NC}"
    gcloud run services delete $GREEN_SERVICE_NAME --region=$REGION --quiet
    exit 1
fi

# Step 5: Switch traffic to green (blue-green swap)
echo -e "\n${YELLOW}🔄 Switching traffic to Green service...${NC}"

# Get the current blue service's configuration for backup
gcloud run services describe $SERVICE_NAME \
    --region=$REGION \
    --format='export' > /tmp/blue-service-backup.yaml

# Update the main service to use the green image
gcloud run deploy $SERVICE_NAME \
    --image="gcr.io/$PROJECT_ID/toy-api:$IMAGE_TAG" \
    --region=$REGION \
    --allow-unauthenticated \
    --quiet

echo -e "${GREEN}✅ Traffic switched to new version${NC}"

# Step 6: Final verification
echo -e "\n${YELLOW}🔍 Final verification of updated service...${NC}"
sleep 15

FINAL_HEALTH_PASSED=false
for i in {1..3}; do
    echo -e "${BLUE}Final health check attempt $i/3...${NC}"
    if curl -s -f "$BLUE_URL/" > /dev/null; then
        echo -e "${GREEN}✅ Final health check passed${NC}"
        FINAL_HEALTH_PASSED=true
        break
    else
        echo -e "${YELLOW}⚠️  Final health check failed, retrying...${NC}"
        sleep 10
    fi
done

if [ "$FINAL_HEALTH_PASSED" = false ]; then
    echo -e "${RED}❌ Final health check failed - initiating rollback${NC}"
    
    # Rollback by restoring blue service
    gcloud run services replace /tmp/blue-service-backup.yaml --region=$REGION --quiet
    echo -e "${YELLOW}🔄 Rollback completed${NC}"
    
    # Cleanup
    gcloud run services delete $GREEN_SERVICE_NAME --region=$REGION --quiet
    exit 1
fi

# Step 7: Cleanup old green service
echo -e "\n${YELLOW}🗑️  Cleaning up temporary Green service...${NC}"
gcloud run services delete $GREEN_SERVICE_NAME --region=$REGION --quiet

echo -e "\n${GREEN}🎉 Blue-Green Deployment Completed Successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e "${BLUE}Service URL: $BLUE_URL${NC}"
echo -e "${BLUE}New Image: gcr.io/$PROJECT_ID/toy-api:$IMAGE_TAG${NC}"
echo -e "${BLUE}Environment: $ENVIRONMENT${NC}"
echo -e "${YELLOW}💾 Blue service backup saved to: /tmp/blue-service-backup.yaml${NC}"
EOF

    chmod +x blue-green-deploy.sh
    echo -e "${GREEN}✅ Blue-green deployment script created${NC}"
}

# Create canary release script
create_canary_deployment() {
    echo -e "\n${YELLOW}🐤 Creating canary deployment script${NC}"
    
    cat > canary-deploy.sh << 'EOF'
#!/bin/bash

# Canary Deployment Script for Google Cloud Run
# Gradually shifts traffic from 10% → 50% → 100%

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
ENVIRONMENT=${1:-"dev"}
IMAGE_TAG=${2:-"latest"}
AUTO_PROMOTE=${3:-"false"}  # Set to "true" for automatic promotion
PROJECT_ID=""
SERVICE_NAME="toy-api-service-${ENVIRONMENT}"
CANARY_SERVICE_NAME="${SERVICE_NAME}-canary"
REGION="us-central1"

# Set project based on environment
case $ENVIRONMENT in
    "dev")
        PROJECT_ID="toy-api-dev"
        ;;
    "staging")
        PROJECT_ID="toy-api-staging"
        ;;
    "prod")
        PROJECT_ID="toy-api-prod"
        ;;
    *)
        echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
        echo "Usage: $0 <environment> [image_tag] [auto_promote]"
        exit 1
        ;;
esac

echo -e "${BLUE}🐤 Starting Canary Deployment${NC}"
echo -e "${BLUE}Environment: $ENVIRONMENT${NC}"
echo -e "${BLUE}Image Tag: $IMAGE_TAG${NC}"
echo -e "${BLUE}Auto Promote: $AUTO_PROMOTE${NC}"

gcloud config set project $PROJECT_ID

# Function to check service health
check_service_health() {
    local service_url=$1
    local max_attempts=5
    
    for i in $(seq 1 $max_attempts); do
        if curl -s -f "$service_url/" > /dev/null; then
            return 0
        fi
        sleep 5
    done
    return 1
}

# Function to run integration tests
run_integration_tests() {
    local service_url=$1
    echo -e "${BLUE}Running integration tests on $service_url${NC}"
    
    if ./test-integration.sh "$service_url" "test-api-key" "$ENVIRONMENT" > /tmp/canary-test-results.log 2>&1; then
        echo -e "${GREEN}✅ Integration tests passed${NC}"
        return 0
    else
        echo -e "${RED}❌ Integration tests failed${NC}"
        cat /tmp/canary-test-results.log
        return 1
    fi
}

# Step 1: Deploy canary service
echo -e "\n${YELLOW}🚀 Deploying canary service...${NC}"

gcloud run deploy $CANARY_SERVICE_NAME \
    --image="gcr.io/$PROJECT_ID/toy-api:$IMAGE_TAG" \
    --region=$REGION \
    --allow-unauthenticated \
    --quiet

CANARY_URL=$(gcloud run services describe $CANARY_SERVICE_NAME \
    --region=$REGION \
    --format='value(status.url)')

echo -e "${GREEN}Canary service deployed: $CANARY_URL${NC}"

# Step 2: Health check canary
echo -e "\n${YELLOW}🏥 Health checking canary service...${NC}"
if ! check_service_health "$CANARY_URL"; then
    echo -e "${RED}❌ Canary health check failed${NC}"
    gcloud run services delete $CANARY_SERVICE_NAME --region=$REGION --quiet
    exit 1
fi

# Step 3: Run tests on canary
if ! run_integration_tests "$CANARY_URL"; then
    echo -e "${RED}❌ Canary tests failed, rolling back${NC}"
    gcloud run services delete $CANARY_SERVICE_NAME --region=$REGION --quiet
    exit 1
fi

echo -e "${GREEN}✅ Canary service is healthy and tests pass${NC}"

# Traffic shifting phases
traffic_phases=(10 50 100)
phase_names=("Initial Canary (10%)" "Expanded Canary (50%)" "Full Deployment (100%)")

for i in "${!traffic_phases[@]}"; do
    traffic=${traffic_phases[$i]}
    phase_name=${phase_names[$i]}
    
    echo -e "\n${BLUE}📊 Phase $((i+1)): $phase_name${NC}"
    
    if [ $traffic -eq 100 ]; then
        # Full deployment - replace main service
        echo -e "${YELLOW}🔄 Replacing main service with canary version...${NC}"
        gcloud run deploy $SERVICE_NAME \
            --image="gcr.io/$PROJECT_ID/toy-api:$IMAGE_TAG" \
            --region=$REGION \
            --allow-unauthenticated \
            --quiet
        
        # Cleanup canary service
        echo -e "${YELLOW}🗑️  Cleaning up canary service...${NC}"
        gcloud run services delete $CANARY_SERVICE_NAME --region=$REGION --quiet
        
        echo -e "${GREEN}✅ Full deployment completed${NC}"
        break
    else
        # Traffic splitting using Cloud Load Balancer would be implemented here
        # For now, we simulate monitoring
        echo -e "${YELLOW}📈 Simulating $traffic% traffic to canary...${NC}"
        echo -e "${BLUE}In a production setup, this would configure:${NC}"
        echo -e "${BLUE}- Cloud Load Balancer with traffic splitting${NC}"
        echo -e "${BLUE}- $traffic% traffic to canary: $CANARY_URL${NC}"
        echo -e "${BLUE}- $((100-traffic))% traffic to stable: $(gcloud run services describe $SERVICE_NAME --region=$REGION --format='value(status.url)')${NC}"
        
        # Monitoring period
        monitor_duration=300  # 5 minutes
        echo -e "${YELLOW}⏱️  Monitoring for $monitor_duration seconds...${NC}"
        
        if [ "$AUTO_PROMOTE" = "true" ]; then
            echo -e "${BLUE}🤖 Auto-promotion enabled, monitoring automatically...${NC}"
            sleep $monitor_duration
            
            # Health check during monitoring
            if check_service_health "$CANARY_URL"; then
                echo -e "${GREEN}✅ Canary stable during monitoring period${NC}"
            else
                echo -e "${RED}❌ Canary failed during monitoring, rolling back${NC}"
                gcloud run services delete $CANARY_SERVICE_NAME --region=$REGION --quiet
                exit 1
            fi
        else
            echo -e "${YELLOW}❓ Manual approval required. Continue to next phase? (y/N)${NC}"
            read -r continue_deployment
            if [[ ! $continue_deployment =~ ^[Yy]$ ]]; then
                echo -e "${YELLOW}🛑 Deployment paused by user${NC}"
                echo -e "${BLUE}Canary service remains at: $CANARY_URL${NC}"
                echo -e "${BLUE}To continue: $0 $ENVIRONMENT $IMAGE_TAG true${NC}"
                echo -e "${BLUE}To rollback: gcloud run services delete $CANARY_SERVICE_NAME --region=$REGION${NC}"
                exit 0
            fi
        fi
    fi
done

MAIN_URL=$(gcloud run services describe $SERVICE_NAME \
    --region=$REGION \
    --format='value(status.url)')

echo -e "\n${GREEN}🎉 Canary Deployment Completed Successfully!${NC}"
echo -e "${GREEN}=======================================${NC}"
echo -e "${BLUE}Final Service URL: $MAIN_URL${NC}"
echo -e "${BLUE}Deployed Image: gcr.io/$PROJECT_ID/toy-api:$IMAGE_TAG${NC}"
echo -e "${BLUE}Environment: $ENVIRONMENT${NC}"
EOF

    chmod +x canary-deploy.sh
    echo -e "${GREEN}✅ Canary deployment script created${NC}"
}

# Create feature flags implementation
create_feature_flags() {
    echo -e "\n${YELLOW}🚩 Creating feature flags implementation${NC}"
    
    # Create feature flags service
    cat > google-cloud-toy-api/src/services/feature-flags.ts << 'EOF'
import { Firestore } from '@google-cloud/firestore';

interface FeatureFlag {
  name: string;
  enabled: boolean;
  description: string;
  environments: string[];
  rolloutPercentage: number;
  createdAt: Date;
  updatedAt: Date;
}

export class FeatureFlagService {
  private db: Firestore;
  private environment: string;
  private cache: Map<string, FeatureFlag> = new Map();
  private cacheExpiry: Map<string, number> = new Map();
  private cacheTTL = 5 * 60 * 1000; // 5 minutes

  constructor(db: Firestore, environment: string = 'dev') {
    this.db = db;
    this.environment = environment;
  }

  /**
   * Check if a feature flag is enabled for the current environment
   */
  async isFeatureEnabled(flagName: string, userId?: string): Promise<boolean> {
    try {
      const flag = await this.getFeatureFlag(flagName);
      
      if (!flag) {
        // Default to disabled if flag doesn't exist
        return false;
      }

      // Check if environment is supported
      if (!flag.environments.includes(this.environment)) {
        return false;
      }

      // If globally disabled
      if (!flag.enabled) {
        return false;
      }

      // Check rollout percentage
      if (flag.rolloutPercentage < 100) {
        // Use userId for consistent rollout, or random if not provided
        const seed = userId || Math.random().toString();
        const hash = this.simpleHash(seed);
        const userPercentage = hash % 100;
        return userPercentage < flag.rolloutPercentage;
      }

      return true;
    } catch (error) {
      console.error(`Error checking feature flag ${flagName}:`, error);
      // Fail safe - return false if there's an error
      return false;
    }
  }

  /**
   * Get all feature flags for the current environment
   */
  async getAllFeatureFlags(): Promise<Record<string, boolean>> {
    try {
      const flagsRef = this.db.collection('feature-flags');
      const snapshot = await flagsRef.get();
      
      const flags: Record<string, boolean> = {};
      
      for (const doc of snapshot.docs) {
        const flag = doc.data() as FeatureFlag;
        flags[flag.name] = await this.isFeatureEnabled(flag.name);
      }
      
      return flags;
    } catch (error) {
      console.error('Error getting all feature flags:', error);
      return {};
    }
  }

  /**
   * Create or update a feature flag (admin operation)
   */
  async setFeatureFlag(flagData: Partial<FeatureFlag>): Promise<void> {
    try {
      const flagRef = this.db.collection('feature-flags').doc(flagData.name!);
      
      const existingFlag = await flagRef.get();
      const now = new Date();
      
      const flag: FeatureFlag = {
        name: flagData.name!,
        enabled: flagData.enabled ?? false,
        description: flagData.description ?? '',
        environments: flagData.environments ?? ['dev'],
        rolloutPercentage: flagData.rolloutPercentage ?? 0,
        createdAt: existingFlag.exists ? existingFlag.data()!.createdAt : now,
        updatedAt: now
      };
      
      await flagRef.set(flag);
      
      // Clear cache for this flag
      this.cache.delete(flagData.name!);
      this.cacheExpiry.delete(flagData.name!);
      
      console.log(`Feature flag ${flagData.name} updated:`, flag);
    } catch (error) {
      console.error(`Error setting feature flag ${flagData.name}:`, error);
      throw error;
    }
  }

  /**
   * Delete a feature flag (admin operation)
   */
  async deleteFeatureFlag(flagName: string): Promise<void> {
    try {
      const flagRef = this.db.collection('feature-flags').doc(flagName);
      await flagRef.delete();
      
      // Clear cache
      this.cache.delete(flagName);
      this.cacheExpiry.delete(flagName);
      
      console.log(`Feature flag ${flagName} deleted`);
    } catch (error) {
      console.error(`Error deleting feature flag ${flagName}:`, error);
      throw error;
    }
  }

  /**
   * Get a feature flag from cache or database
   */
  private async getFeatureFlag(flagName: string): Promise<FeatureFlag | null> {
    // Check cache first
    const cached = this.cache.get(flagName);
    const cacheExpiry = this.cacheExpiry.get(flagName);
    
    if (cached && cacheExpiry && Date.now() < cacheExpiry) {
      return cached;
    }

    // Fetch from database
    try {
      const flagRef = this.db.collection('feature-flags').doc(flagName);
      const doc = await flagRef.get();
      
      if (!doc.exists) {
        return null;
      }
      
      const flag = doc.data() as FeatureFlag;
      
      // Update cache
      this.cache.set(flagName, flag);
      this.cacheExpiry.set(flagName, Date.now() + this.cacheTTL);
      
      return flag;
    } catch (error) {
      console.error(`Error fetching feature flag ${flagName}:`, error);
      return null;
    }
  }

  /**
   * Simple hash function for consistent user rollout
   */
  private simpleHash(str: string): number {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32-bit integer
    }
    return Math.abs(hash);
  }

  /**
   * Middleware for Express to add feature flags to request
   */
  expressMiddleware() {
    return async (req: any, res: any, next: any) => {
      try {
        // Get user ID from request (from auth middleware)
        const userId = req.user?.uid;
        
        // Add feature flag helper to request
        req.featureFlags = {
          isEnabled: async (flagName: string) => {
            return await this.isFeatureEnabled(flagName, userId);
          },
          getAll: async () => {
            return await this.getAllFeatureFlags();
          }
        };
        
        next();
      } catch (error) {
        console.error('Feature flags middleware error:', error);
        // Don't fail the request, just skip feature flags
        req.featureFlags = {
          isEnabled: async () => false,
          getAll: async () => ({})
        };
        next();
      }
    };
  }
}
EOF

    # Create feature flags admin endpoints
    cat > google-cloud-toy-api/src/functions/feature-flags.ts << 'EOF'
import { Request, Response } from 'express';
import { FeatureFlagService } from '../services/feature-flags';
import { db } from '../services/firestore';

const environment = process.env.NODE_ENV || 'dev';
const featureFlagsService = new FeatureFlagService(db, environment);

/**
 * Get all feature flags for current environment
 */
export const getFeatureFlags = async (req: Request, res: Response) => {
  try {
    const flags = await featureFlagsService.getAllFeatureFlags();
    
    res.json({
      success: true,
      environment,
      flags
    });
  } catch (error) {
    console.error('Error getting feature flags:', error);
    res.status(500).json({
      error: 'Failed to get feature flags',
      details: error instanceof Error ? error.message : 'Unknown error'
    });
  }
};

/**
 * Check if a specific feature flag is enabled
 */
export const checkFeatureFlag = async (req: Request, res: Response) => {
  try {
    const { flagName } = req.params;
    const userId = (req as any).user?.uid;
    
    if (!flagName) {
      return res.status(400).json({
        error: 'Flag name is required'
      });
    }
    
    const isEnabled = await featureFlagsService.isFeatureEnabled(flagName, userId);
    
    res.json({
      success: true,
      flagName,
      enabled: isEnabled,
      environment,
      userId: userId || 'anonymous'
    });
  } catch (error) {
    console.error('Error checking feature flag:', error);
    res.status(500).json({
      error: 'Failed to check feature flag',
      details: error instanceof Error ? error.message : 'Unknown error'
    });
  }
};

/**
 * Create or update a feature flag (admin only)
 */
export const setFeatureFlag = async (req: Request, res: Response) => {
  try {
    const { name, enabled, description, environments, rolloutPercentage } = req.body;
    
    if (!name) {
      return res.status(400).json({
        error: 'Flag name is required'
      });
    }
    
    await featureFlagsService.setFeatureFlag({
      name,
      enabled: enabled ?? false,
      description: description ?? '',
      environments: environments ?? [environment],
      rolloutPercentage: rolloutPercentage ?? 0
    });
    
    res.json({
      success: true,
      message: `Feature flag ${name} updated successfully`,
      flag: {
        name,
        enabled,
        description,
        environments,
        rolloutPercentage
      }
    });
  } catch (error) {
    console.error('Error setting feature flag:', error);
    res.status(500).json({
      error: 'Failed to set feature flag',
      details: error instanceof Error ? error.message : 'Unknown error'
    });
  }
};

/**
 * Delete a feature flag (admin only)
 */
export const deleteFeatureFlag = async (req: Request, res: Response) => {
  try {
    const { flagName } = req.params;
    
    if (!flagName) {
      return res.status(400).json({
        error: 'Flag name is required'
      });
    }
    
    await featureFlagsService.deleteFeatureFlag(flagName);
    
    res.json({
      success: true,
      message: `Feature flag ${flagName} deleted successfully`
    });
  } catch (error) {
    console.error('Error deleting feature flag:', error);
    res.status(500).json({
      error: 'Failed to delete feature flag',
      details: error instanceof Error ? error.message : 'Unknown error'
    });
  }
};
EOF

    echo -e "${GREEN}✅ Feature flags implementation created${NC}"
}

# Create deployment promotion script
create_deployment_promotion() {
    echo -e "\n${YELLOW}🔄 Creating deployment promotion script${NC}"
    
    cat > promote-deployment.sh << 'EOF'
#!/bin/bash

# Deployment Promotion Script
# Promotes deployments through environments: dev → staging → prod

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SOURCE_ENV=${1}
TARGET_ENV=${2}
STRATEGY=${3:-"standard"}  # standard, blue-green, canary

if [ -z "$SOURCE_ENV" ] || [ -z "$TARGET_ENV" ]; then
    echo -e "${RED}Usage: $0 <source_env> <target_env> [strategy]${NC}"
    echo -e "${BLUE}Environments: dev, staging, prod${NC}"
    echo -e "${BLUE}Strategies: standard, blue-green, canary${NC}"
    echo -e "${BLUE}Examples:${NC}"
    echo -e "${BLUE}  $0 dev staging standard${NC}"
    echo -e "${BLUE}  $0 staging prod blue-green${NC}"
    echo -e "${BLUE}  $0 dev staging canary${NC}"
    exit 1
fi

# Validate promotion path
case "$SOURCE_ENV-$TARGET_ENV" in
    "dev-staging"|"staging-prod")
        echo -e "${GREEN}✅ Valid promotion path: $SOURCE_ENV → $TARGET_ENV${NC}"
        ;;
    "dev-prod")
        echo -e "${YELLOW}⚠️  Skipping staging environment. Recommended to promote dev → staging → prod${NC}"
        read -p "Continue anyway? (y/N): " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            exit 1
        fi
        ;;
    *)
        echo -e "${RED}❌ Invalid promotion path: $SOURCE_ENV → $TARGET_ENV${NC}"
        echo -e "${BLUE}Valid paths: dev→staging, staging→prod, dev→prod${NC}"
        exit 1
        ;;
esac

# Get current image from source environment
echo -e "\n${BLUE}🔍 Getting current deployment from $SOURCE_ENV...${NC}"

PROJECT_ID_SOURCE=""
case $SOURCE_ENV in
    "dev") PROJECT_ID_SOURCE="toy-api-dev" ;;
    "staging") PROJECT_ID_SOURCE="toy-api-staging" ;;
    "prod") PROJECT_ID_SOURCE="toy-api-prod" ;;
esac

CURRENT_IMAGE=$(gcloud run services describe toy-api-service-$SOURCE_ENV \
    --project=$PROJECT_ID_SOURCE \
    --region=us-central1 \
    --format='value(spec.template.spec.template.spec.containers[0].image)')

IMAGE_TAG=$(echo $CURRENT_IMAGE | cut -d: -f2)

echo -e "${BLUE}Source Image: $CURRENT_IMAGE${NC}"
echo -e "${BLUE}Image Tag: $IMAGE_TAG${NC}"

# Execute deployment based on strategy
echo -e "\n${BLUE}🚀 Executing $STRATEGY deployment to $TARGET_ENV...${NC}"

case $STRATEGY in
    "standard")
        # Use GitHub Actions workflow for staging promotion
        echo -e "${YELLOW}Triggering staging promotion workflow...${NC}"
        gh workflow run staging-promotion.yml \
            -f environment=$SOURCE_ENV \
            -f target_environment=$TARGET_ENV \
            -f image_tag=$IMAGE_TAG
        ;;
    "blue-green")
        ./blue-green-deploy.sh $TARGET_ENV $IMAGE_TAG
        ;;
    "canary")
        ./canary-deploy.sh $TARGET_ENV $IMAGE_TAG
        ;;
    *)
        echo -e "${RED}❌ Unknown deployment strategy: $STRATEGY${NC}"
        exit 1
        ;;
esac

echo -e "\n${GREEN}🎉 Promotion completed: $SOURCE_ENV → $TARGET_ENV${NC}"
echo -e "${GREEN}Strategy: $STRATEGY${NC}"
echo -e "${GREEN}Image: $CURRENT_IMAGE${NC}"
EOF

    chmod +x promote-deployment.sh
    echo -e "${GREEN}✅ Deployment promotion script created${NC}"
}

# Update main application to use feature flags
update_main_app_with_feature_flags() {
    echo -e "\n${YELLOW}🔧 Updating main application with feature flags${NC}"
    
    # Check if index.ts exists
    if [ ! -f "google-cloud-toy-api/src/index.ts" ]; then
        echo -e "${YELLOW}⚠️  index.ts not found, skipping app update${NC}"
        return 0
    fi
    
    # Add feature flags routes to index.ts
    cat >> google-cloud-toy-api/src/index.ts << 'EOF'

// Feature Flags endpoints (admin only - require API key)
import { 
  getFeatureFlags, 
  checkFeatureFlag, 
  setFeatureFlag, 
  deleteFeatureFlag 
} from './functions/feature-flags';
import { FeatureFlagService } from './services/feature-flags';
import { db } from './services/firestore';

// Initialize feature flags service
const environment = process.env.NODE_ENV || 'dev';
const featureFlagsService = new FeatureFlagService(db, environment);

// Add feature flags middleware
app.use(featureFlagsService.expressMiddleware());

// Feature flags admin endpoints (require API key)
app.get('/admin/feature-flags', authenticateApiKey, getFeatureFlags);
app.get('/admin/feature-flags/:flagName', authenticateApiKey, checkFeatureFlag);
app.post('/admin/feature-flags', authenticateApiKey, setFeatureFlag);
app.delete('/admin/feature-flags/:flagName', authenticateApiKey, deleteFeatureFlag);

// Example of using feature flags in endpoints
app.get('/features/new-ui', async (req, res) => {
  const isEnabled = await (req as any).featureFlags.isEnabled('new-ui');
  
  res.json({
    feature: 'new-ui',
    enabled: isEnabled,
    message: isEnabled ? 'New UI is enabled!' : 'Using classic UI'
  });
});
EOF

    echo -e "${GREEN}✅ Main application updated with feature flags${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}Starting Advanced Deployment Strategies setup...${NC}\n"
    
    # Check prerequisites
    if ! command -v gcloud &> /dev/null; then
        echo -e "${RED}❌ gcloud CLI not found${NC}"
        exit 1
    fi
    
    if ! command -v gh &> /dev/null; then
        echo -e "${YELLOW}⚠️  GitHub CLI not found. Some features will be limited.${NC}"
    fi
    
    echo -e "${BLUE}Creating advanced deployment strategies:${NC}"
    echo -e "✅ Staging promotion workflows (dev → staging → production)"
    echo -e "✅ Blue-green deployments for zero-downtime"
    echo -e "✅ Canary releases with gradual traffic migration"
    echo -e "✅ Feature flags for runtime feature control"
    
    read -p "Press Enter to continue..."
    
    # Create all deployment strategies
    create_staging_promotion_workflow
    create_blue_green_deployment
    create_canary_deployment
    create_feature_flags
    create_deployment_promotion
    update_main_app_with_feature_flags
    
    echo -e "\n${GREEN}🎉 Advanced Deployment Strategies Setup Complete!${NC}"
    echo -e "${GREEN}=================================================${NC}"
    echo -e "${BLUE}What was created:${NC}"
    echo -e "✅ GitHub Actions staging promotion workflow"
    echo -e "✅ Blue-green deployment script (./blue-green-deploy.sh)"
    echo -e "✅ Canary deployment script (./canary-deploy.sh)"
    echo -e "✅ Feature flags service and admin endpoints"
    echo -e "✅ Deployment promotion script (./promote-deployment.sh)"
    
    echo -e "\n${YELLOW}⚠️  Next steps:${NC}"
    echo -e "1. Update GITHUB_OWNER in .github/workflows/staging-promotion.yml"
    echo -e "2. Test deployment strategies in dev environment"
    echo -e "3. Configure GitHub secrets for automated workflows"
    echo -e "4. Set up initial feature flags in Firestore"
    
    echo -e "\n${BLUE}Usage examples:${NC}"
    echo -e "${YELLOW}# Blue-green deployment${NC}"
    echo -e "./blue-green-deploy.sh dev latest"
    echo -e "${YELLOW}# Canary deployment${NC}"
    echo -e "./canary-deploy.sh staging v1.2.3 true"
    echo -e "${YELLOW}# Promote between environments${NC}"
    echo -e "./promote-deployment.sh dev staging blue-green"
}

# Run main function
main "$@"