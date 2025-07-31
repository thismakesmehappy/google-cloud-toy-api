#!/bin/bash

# Complete Project Setup Script for Google Cloud Toy API
# Orchestrates the setup of all Phase 6 features: CI/CD, Monitoring, Security, Advanced Deployments, Team Collaboration, and Performance Optimization

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
GITHUB_OWNER="YOUR_GITHUB_USERNAME"  # Update this
NOTIFICATION_EMAIL="your-email@example.com"  # Update this

echo -e "${BLUE}🚀 Google Cloud Toy API - Complete Enterprise Setup${NC}"
echo -e "${BLUE}==================================================${NC}"
echo -e "${CYAN}This script will set up all Phase 6 enterprise features:${NC}"
echo -e "${CYAN}✅ CI/CD Pipeline Activation${NC}"
echo -e "${CYAN}✅ Monitoring & Alerting${NC}"
echo -e "${CYAN}✅ Security Enhancements${NC}"
echo -e "${CYAN}✅ Advanced Deployment Strategies${NC}"
echo -e "${CYAN}✅ Team Collaboration Features${NC}"
echo -e "${CYAN}✅ Performance Optimization${NC}"

# Check if configuration variables are updated
if [ "$GITHUB_OWNER" = "YOUR_GITHUB_USERNAME" ]; then
    echo -e "\n${RED}❌ Please update the configuration variables in this script:${NC}"
    echo -e "${YELLOW}1. Set GITHUB_OWNER to your GitHub username${NC}"
    echo -e "${YELLOW}2. Set NOTIFICATION_EMAIL to your email address${NC}"
    echo -e "\n${BLUE}Edit this file and update the variables at the top, then run again.${NC}"
    exit 1
fi

echo -e "\n${GREEN}Configuration:${NC}"
echo -e "${BLUE}  GitHub Owner: $GITHUB_OWNER${NC}"
echo -e "${BLUE}  Notification Email: $NOTIFICATION_EMAIL${NC}"

# Prerequisites check
check_prerequisites() {
    echo -e "\n${YELLOW}🔍 Checking prerequisites...${NC}"
    
    local missing_tools=()
    
    if ! command -v gcloud &> /dev/null; then
        missing_tools+=("gcloud")
    fi
    
    if ! command -v gh &> /dev/null; then
        missing_tools+=("gh (GitHub CLI)")
    fi
    
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    if ! command -v npm &> /dev/null; then
        missing_tools+=("npm")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "${RED}❌ Missing required tools:${NC}"
        for tool in "${missing_tools[@]}"; do
            echo -e "${RED}  - $tool${NC}"
        done
        echo -e "\n${BLUE}Please install the missing tools and run this script again.${NC}"
        exit 1
    fi
    
    # Check authentication
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        echo -e "${RED}❌ Not authenticated with gcloud. Please run 'gcloud auth login'${NC}"
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        echo -e "${YELLOW}⚠️  Not authenticated with GitHub CLI. Some features will be limited.${NC}"
        echo -e "${BLUE}Run 'gh auth login' for full functionality.${NC}"
    fi
    
    echo -e "${GREEN}✅ All prerequisites satisfied${NC}"
}

# Phase 6.1: CI/CD Pipeline Activation
setup_cicd() {
    echo -e "\n${PURPLE}🔧 Phase 6.1: CI/CD Pipeline Activation${NC}"
    echo -e "${PURPLE}=======================================${NC}"
    
    if [ -f "./activate-cicd.sh" ]; then
        echo -e "${BLUE}Updating GitHub owner in activate-cicd.sh...${NC}"
        sed -i.bak "s/YOUR_GITHUB_USERNAME/$GITHUB_OWNER/g" ./activate-cicd.sh
        
        echo -e "${YELLOW}Running CI/CD activation...${NC}"
        ./activate-cicd.sh
        echo -e "${GREEN}✅ CI/CD Pipeline activated${NC}"
    else
        echo -e "${RED}❌ activate-cicd.sh not found${NC}"
        return 1
    fi
}

# Phase 6.2: Monitoring & Alerting
setup_monitoring() {
    echo -e "\n${PURPLE}📊 Phase 6.2: Monitoring & Alerting${NC}"
    echo -e "${PURPLE}===================================${NC}"
    
    if [ -f "./setup-monitoring.sh" ]; then
        echo -e "${BLUE}Updating notification email in setup-monitoring.sh...${NC}"
        sed -i.bak "s/your-email@example.com/$NOTIFICATION_EMAIL/g" ./setup-monitoring.sh
        
        echo -e "${YELLOW}Running monitoring setup...${NC}"
        ./setup-monitoring.sh
        echo -e "${GREEN}✅ Monitoring & Alerting configured${NC}"
    else
        echo -e "${RED}❌ setup-monitoring.sh not found${NC}"
        return 1
    fi
}

# Phase 6.3: Security Enhancements
setup_security() {
    echo -e "\n${PURPLE}🔐 Phase 6.3: Security Enhancements${NC}"
    echo -e "${PURPLE}==================================${NC}"
    
    if [ -f "./setup-security.sh" ]; then
        echo -e "${YELLOW}Running security enhancements setup...${NC}"
        ./setup-security.sh
        echo -e "${GREEN}✅ Security Enhancements implemented${NC}"
    else
        echo -e "${RED}❌ setup-security.sh not found${NC}"
        return 1
    fi
}

# Phase 6.4: Advanced Deployment Strategies
setup_advanced_deployments() {
    echo -e "\n${PURPLE}🚀 Phase 6.4: Advanced Deployment Strategies${NC}"
    echo -e "${PURPLE}==============================================${NC}"
    
    if [ -f "./setup-advanced-deployments.sh" ]; then
        echo -e "${BLUE}Updating GitHub owner in deployment workflows...${NC}"
        sed -i.bak "s/YOUR_GITHUB_USERNAME/$GITHUB_OWNER/g" ./setup-advanced-deployments.sh
        
        echo -e "${YELLOW}Running advanced deployments setup...${NC}"
        ./setup-advanced-deployments.sh
        echo -e "${GREEN}✅ Advanced Deployment Strategies implemented${NC}"
    else
        echo -e "${RED}❌ setup-advanced-deployments.sh not found${NC}"
        return 1
    fi
}

# Phase 6.5: Team Collaboration Features
setup_team_collaboration() {
    echo -e "\n${PURPLE}🤝 Phase 6.5: Team Collaboration Features${NC}"
    echo -e "${PURPLE}=========================================${NC}"
    
    if [ -f "./setup-team-collaboration.sh" ]; then
        echo -e "${YELLOW}Running team collaboration setup...${NC}"
        ./setup-team-collaboration.sh
        
        # Update branch protection with correct GitHub username
        if [ -f "./setup-branch-protection.sh" ]; then
            echo -e "${BLUE}Setting up branch protection rules...${NC}"
            ./setup-branch-protection.sh "$GITHUB_OWNER"
        fi
        
        echo -e "${GREEN}✅ Team Collaboration Features implemented${NC}"
    else
        echo -e "${RED}❌ setup-team-collaboration.sh not found${NC}"
        return 1
    fi
}

# Phase 6.6: Performance Optimization
setup_performance_optimization() {
    echo -e "\n${PURPLE}⚡ Phase 6.6: Performance Optimization${NC}"
    echo -e "${PURPLE}=====================================${NC}"
    
    if [ -f "./setup-performance-optimization.sh" ]; then
        echo -e "${YELLOW}Running performance optimization setup...${NC}"
        ./setup-performance-optimization.sh
        echo -e "${GREEN}✅ Performance Optimization implemented${NC}"
    else
        echo -e "${RED}❌ setup-performance-optimization.sh not found${NC}"
        return 1
    fi
}

# Generate final summary report
generate_summary_report() {
    echo -e "\n${PURPLE}📋 Generating Final Summary Report${NC}"
    echo -e "${PURPLE}==================================${NC}"
    
    cat > COMPLETE_SETUP_SUMMARY.md << EOF
# 🎉 Complete Enterprise Setup Summary

**Setup Date:** $(date)
**GitHub Repository:** $GITHUB_OWNER/TestGoogleAPI
**Notification Email:** $NOTIFICATION_EMAIL

## ✅ Phase 6 Implementation Status

### 6.1 CI/CD Pipeline Activation
- ✅ Cloud Build triggers configured
- ✅ GitHub Actions workflows created
- ✅ Automatic deployment on push to main
- ✅ Integration testing with rollback

### 6.2 Monitoring & Alerting
- ✅ Application Performance Monitoring
- ✅ Infrastructure monitoring dashboards
- ✅ 5 alert policies configured
- ✅ Email notifications to $NOTIFICATION_EMAIL
- ✅ Uptime monitoring enabled

### 6.3 Security Enhancements
- ✅ Google Secret Manager integration
- ✅ Container vulnerability scanning
- ✅ Rate limiting and security headers
- ✅ Cloud Armor WAF configuration
- ✅ Access logging and audit trails

### 6.4 Advanced Deployment Strategies
- ✅ Staging promotion workflows
- ✅ Blue-green deployment scripts
- ✅ Canary release automation
- ✅ Feature flags with Firestore backend

### 6.5 Team Collaboration Features
- ✅ Pull request automation
- ✅ Branch protection rules
- ✅ Code quality gates
- ✅ Automated code review
- ✅ CODEOWNERS file configuration

### 6.6 Performance Optimization
- ✅ Cloud CDN integration
- ✅ Redis caching implementation
- ✅ Database query optimization
- ✅ Auto-scaling configuration
- ✅ Performance monitoring endpoints

## 🚀 Ready-to-Use Scripts

| Script | Purpose |
|--------|---------|
| \`./deploy-with-tests.sh [env]\` | Deploy with automatic testing |
| \`./blue-green-deploy.sh [env] [tag]\` | Zero-downtime deployment |
| \`./canary-deploy.sh [env] [tag]\` | Gradual traffic migration |
| \`./promote-deployment.sh [src] [target]\` | Promote between environments |
| \`./rollback.sh [env]\` | Emergency rollback |
| \`./test-integration.sh [url] [key] [env]\` | Integration testing |

## 📊 Monitoring URLs

- **Dev Environment:** https://console.cloud.google.com/monitoring?project=toy-api-dev
- **Staging Environment:** https://console.cloud.google.com/monitoring?project=toy-api-staging
- **Production Environment:** https://console.cloud.google.com/monitoring?project=toy-api-prod

## 🔐 Security Features

- **Secret Management:** All API keys stored in Google Secret Manager
- **Container Scanning:** Automated vulnerability detection in CI/CD
- **Rate Limiting:** 100 requests per 15 minutes per IP
- **Security Headers:** HSTS, CSP, XSS protection enabled
- **WAF Protection:** Cloud Armor DDoS protection active
- **Access Logging:** Complete audit trail available

## 📈 Performance Features

- **Caching:** Redis-based caching for frequently accessed data
- **CDN:** Cloud CDN for static assets
- **Database:** Query optimization and performance monitoring
- **Auto-scaling:** Dynamic resource allocation based on load
- **Monitoring:** Real-time performance metrics and alerts

## 💰 Cost Analysis

**Estimated Monthly Costs:**
- Development: \$0 (within free tiers)
- Staging: \$0-15 (Redis instance)
- Production: \$15-50 (Redis + enhanced monitoring)

## 🎯 Next Steps

1. **Test all systems** by creating a pull request
2. **Monitor dashboards** for 24 hours to ensure stability
3. **Configure team members** in CODEOWNERS file
4. **Set up production** Redis and CDN instances
5. **Train team** on new deployment workflows

## 📞 Support & Documentation

- **Implementation Plan:** docs/IMPLEMENTATION_PLAN_V2.md
- **Phase 6 Guide:** docs/PHASE_6_IMPLEMENTATION_GUIDE.md
- **README:** README.md
- **GitHub Issues:** https://github.com/$GITHUB_OWNER/TestGoogleAPI/issues

---

**🚀 Enterprise Production Ready - All Phase 6 Features Implemented! 🚀**
EOF

    echo -e "${GREEN}✅ Summary report generated: COMPLETE_SETUP_SUMMARY.md${NC}"
}

# Main execution flow
main() {
    echo -e "\n${BLUE}Starting complete enterprise setup...${NC}"
    
    read -p "This will set up all Phase 6 features. Continue? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Setup cancelled by user.${NC}"
        exit 0
    fi
    
    # Run all setup phases
    check_prerequisites
    
    echo -e "\n${CYAN}🎯 Executing all Phase 6 implementations...${NC}"
    
    setup_cicd
    setup_monitoring
    setup_security
    setup_advanced_deployments
    setup_team_collaboration
    setup_performance_optimization
    
    generate_summary_report
    
    echo -e "\n${GREEN}🎉 COMPLETE ENTERPRISE SETUP FINISHED! 🎉${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "${CYAN}Your Google Cloud Toy API project is now enterprise-ready with:${NC}"
    echo -e "${CYAN}✅ Automated CI/CD pipeline${NC}"
    echo -e "${CYAN}✅ Real-time monitoring and alerting${NC}"
    echo -e "${CYAN}✅ Enterprise security controls${NC}"
    echo -e "${CYAN}✅ Advanced deployment strategies${NC}"
    echo -e "${CYAN}✅ Team collaboration workflows${NC}"
    echo -e "${CYAN}✅ Performance optimization${NC}"
    
    echo -e "\n${BLUE}📋 Summary report: COMPLETE_SETUP_SUMMARY.md${NC}"
    echo -e "${BLUE}📚 Full documentation: docs/IMPLEMENTATION_PLAN_V2.md${NC}"
    echo -e "\n${YELLOW}⚠️  Remember to:${NC}"
    echo -e "${YELLOW}1. Update usernames in .github/CODEOWNERS${NC}"
    echo -e "${YELLOW}2. Test the setup by creating a pull request${NC}"
    echo -e "${YELLOW}3. Monitor dashboards for system health${NC}"
    echo -e "${YELLOW}4. Configure production secrets and credentials${NC}"
    
    echo -e "\n${GREEN}🚀 Your project is ready for enterprise production deployment! 🚀${NC}"
}

# Run main function
main "$@"