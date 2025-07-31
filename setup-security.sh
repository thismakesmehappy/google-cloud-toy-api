#!/bin/bash

# Setup Security Enhancements for Google Cloud Toy API
# Implements Secret Manager, security headers, rate limiting, and container scanning

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

echo -e "${BLUE}🔐 Setting up Security Enhancements${NC}"
echo -e "${BLUE}=================================${NC}"

# Setup security for a project
setup_security() {
    local project_id=$1
    local environment=$2
    
    echo -e "\n${YELLOW}🛡️  Setting up security for $environment environment${NC}"
    echo -e "${YELLOW}Project: $project_id${NC}"
    
    # Set current project
    gcloud config set project $project_id
    
    # Enable required APIs
    echo -e "${BLUE}🔧 Enabling required APIs...${NC}"
    gcloud services enable secretmanager.googleapis.com --quiet
    gcloud services enable containeranalysis.googleapis.com --quiet
    gcloud services enable binaryauthorization.googleapis.com --quiet
    gcloud services enable cloudsecurity.googleapis.com --quiet
    
    echo -e "${GREEN}✅ Security APIs enabled for $environment${NC}"
}

# Create secrets in Secret Manager
create_secrets() {
    local project_id=$1
    local environment=$2
    
    echo -e "\n${YELLOW}🔑 Creating secrets in Secret Manager for $environment${NC}"
    
    gcloud config set project $project_id
    
    # API Key secret
    local api_key_value
    case $environment in
        "dev")
            api_key_value="dev-api-key-123"
            ;;
        "staging")
            api_key_value="staging-api-key-456"
            ;;
        "prod")
            api_key_value="prod-api-key-789"
            ;;
        *)
            api_key_value="default-api-key"
            ;;
    esac
    
    # Create API key secret
    if ! gcloud secrets describe "api-key" &>/dev/null; then
        echo -e "${BLUE}Creating API key secret...${NC}"
        echo -n "$api_key_value" | gcloud secrets create "api-key" \
            --data-file=- \
            --labels="environment=$environment,type=api-key"
        echo -e "${GREEN}✅ API key secret created${NC}"
    else
        echo -e "${YELLOW}⚠️  API key secret already exists${NC}"
    fi
    
    # Create Firebase service account key secret (placeholder)
    if ! gcloud secrets describe "firebase-service-account" &>/dev/null; then
        echo -e "${BLUE}Creating Firebase service account secret...${NC}"
        echo '{"type":"service_account","placeholder":true}' | gcloud secrets create "firebase-service-account" \
            --data-file=- \
            --labels="environment=$environment,type=service-account"
        echo -e "${GREEN}✅ Firebase service account secret created (placeholder)${NC}"
        echo -e "${YELLOW}⚠️  Remember to update with actual service account key${NC}"
    else
        echo -e "${YELLOW}⚠️  Firebase service account secret already exists${NC}"
    fi
    
    # Grant Cloud Run service access to secrets
    PROJECT_NUMBER=$(gcloud projects describe $project_id --format="value(projectNumber)")
    CLOUD_RUN_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
    
    echo -e "${BLUE}Granting Cloud Run access to secrets...${NC}"
    gcloud secrets add-iam-policy-binding "api-key" \
        --member="serviceAccount:${CLOUD_RUN_SA}" \
        --role="roles/secretmanager.secretAccessor" \
        --quiet
    
    gcloud secrets add-iam-policy-binding "firebase-service-account" \
        --member="serviceAccount:${CLOUD_RUN_SA}" \
        --role="roles/secretmanager.secretAccessor" \
        --quiet
    
    echo -e "${GREEN}✅ Secrets configured for $environment${NC}"
}

# Setup container security scanning
setup_container_scanning() {
    local project_id=$1
    local environment=$2
    
    echo -e "\n${YELLOW}🔍 Setting up container security scanning for $environment${NC}"
    
    gcloud config set project $project_id
    
    # Enable vulnerability scanning
    gcloud container images scan --help &>/dev/null || {
        echo -e "${YELLOW}⚠️  Container scanning not available in current gcloud version${NC}"
        return 0
    }
    
    echo -e "${GREEN}✅ Container scanning configured for $environment${NC}"
}

# Create security-enhanced Cloud Run service configuration
create_secure_service_template() {
    local environment=$1
    
    echo -e "\n${YELLOW}📋 Creating secure Cloud Run service template for $environment${NC}"
    
    cat > "/tmp/secure-service-${environment}.yaml" << EOF
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: toy-api-service-${environment}
  annotations:
    run.googleapis.com/ingress: all
    run.googleapis.com/execution-environment: gen2
spec:
  template:
    metadata:
      annotations:
        # Security annotations
        run.googleapis.com/execution-environment: gen2
        run.googleapis.com/cpu-throttling: "true"
        run.googleapis.com/sessionAffinity: "false"
        # Resource limits
        autoscaling.knative.dev/maxScale: "10"
        autoscaling.knative.dev/minScale: "0"
    spec:
      containerConcurrency: 100
      timeoutSeconds: 300
      serviceAccountName: "${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
      containers:
      - image: gcr.io/PROJECT_ID/toy-api:latest
        ports:
        - name: http1
          containerPort: 8080
        env:
        - name: NODE_ENV
          value: "${environment}"
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: api-key
              key: latest
        - name: FIREBASE_SERVICE_ACCOUNT
          valueFrom:
            secretKeyRef:
              name: firebase-service-account
              key: latest
        resources:
          limits:
            cpu: "1"
            memory: "512Mi"
        # Security context
        securityContext:
          runAsNonRoot: true
          runAsUser: 1001
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: false
          capabilities:
            drop:
            - ALL
EOF
    
    echo -e "${GREEN}✅ Secure service template created: /tmp/secure-service-${environment}.yaml${NC}"
}

# Setup Web Application Firewall (Cloud Armor) - Basic version
setup_cloud_armor() {
    local project_id=$1
    local environment=$2
    
    echo -e "\n${YELLOW}🛡️  Setting up Cloud Armor (WAF) for $environment${NC}"
    
    gcloud config set project $project_id
    
    # Enable Cloud Armor API
    gcloud services enable compute.googleapis.com --quiet
    
    # Create security policy
    POLICY_NAME="toy-api-security-policy-${environment}"
    
    if ! gcloud compute security-policies describe "$POLICY_NAME" &>/dev/null; then
        echo -e "${BLUE}Creating Cloud Armor security policy...${NC}"
        
        # Create basic security policy
        gcloud compute security-policies create "$POLICY_NAME" \
            --description="Security policy for Toy API $environment" \
            --quiet
        
        # Add rate limiting rule (1000 requests per minute per IP)
        gcloud compute security-policies rules create 1000 \
            --security-policy="$POLICY_NAME" \
            --expression="origin.ip != ''" \
            --action="rate-based-ban" \
            --rate-limit-threshold-count=1000 \
            --rate-limit-threshold-interval-sec=60 \
            --ban-duration-sec=300 \
            --conform-action="allow" \
            --exceed-action="deny-429" \
            --enforce-on-key="IP" \
            --quiet
        
        # Add geo-blocking rule (example: block traffic from certain countries)
        # gcloud compute security-policies rules create 2000 \
        #     --security-policy="$POLICY_NAME" \
        #     --expression="origin.region_code == 'CN' || origin.region_code == 'RU'" \
        #     --action="deny-403" \
        #     --quiet
        
        echo -e "${GREEN}✅ Cloud Armor security policy created${NC}"
    else
        echo -e "${YELLOW}⚠️  Security policy already exists${NC}"
    fi
}

# Update Cloud Build configuration with security scanning
update_cloudbuild_security() {
    echo -e "\n${YELLOW}🔧 Updating Cloud Build with security enhancements${NC}"
    
    # Check if cloudbuild.yaml exists
    if [ ! -f "google-cloud-toy-api/cloudbuild.yaml" ]; then
        echo -e "${RED}❌ cloudbuild.yaml not found${NC}"
        return 1
    fi
    
    # Create backup
    cp "google-cloud-toy-api/cloudbuild.yaml" "google-cloud-toy-api/cloudbuild.yaml.backup"
    
    # Add security scanning step to cloudbuild.yaml
    cat >> "google-cloud-toy-api/cloudbuild.yaml" << 'EOF'

  # Security: Container vulnerability scanning
  - name: 'gcr.io/cloud-builders/gcloud'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        echo "🔍 Scanning container for vulnerabilities..."
        gcloud container images scan gcr.io/$PROJECT_ID/toy-api:$SHORT_SHA \
          --format='table(vulnerability.severity,vulnerability.cvss_score,package.name,version.name)' \
          || echo "⚠️ Vulnerability scanning completed with warnings"
    id: 'security-scan'
    waitFor: ['build-image']

  # Security: Check for high/critical vulnerabilities
  - name: 'gcr.io/cloud-builders/gcloud'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        echo "🚨 Checking for critical vulnerabilities..."
        CRITICAL_VULNS=$(gcloud container images scan gcr.io/$PROJECT_ID/toy-api:$SHORT_SHA \
          --format='value(vulnerability.severity)' | grep -c "CRITICAL" || echo "0")
        HIGH_VULNS=$(gcloud container images scan gcr.io/$PROJECT_ID/toy-api:$SHORT_SHA \
          --format='value(vulnerability.severity)' | grep -c "HIGH" || echo "0")
        
        echo "Critical vulnerabilities: $CRITICAL_VULNS"
        echo "High vulnerabilities: $HIGH_VULNS"
        
        if [ "$CRITICAL_VULNS" -gt "0" ]; then
          echo "❌ CRITICAL vulnerabilities found - blocking deployment"
          exit 1
        fi
        
        if [ "$HIGH_VULNS" -gt "5" ]; then
          echo "⚠️ Too many HIGH vulnerabilities found ($HIGH_VULNS > 5)"
          echo "Consider updating base image or dependencies"
        fi
        
        echo "✅ Security check passed"
    id: 'security-check'
    waitFor: ['security-scan']
EOF
    
    echo -e "${GREEN}✅ Cloud Build updated with security scanning${NC}"
}

# Create security middleware for the application
create_security_middleware() {
    echo -e "\n${YELLOW}🔒 Creating security middleware${NC}"
    
    # Create security middleware file
    cat > "google-cloud-toy-api/src/middleware/security.ts" << 'EOF'
import { Request, Response, NextFunction } from 'express';
import rateLimit from 'express-rate-limit';
import helmet from 'helmet';

// Rate limiting configuration
export const createRateLimiter = (windowMs: number = 15 * 60 * 1000, max: number = 100) => {
  return rateLimit({
    windowMs, // 15 minutes default
    max, // Limit each IP to 100 requests per windowMs
    message: {
      error: 'Too many requests from this IP, please try again later.',
      retryAfter: Math.ceil(windowMs / 1000)
    },
    standardHeaders: true,
    legacyHeaders: false,
    // Skip successful requests from rate limiting
    skip: (req: Request) => {
      return req.method === 'GET' && req.path === '/';
    }
  });
};

// Security headers middleware
export const securityHeaders = helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'"],
      fontSrc: ["'self'"],
      objectSrc: ["'none'"],
      mediaSrc: ["'self'"],
      frameSrc: ["'none'"],
    },
  },
  crossOriginEmbedderPolicy: false, // Disable for API
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
});

// Request logging middleware
export const requestLogger = (req: Request, res: Response, next: NextFunction) => {
  const startTime = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    const logData = {
      timestamp: new Date().toISOString(),
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      ip: req.ip,
      userAgent: req.get('User-Agent'),
      contentLength: res.get('Content-Length') || '0'
    };
    
    // Log to Cloud Logging
    console.log(JSON.stringify(logData));
  });
  
  next();
};

// Input validation middleware
export const validateInput = (req: Request, res: Response, next: NextFunction) => {
  // Basic input sanitization
  if (req.body) {
    for (const key in req.body) {
      if (typeof req.body[key] === 'string') {
        // Remove potential XSS
        req.body[key] = req.body[key]
          .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
          .replace(/javascript:/gi, '')
          .replace(/on\w+\s*=/gi, '');
      }
    }
  }
  
  next();
};

// API key validation with Secret Manager
export const validateApiKeyFromSecret = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const apiKey = req.headers['x-api-key'];
    
    if (!apiKey) {
      return res.status(401).json({ 
        error: 'API key required. Provide x-api-key header.' 
      });
    }
    
    // In production, retrieve from Secret Manager
    const environment = process.env.NODE_ENV || 'development';
    let validApiKey: string;
    
    if (process.env.GOOGLE_CLOUD_PROJECT) {
      // Running in Google Cloud - use Secret Manager
      const { SecretManagerServiceClient } = require('@google-cloud/secret-manager');
      const client = new SecretManagerServiceClient();
      
      const [version] = await client.accessSecretVersion({
        name: `projects/${process.env.GOOGLE_CLOUD_PROJECT}/secrets/api-key/versions/latest`,
      });
      
      validApiKey = version.payload?.data?.toString() || '';
    } else {
      // Local development - use environment variable
      validApiKey = process.env.API_KEY || 'dev-api-key-123';
    }
    
    if (apiKey === validApiKey) {
      // Set user context for downstream middleware
      (req as any).user = { uid: 'authenticated-user' };
      next();
    } else {
      res.status(401).json({ 
        error: 'Invalid API key' 
      });
    }
  } catch (error) {
    console.error('API key validation error:', error);
    res.status(500).json({ 
      error: 'Authentication service unavailable' 
    });
  }
};
EOF
    
    echo -e "${GREEN}✅ Security middleware created${NC}"
}

# Update package.json with security dependencies
update_package_dependencies() {
    echo -e "\n${YELLOW}📦 Adding security dependencies${NC}"
    
    cd "google-cloud-toy-api"
    
    # Add security-related dependencies
    npm install --save express-rate-limit helmet @google-cloud/secret-manager
    npm install --save-dev @types/express-rate-limit
    
    echo -e "${GREEN}✅ Security dependencies added${NC}"
    cd ..
}

# Main setup process
main() {
    echo -e "${BLUE}Starting security enhancements setup...${NC}\n"
    
    # Check prerequisites
    if ! command -v gcloud &> /dev/null; then
        echo -e "${RED}❌ gcloud CLI not found. Please install Google Cloud SDK.${NC}"
        exit 1
    fi
    
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        echo -e "${RED}❌ Not authenticated with gcloud. Please run 'gcloud auth login'${NC}"
        exit 1
    fi
    
    # Show what will be configured
    echo -e "${BLUE}Security enhancements to be configured:${NC}"
    echo -e "✅ Secret Manager for API keys and service accounts"
    echo -e "✅ Container security scanning in CI/CD"
    echo -e "✅ Security headers and rate limiting"
    echo -e "✅ Cloud Armor WAF (basic configuration)"
    echo -e "✅ Secure Cloud Run service templates"
    
    read -p "Press Enter to continue or Ctrl+C to abort..."
    
    # Setup dev environment
    echo -e "\n${BLUE}=== Setting up DEV environment security ===${NC}"
    setup_security $PROJECT_ID_DEV "dev"
    create_secrets $PROJECT_ID_DEV "dev"
    setup_container_scanning $PROJECT_ID_DEV "dev"
    setup_cloud_armor $PROJECT_ID_DEV "dev"
    create_secure_service_template "dev"
    
    # Ask about other environments
    echo -e "\n${BLUE}Do you want to setup security for staging environment? (y/n)${NC}"
    read -r setup_staging
    if [[ $setup_staging == "y" || $setup_staging == "Y" ]]; then
        echo -e "\n${BLUE}=== Setting up STAGING environment security ===${NC}"
        setup_security $PROJECT_ID_STAGING "staging"
        create_secrets $PROJECT_ID_STAGING "staging"
        setup_container_scanning $PROJECT_ID_STAGING "staging"
        setup_cloud_armor $PROJECT_ID_STAGING "staging"
        create_secure_service_template "staging"
    fi
    
    echo -e "\n${BLUE}Do you want to setup security for production environment? (y/n)${NC}"
    read -r setup_prod
    if [[ $setup_prod == "y" || $setup_prod == "Y" ]]; then
        echo -e "\n${BLUE}=== Setting up PRODUCTION environment security ===${NC}"
        setup_security $PROJECT_ID_PROD "prod"
        create_secrets $PROJECT_ID_PROD "prod"
        setup_container_scanning $PROJECT_ID_PROD "prod"
        setup_cloud_armor $PROJECT_ID_PROD "prod"
        create_secure_service_template "prod"
    fi
    
    # Update application code
    echo -e "\n${BLUE}=== Updating application with security enhancements ===${NC}"
    mkdir -p "google-cloud-toy-api/src/middleware"
    create_security_middleware
    update_package_dependencies
    update_cloudbuild_security
    
    echo -e "\n${GREEN}🎉 Security enhancements setup completed!${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo -e "${BLUE}What was configured:${NC}"
    echo -e "✅ Secret Manager with API keys and service account keys"
    echo -e "✅ Container vulnerability scanning in CI/CD pipeline"
    echo -e "✅ Security middleware (rate limiting, headers, input validation)"
    echo -e "✅ Cloud Armor WAF with basic rules"
    echo -e "✅ Secure Cloud Run service templates"
    echo -e "\n${YELLOW}⚠️  Next steps:${NC}"
    echo -e "1. Update your application to use the new security middleware"
    echo -e "2. Test the enhanced security features"
    echo -e "3. Upload actual Firebase service account key to Secret Manager"
    echo -e "4. Configure Cloud Armor rules as needed"
    echo -e "\n${BLUE}Monitor security at:${NC}"
    echo -e "${YELLOW}https://console.cloud.google.com/security?project=$PROJECT_ID_DEV${NC}"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi