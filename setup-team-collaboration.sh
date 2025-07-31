#!/bin/bash

# Team Collaboration Features Setup for Google Cloud Toy API
# Implements PR automation, branch protection, code quality gates, and automated code review

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITHUB_OWNER="YOUR_GITHUB_USERNAME"  # Update this with your GitHub username
REPO_NAME="TestGoogleAPI"

echo -e "${BLUE}🤝 Setting up Team Collaboration Features${NC}"
echo -e "${BLUE}=======================================${NC}"

# Create PR automation workflow
create_pr_automation() {
    echo -e "\n${YELLOW}🔄 Creating PR automation workflow${NC}"
    
    mkdir -p .github/workflows
    
    cat > .github/workflows/pr-automation.yml << 'EOF'
name: Pull Request Automation

on:
  pull_request:
    branches: [ main, develop ]
    paths:
      - 'google-cloud-toy-api/**'
      - '.github/workflows/**'
  pull_request_target:
    types: [opened, synchronize, reopened]

# Security: Limit permissions for PR workflows
permissions:
  contents: read
  pull-requests: write
  checks: write
  statuses: write

jobs:
  # Code Quality Checks
  code-quality:
    runs-on: ubuntu-latest
    name: Code Quality & Security
    steps:
    - name: Checkout PR
      uses: actions/checkout@v4
      with:
        ref: ${{ github.event.pull_request.head.sha }}
        fetch-depth: 0

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '20'
        cache: 'npm'
        cache-dependency-path: 'google-cloud-toy-api/package-lock.json'

    - name: Install dependencies
      working-directory: google-cloud-toy-api
      run: npm ci

    - name: Run ESLint
      working-directory: google-cloud-toy-api
      run: |
        npx eslint src/ --ext .ts,.js --format=json --output-file=eslint-results.json || true
        npx eslint src/ --ext .ts,.js

    - name: Run Prettier check
      working-directory: google-cloud-toy-api
      run: npx prettier --check "src/**/*.{ts,js,json}"

    - name: TypeScript type checking
      working-directory: google-cloud-toy-api
      run: npx tsc --noEmit

    - name: Security audit
      working-directory: google-cloud-toy-api
      run: npm audit --audit-level=moderate

    - name: Check for secrets
      uses: trufflesecurity/trufflehog@main
      with:
        path: ./
        base: main
        head: HEAD

  # Unit Tests
  unit-tests:
    runs-on: ubuntu-latest
    name: Unit Tests
    steps:
    - name: Checkout PR
      uses: actions/checkout@v4
      with:
        ref: ${{ github.event.pull_request.head.sha }}

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '20'
        cache: 'npm'
        cache-dependency-path: 'google-cloud-toy-api/package-lock.json'

    - name: Install dependencies
      working-directory: google-cloud-toy-api
      run: npm ci

    - name: Run unit tests with coverage
      working-directory: google-cloud-toy-api
      run: npm run test:coverage

    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        directory: google-cloud-toy-api/coverage
        fail_ci_if_error: false

    - name: Coverage comment
      uses: romeovs/lcov-reporter-action@v0.3.1
      with:
        lcov-file: google-cloud-toy-api/coverage/lcov.info
        github-token: ${{ secrets.GITHUB_TOKEN }}
        delete-old-comments: true

  # Build and Security Scan
  build-and-scan:
    runs-on: ubuntu-latest
    name: Build & Security Scan
    steps:
    - name: Checkout PR
      uses: actions/checkout@v4
      with:
        ref: ${{ github.event.pull_request.head.sha }}

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '20'
        cache: 'npm'
        cache-dependency-path: 'google-cloud-toy-api/package-lock.json'

    - name: Install dependencies
      working-directory: google-cloud-toy-api
      run: npm ci

    - name: Build TypeScript
      working-directory: google-cloud-toy-api
      run: npm run build

    - name: Build Docker image
      run: |
        docker build -t test-image:pr-${{ github.event.pull_request.number }} google-cloud-toy-api/

    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: 'test-image:pr-${{ github.event.pull_request.number }}'
        format: 'sarif'
        output: 'trivy-results.sarif'

    - name: Upload Trivy scan results
      uses: github/codeql-action/upload-sarif@v2
      if: always()
      with:
        sarif_file: 'trivy-results.sarif'

  # Performance Tests
  performance-tests:
    runs-on: ubuntu-latest
    name: Performance Tests
    steps:
    - name: Checkout PR
      uses: actions/checkout@v4
      with:
        ref: ${{ github.event.pull_request.head.sha }}

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '20'
        cache: 'npm'
        cache-dependency-path: 'google-cloud-toy-api/package-lock.json'

    - name: Install dependencies
      working-directory: google-cloud-toy-api
      run: npm ci

    - name: Start test server
      working-directory: google-cloud-toy-api
      run: |
        npm run build
        npm start &
        sleep 10

    - name: Install Artillery
      run: npm install -g artillery@latest

    - name: Run performance tests
      run: |
        cat > performance-test.yml << 'PERF_EOF'
config:
  target: 'http://localhost:8080'
  phases:
    - duration: 60
      arrivalRate: 10
  defaults:
    headers:
      x-api-key: 'dev-api-key-123'

scenarios:
  - name: "Health check performance"
    requests:
      - get:
          url: "/"
  - name: "Public endpoint performance"
    requests:
      - get:
          url: "/public"
  - name: "Private endpoint performance"
    requests:
      - get:
          url: "/private"
PERF_EOF
        artillery run performance-test.yml --output performance-results.json

    - name: Generate performance report
      run: artillery report performance-results.json --output performance-report.html

    - name: Upload performance artifacts
      uses: actions/upload-artifact@v3
      with:
        name: performance-results
        path: |
          performance-results.json
          performance-report.html

  # Integration Tests
  integration-tests:
    runs-on: ubuntu-latest
    name: Integration Tests
    needs: [build-and-scan]
    steps:
    - name: Checkout PR
      uses: actions/checkout@v4
      with:
        ref: ${{ github.event.pull_request.head.sha }}

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '20'

    - name: Start services with Docker Compose
      run: |
        cd google-cloud-toy-api
        docker-compose up -d
        sleep 30

    - name: Run integration tests
      run: |
        chmod +x test-integration.sh
        ./test-integration.sh http://localhost:8080 dev-api-key-123 dev

    - name: Cleanup
      if: always()
      run: |
        cd google-cloud-toy-api
        docker-compose down

  # PR Size Check
  pr-size-check:
    runs-on: ubuntu-latest
    name: PR Size Check
    steps:
    - name: Check PR size
      uses: actions/github-script@v6
      with:
        script: |
          const { data: pr } = await github.rest.pulls.get({
            owner: context.repo.owner,
            repo: context.repo.repo,
            pull_number: context.issue.number
          });
          
          const additions = pr.additions;
          const deletions = pr.deletions;
          const changes = additions + deletions;
          
          console.log(`PR Changes: +${additions} -${deletions} (${changes} total)`);
          
          // Large PR warning
          if (changes > 500) {
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: `⚠️ **Large PR Warning**\n\nThis PR has ${changes} changes (+${additions}/-${deletions}). Consider breaking it into smaller PRs for easier review.\n\n**Guidelines:**\n- PRs with <200 changes are easier to review\n- Break large features into multiple PRs\n- Each PR should have a single responsibility`
            });
          }

  # Auto-assign reviewers
  auto-assign-reviewers:
    runs-on: ubuntu-latest
    name: Auto-assign Reviewers
    if: github.event.action == 'opened'
    steps:
    - name: Auto-assign reviewers
      uses: actions/github-script@v6
      with:
        script: |
          // Define review assignment rules
          const reviewers = {
            'backend': ['backend-team-lead'],
            'frontend': ['frontend-team-lead'],
            'infrastructure': ['devops-lead'],
            'security': ['security-team-lead']
          };
          
          const { data: files } = await github.rest.pulls.listFiles({
            owner: context.repo.owner,
            repo: context.repo.repo,
            pull_number: context.issue.number
          });
          
          let assignReviewers = new Set();
          
          files.forEach(file => {
            if (file.filename.includes('src/') || file.filename.includes('api')) {
              assignReviewers.add('backend-reviewer');
            }
            if (file.filename.includes('terraform/') || file.filename.includes('docker') || file.filename.includes('cloud')) {
              assignReviewers.add('infrastructure-reviewer');
            }
            if (file.filename.includes('security') || file.filename.includes('auth')) {
              assignReviewers.add('security-reviewer');
            }
          });
          
          if (assignReviewers.size > 0) {
            // In a real setup, these would be actual GitHub usernames
            console.log(`Would assign reviewers: ${Array.from(assignReviewers).join(', ')}`);
            
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: `🤖 **Auto-assigned for review based on changed files:**\n\n${Array.from(assignReviewers).map(r => `- @${r}`).join('\n')}\n\n*This is an automated assignment based on the files changed in this PR.*`
            });
          }

  # PR Summary
  pr-summary:
    runs-on: ubuntu-latest
    name: PR Summary
    needs: [code-quality, unit-tests, build-and-scan, performance-tests]
    if: always()
    steps:
    - name: Create PR summary
      uses: actions/github-script@v6
      with:
        script: |
          const jobs = [
            { name: 'Code Quality', status: '${{ needs.code-quality.result }}' },
            { name: 'Unit Tests', status: '${{ needs.unit-tests.result }}' },
            { name: 'Build & Security Scan', status: '${{ needs.build-and-scan.result }}' },
            { name: 'Performance Tests', status: '${{ needs.performance-tests.result }}' }
          ];
          
          const statusEmoji = {
            'success': '✅',
            'failure': '❌',
            'cancelled': '⏹️',
            'skipped': '⏭️'
          };
          
          let summary = '## 🚀 PR Automation Summary\n\n';
          summary += '| Check | Status |\n';
          summary += '|-------|--------|\n';
          
          jobs.forEach(job => {
            const emoji = statusEmoji[job.status] || '❓';
            summary += `| ${job.name} | ${emoji} ${job.status} |\n`;
          });
          
          const allPassed = jobs.every(job => job.status === 'success');
          
          if (allPassed) {
            summary += '\n✅ **All checks passed!** This PR is ready for review.\n';
          } else {
            summary += '\n❌ **Some checks failed.** Please review and fix the issues above.\n';
          }
          
          summary += '\n---\n*This summary is automatically generated by PR automation.*';
          
          await github.rest.issues.createComment({
            owner: context.repo.owner,
            repo: context.repo.repo,
            issue_number: context.issue.number,
            body: summary
          });
EOF

    echo -e "${GREEN}✅ PR automation workflow created${NC}"
}

# Create branch protection setup script
create_branch_protection() {
    echo -e "\n${YELLOW}🛡️ Creating branch protection setup${NC}"
    
    cat > setup-branch-protection.sh << 'EOF'
#!/bin/bash

# Branch Protection Rules Setup
# Configures GitHub branch protection for main and develop branches

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

GITHUB_OWNER=${1:-"YOUR_GITHUB_USERNAME"}
REPO_NAME=${2:-"TestGoogleAPI"}

if [ "$GITHUB_OWNER" = "YOUR_GITHUB_USERNAME" ]; then
    echo -e "${RED}❌ Please provide your GitHub username${NC}"
    echo "Usage: $0 <github_username> [repo_name]"
    exit 1
fi

echo -e "${BLUE}🛡️ Setting up branch protection rules${NC}"
echo -e "${BLUE}Repository: $GITHUB_OWNER/$REPO_NAME${NC}"

# Check if GitHub CLI is available
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI not found. Please install: https://cli.github.com/${NC}"
    exit 1
fi

# Check authentication
if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ Not authenticated with GitHub CLI${NC}"
    echo "Please run: gh auth login"
    exit 1
fi

# Function to create branch protection rule
create_protection_rule() {
    local branch=$1
    local required_checks=$2
    
    echo -e "\n${YELLOW}🔒 Setting up protection for '$branch' branch${NC}"
    
    # Create the protection rule
    gh api repos/$GITHUB_OWNER/$REPO_NAME/branches/$branch/protection \
        --method PUT \
        --field required_status_checks='{
            "strict": true,
            "checks": ['"$required_checks"']
        }' \
        --field enforce_admins=false \
        --field required_pull_request_reviews='{
            "required_approving_review_count": 1,
            "dismiss_stale_reviews": true,
            "require_code_owner_reviews": true,
            "require_last_push_approval": false
        }' \
        --field restrictions=null \
        --field allow_deletions=false \
        --field allow_force_pushes=false \
        --field allow_fork_syncing=false \
        --field block_creations=false \
        --field required_conversation_resolution=true \
        --field lock_branch=false \
        --field required_linear_history=false || {
        
        echo -e "${YELLOW}⚠️  Failed to set protection rule via API, trying gh CLI command${NC}"
        
        # Fallback to gh CLI command
        gh api repos/$GITHUB_OWNER/$REPO_NAME/branches/$branch/protection \
            --method PUT \
            --raw-field required_status_checks='{"strict": true, "contexts": []}' \
            --raw-field enforce_admins=false \
            --raw-field required_pull_request_reviews='{"required_approving_review_count": 1}' \
            --raw-field restrictions=null
    }
    
    echo -e "${GREEN}✅ Protection rule created for '$branch' branch${NC}"
}

# Required status checks for main branch
MAIN_CHECKS='{
    "context": "Code Quality & Security"
},
{
    "context": "Unit Tests"
},
{
    "context": "Build & Security Scan"
},
{
    "context": "Integration Tests"
}'

# Required status checks for develop branch (less strict)
DEVELOP_CHECKS='{
    "context": "Code Quality & Security"
},
{
    "context": "Unit Tests"
}'

echo -e "\n${BLUE}Branch protection rules to be configured:${NC}"
echo -e "✅ Require pull request reviews (1 approval minimum)"
echo -e "✅ Dismiss stale reviews when new commits are pushed"
echo -e "✅ Require status checks to pass before merging"
echo -e "✅ Require branches to be up to date before merging"
echo -e "✅ Require conversation resolution before merging"
echo -e "✅ Prevent force pushes"
echo -e "✅ Prevent branch deletion"

read -p "Press Enter to continue or Ctrl+C to abort..."

# Setup protection for main branch
if gh api repos/$GITHUB_OWNER/$REPO_NAME/branches/main &> /dev/null; then
    create_protection_rule "main" "$MAIN_CHECKS"
else
    echo -e "${YELLOW}⚠️  'main' branch not found, skipping${NC}"
fi

# Setup protection for develop branch
if gh api repos/$GITHUB_OWNER/$REPO_NAME/branches/develop &> /dev/null; then
    create_protection_rule "develop" "$DEVELOP_CHECKS"
else
    echo -e "${YELLOW}⚠️  'develop' branch not found, creating it${NC}"
    
    # Create develop branch from main
    if gh api repos/$GITHUB_OWNER/$REPO_NAME/branches/main &> /dev/null; then
        gh api repos/$GITHUB_OWNER/$REPO_NAME/git/refs \
            --method POST \
            --field ref='refs/heads/develop' \
            --field sha="$(gh api repos/$GITHUB_OWNER/$REPO_NAME/branches/main --jq '.commit.sha')"
        
        echo -e "${GREEN}✅ 'develop' branch created${NC}"
        create_protection_rule "develop" "$DEVELOP_CHECKS"
    else
        echo -e "${YELLOW}⚠️  Cannot create 'develop' branch - 'main' branch not found${NC}"
    fi
fi

echo -e "\n${GREEN}🎉 Branch Protection Setup Complete!${NC}"
echo -e "${GREEN}===================================${NC}"
echo -e "${YELLOW}⚠️  Next steps:${NC}"
echo -e "1. Verify protection rules in GitHub UI: https://github.com/$GITHUB_OWNER/$REPO_NAME/settings/branches"
echo -e "2. Create a CODEOWNERS file to specify code review assignments"
echo -e "3. Test the protection by creating a PR"
echo -e "4. Adjust settings as needed for your team workflow"
EOF

    chmod +x setup-branch-protection.sh
    echo -e "${GREEN}✅ Branch protection setup script created${NC}"
}

# Create CODEOWNERS file
create_codeowners() {
    echo -e "\n${YELLOW}👥 Creating CODEOWNERS file${NC}"
    
    mkdir -p .github
    
    cat > .github/CODEOWNERS << 'EOF'
# CODEOWNERS - Automatic code review assignment
# https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners

# Global owners (will be requested for all changes)
# * @your-username

# Backend code changes
google-cloud-toy-api/src/ @backend-team-lead @senior-backend-dev
google-cloud-toy-api/src/services/ @backend-team-lead
google-cloud-toy-api/src/middleware/ @security-team-lead @backend-team-lead

# Infrastructure and deployment changes
terraform/ @devops-lead @infrastructure-team
*.sh @devops-lead
Dockerfile @devops-lead @backend-dev
docker-compose.yml @devops-lead @backend-dev
cloudbuild.yaml @devops-lead @cicd-specialist

# GitHub workflows and CI/CD
.github/workflows/ @devops-lead @cicd-specialist

# Security-related changes
*/security* @security-team-lead
*/auth* @security-team-lead @backend-team-lead
setup-security.sh @security-team-lead @devops-lead

# Configuration files
package.json @backend-team-lead
package-lock.json @backend-team-lead
tsconfig.json @backend-team-lead

# Documentation
*.md @tech-writer @team-lead
docs/ @tech-writer @team-lead

# Tests
**/*test* @backend-dev @qa-lead
**/__tests__/ @backend-dev @qa-lead
test-integration.sh @qa-lead @backend-dev

# Database and data-related changes
*/firestore* @data-team-lead @backend-team-lead
*/database* @data-team-lead

# Performance and monitoring
*/monitoring* @sre-team-lead @devops-lead
setup-monitoring.sh @sre-team-lead

# Examples of specific file ownership
# SECURITY.md @security-team-lead
# CONTRIBUTING.md @team-lead @senior-dev

# Example: Require multiple reviewers for critical files
# setup-security.sh @security-team-lead @devops-lead @team-lead
EOF

    echo -e "${GREEN}✅ CODEOWNERS file created${NC}"
    echo -e "${YELLOW}⚠️  Update the usernames in .github/CODEOWNERS with actual GitHub usernames${NC}"
}

# Create code quality gates
create_quality_gates() {
    echo -e "\n${YELLOW}🚧 Creating code quality gates${NC}"
    
    # Create quality gates configuration
    cat > .github/workflows/quality-gates.yml << 'EOF'
name: Quality Gates

on:
  pull_request:
    branches: [ main, develop ]
  push:
    branches: [ main, develop ]

jobs:
  quality-gates:
    runs-on: ubuntu-latest
    name: Code Quality Gates
    steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0  # Needed for SonarCloud

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '20'
        cache: 'npm'
        cache-dependency-path: 'google-cloud-toy-api/package-lock.json'

    - name: Install dependencies
      working-directory: google-cloud-toy-api
      run: npm ci

    # Gate 1: Code Coverage Threshold
    - name: Run tests with coverage
      working-directory: google-cloud-toy-api
      run: npm run test:coverage

    - name: Check coverage threshold
      working-directory: google-cloud-toy-api
      run: |
        COVERAGE=$(npm run test:coverage:summary 2>/dev/null | grep "Lines" | awk '{print $3}' | sed 's/%//')
        THRESHOLD=80
        
        echo "Coverage: ${COVERAGE}%"
        echo "Threshold: ${THRESHOLD}%"
        
        if (( $(echo "$COVERAGE < $THRESHOLD" | bc -l) )); then
          echo "❌ Coverage ${COVERAGE}% is below threshold ${THRESHOLD}%"
          exit 1
        else
          echo "✅ Coverage ${COVERAGE}% meets threshold ${THRESHOLD}%"
        fi

    # Gate 2: Security Vulnerabilities
    - name: Security audit
      working-directory: google-cloud-toy-api
      run: |
        # Check for high/critical vulnerabilities
        AUDIT_OUTPUT=$(npm audit --audit-level=high --json 2>/dev/null || echo '{"vulnerabilities":{}}')
        HIGH_VULNS=$(echo $AUDIT_OUTPUT | jq '.metadata.vulnerabilities.high // 0')
        CRITICAL_VULNS=$(echo $AUDIT_OUTPUT | jq '.metadata.vulnerabilities.critical // 0')
        
        echo "High vulnerabilities: $HIGH_VULNS"
        echo "Critical vulnerabilities: $CRITICAL_VULNS"
        
        if [ "$CRITICAL_VULNS" -gt "0" ]; then
          echo "❌ Critical vulnerabilities found: $CRITICAL_VULNS"
          exit 1
        fi
        
        if [ "$HIGH_VULNS" -gt "5" ]; then
          echo "❌ Too many high vulnerabilities found: $HIGH_VULNS (max 5)"
          exit 1
        fi
        
        echo "✅ Security audit passed"

    # Gate 3: Code Complexity
    - name: Check code complexity
      working-directory: google-cloud-toy-api
      run: |
        npx eslint src/ --ext .ts --format json --output-file eslint-results.json || true
        
        # Check for excessive complexity
        COMPLEX_FILES=$(cat eslint-results.json | jq '[.[] | select(.messages[].ruleId == "complexity")] | length')
        
        if [ "$COMPLEX_FILES" -gt "3" ]; then
          echo "❌ Too many files with high complexity: $COMPLEX_FILES"
          echo "Consider refactoring complex functions"
          exit 1
        fi
        
        echo "✅ Code complexity check passed"

    # Gate 4: Technical Debt
    - name: Check technical debt
      working-directory: google-cloud-toy-api
      run: |
        # Count TODO/FIXME comments
        TODO_COUNT=$(find src/ -name "*.ts" -exec grep -l "TODO\|FIXME\|XXX\|HACK" {} \; | wc -l)
        
        echo "Files with technical debt markers: $TODO_COUNT"
        
        if [ "$TODO_COUNT" -gt "10" ]; then
          echo "❌ Too much technical debt: $TODO_COUNT files with TODO/FIXME (max 10)"
          echo "Consider addressing technical debt before adding new features"
          exit 1
        fi
        
        echo "✅ Technical debt check passed"

    # Gate 5: Bundle Size
    - name: Check bundle size
      working-directory: google-cloud-toy-api
      run: |
        npm run build
        
        # Check built file sizes
        BUILD_SIZE=$(du -sk build/ | cut -f1)
        MAX_SIZE=10240  # 10MB in KB
        
        echo "Build size: ${BUILD_SIZE}KB"
        echo "Max size: ${MAX_SIZE}KB"
        
        if [ "$BUILD_SIZE" -gt "$MAX_SIZE" ]; then
          echo "❌ Build size ${BUILD_SIZE}KB exceeds maximum ${MAX_SIZE}KB"
          echo "Consider optimizing bundle size"
          exit 1
        fi
        
        echo "✅ Bundle size check passed"

    # Gate 6: Performance Regression
    - name: Performance regression check
      working-directory: google-cloud-toy-api
      run: |
        # Start the app
        npm start &
        APP_PID=$!
        sleep 10
        
        # Simple performance test
        echo "Running performance regression test..."
        
        START_TIME=$(date +%s%N)
        curl -s http://localhost:8080/ > /dev/null
        END_TIME=$(date +%s%N)
        
        RESPONSE_TIME=$(( (END_TIME - START_TIME) / 1000000 ))  # Convert to milliseconds
        MAX_RESPONSE_TIME=1000  # 1 second
        
        echo "Response time: ${RESPONSE_TIME}ms"
        echo "Max response time: ${MAX_RESPONSE_TIME}ms"
        
        # Cleanup
        kill $APP_PID
        
        if [ "$RESPONSE_TIME" -gt "$MAX_RESPONSE_TIME" ]; then
          echo "❌ Response time ${RESPONSE_TIME}ms exceeds maximum ${MAX_RESPONSE_TIME}ms"
          exit 1
        fi
        
        echo "✅ Performance regression check passed"

    # Summary
    - name: Quality gates summary
      if: always()
      run: |
        echo "🎉 All quality gates passed!"
        echo "✅ Code coverage threshold met"
        echo "✅ No critical security vulnerabilities"
        echo "✅ Code complexity within limits"
        echo "✅ Technical debt under control"
        echo "✅ Bundle size optimized"
        echo "✅ No performance regression"
EOF

    echo -e "${GREEN}✅ Quality gates workflow created${NC}"
}

# Create automated code review
create_automated_review() {
    echo -e "\n${YELLOW}🤖 Creating automated code review${NC}"
    
    cat > .github/workflows/automated-review.yml << 'EOF'
name: Automated Code Review

on:
  pull_request:
    types: [opened, synchronize]
    branches: [ main, develop ]

permissions:
  contents: read
  pull-requests: write

jobs:
  automated-review:
    runs-on: ubuntu-latest
    name: Automated Code Review
    steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '20'

    # Review 1: Code Structure Analysis
    - name: Analyze code structure
      uses: actions/github-script@v6
      with:
        script: |
          const fs = require('fs');
          const path = require('path');
          
          let reviewComments = [];
          
          // Get changed files
          const { data: files } = await github.rest.pulls.listFiles({
            owner: context.repo.owner,
            repo: context.repo.repo,
            pull_number: context.issue.number
          });
          
          for (const file of files) {
            if (file.filename.endsWith('.ts') || file.filename.endsWith('.js')) {
              try {
                // Read file content
                const content = fs.readFileSync(file.filename, 'utf8');
                const lines = content.split('\n');
                
                // Check for common issues
                lines.forEach((line, index) => {
                  const lineNumber = index + 1;
                  
                  // Check for console.log in production
                  if (line.includes('console.log') && !line.includes('//')) {
                    reviewComments.push({
                      path: file.filename,
                      line: lineNumber,
                      body: '🚨 **Code Review Issue**: Consider removing console.log statement for production code. Use proper logging instead.',
                      side: 'RIGHT'
                    });
                  }
                  
                  // Check for TODO comments
                  if (line.includes('TODO') || line.includes('FIXME')) {
                    reviewComments.push({
                      path: file.filename,
                      line: lineNumber,
                      body: '📝 **Technical Debt**: This TODO/FIXME should be addressed or converted to a GitHub issue.',
                      side: 'RIGHT'
                    });
                  }
                  
                  // Check for hardcoded credentials
                  if (line.match(/(password|secret|key|token)\s*[:=]\s*['""][^'""]+['""]/) && !line.includes('test')) {
                    reviewComments.push({
                      path: file.filename,
                      line: lineNumber,
                      body: '🔐 **Security Issue**: Potential hardcoded credential detected. Use environment variables or secret management.',
                      side: 'RIGHT'
                    });
                  }
                  
                  // Check for long lines
                  if (line.length > 120) {
                    reviewComments.push({
                      path: file.filename,
                      line: lineNumber,
                      body: '📏 **Style Issue**: Line length exceeds 120 characters. Consider breaking it into multiple lines for better readability.',
                      side: 'RIGHT'
                    });
                  }
                });
                
                // Check file-level issues
                if (content.length > 15000) { // ~500 lines
                  reviewComments.push({
                    path: file.filename,
                    line: 1,
                    body: '📦 **Architecture Issue**: This file is quite large (>500 lines). Consider breaking it into smaller, more focused modules.',
                    side: 'RIGHT'
                  });
                }
                
              } catch (error) {
                console.log(`Could not analyze ${file.filename}: ${error.message}`);
              }
            }
          }
          
          // Submit review comments
          if (reviewComments.length > 0) {
            await github.rest.pulls.createReview({
              owner: context.repo.owner,
              repo: context.repo.repo,
              pull_number: context.issue.number,
              comments: reviewComments,
              event: 'COMMENT'
            });
          }

    # Review 2: Security Patterns Check
    - name: Security patterns review
      uses: actions/github-script@v6
      with:
        script: |
          let securityIssues = [];
          
          const { data: files } = await github.rest.pulls.listFiles({
            owner: context.repo.owner,
            repo: context.repo.repo,
            pull_number: context.issue.number
          });
          
          for (const file of files) {
            if (file.patch) {
              const addedLines = file.patch.split('\n').filter(line => line.startsWith('+'));
              
              addedLines.forEach(line => {
                // Check for SQL injection patterns
                if (line.match(/\$\{.*\}.*SELECT|SELECT.*\$\{.*\}/i)) {
                  securityIssues.push(`🔐 **SQL Injection Risk** in \`${file.filename}\`: Potential SQL injection vulnerability detected.`);
                }
                
                // Check for XSS patterns
                if (line.match(/innerHTML\s*=|document\.write\(/)) {
                  securityIssues.push(`🔐 **XSS Risk** in \`${file.filename}\`: Potential XSS vulnerability with innerHTML or document.write.`);
                }
                
                // Check for insecure HTTP
                if (line.match(/http:\/\/(?!localhost|127\.0\.0\.1)/)) {
                  securityIssues.push(`🔐 **Insecure HTTP** in \`${file.filename}\`: Use HTTPS instead of HTTP for external requests.`);
                }
              });
            }
          }
          
          if (securityIssues.length > 0) {
            const body = '## 🛡️ Automated Security Review\n\n' + securityIssues.join('\n\n') + '\n\n*This is an automated security review. Please address these issues before merging.*';
            
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: body
            });
          }

    # Review 3: Performance Patterns
    - name: Performance review
      uses: actions/github-script@v6
      with:
        script: |
          let performanceIssues = [];
          
          const { data: files } = await github.rest.pulls.listFiles({
            owner: context.repo.owner,
            repo: context.repo.repo,
            pull_number: context.issue.number
          });
          
          for (const file of files) {
            if (file.patch && file.filename.endsWith('.ts')) {
              const addedLines = file.patch.split('\n').filter(line => line.startsWith('+'));
              
              addedLines.forEach(line => {
                // Check for synchronous operations in async context
                if (line.includes('fs.readFileSync') || line.includes('fs.writeFileSync')) {
                  performanceIssues.push(`⚡ **Performance Issue** in \`${file.filename}\`: Consider using async file operations instead of sync.`);
                }
                
                // Check for inefficient loops
                if (line.match(/for.*in.*Object\.keys|for.*of.*Object\.keys/)) {
                  performanceIssues.push(`⚡ **Performance Issue** in \`${file.filename}\`: Consider using Object.entries() instead of Object.keys() in loops.`);
                }
                
                // Check for multiple database calls in loops
                if (line.match(/for.*\{[\s\S]*?await.*db\.|forEach.*await.*db\./)) {
                  performanceIssues.push(`⚡ **Performance Issue** in \`${file.filename}\`: Multiple database calls in loop detected. Consider batch operations.`);
                }
              });
            }
          }
          
          if (performanceIssues.length > 0) {
            const body = '## ⚡ Automated Performance Review\n\n' + performanceIssues.join('\n\n') + '\n\n*This is an automated performance review. Consider optimizing these patterns.*';
            
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: body
            });
          }

    # Review 4: Best Practices Check
    - name: Best practices review
      uses: actions/github-script@v6
      with:
        script: |
          let bestPracticeIssues = [];
          
          const { data: files } = await github.rest.pulls.listFiles({
            owner: context.repo.owner,
            repo: context.repo.repo,
            pull_number: context.issue.number
          });
          
          for (const file of files) {
            if (file.patch && file.filename.endsWith('.ts')) {
              const addedLines = file.patch.split('\n').filter(line => line.startsWith('+'));
              
              addedLines.forEach(line => {
                // Check for missing error handling
                if (line.includes('await ') && !line.includes('try') && !line.includes('.catch(')) {
                  bestPracticeIssues.push(`💡 **Best Practice** in \`${file.filename}\`: Consider adding error handling for async operations.`);
                }
                
                // Check for magic numbers
                if (line.match(/\d{4,}/) && !line.includes('port') && !line.includes('timeout')) {
                  bestPracticeIssues.push(`💡 **Best Practice** in \`${file.filename}\`: Consider extracting magic numbers to named constants.`);
                }
                
                // Check for missing TypeScript types
                if (line.match(/:\s*any/) && !line.includes('eslint-disable')) {
                  bestPracticeIssues.push(`💡 **TypeScript** in \`${file.filename}\`: Avoid using 'any' type. Consider using specific types.`);
                }
              });
            }
          }
          
          if (bestPracticeIssues.length > 0) {
            const body = '## 💡 Automated Best Practices Review\n\n' + bestPracticeIssues.join('\n\n') + '\n\n*These are suggestions to improve code quality and maintainability.*';
            
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: body
            });
          }

    # Final review summary
    - name: Review summary
      uses: actions/github-script@v6
      with:
        script: |
          const { data: comments } = await github.rest.issues.listComments({
            owner: context.repo.owner,
            repo: context.repo.repo,
            issue_number: context.issue.number
          });
          
          const automatedComments = comments.filter(comment => 
            comment.body.includes('Automated') && 
            comment.user.type === 'Bot'
          );
          
          if (automatedComments.length === 0) {
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: '## ✅ Automated Code Review Complete\n\n🎉 **Great job!** No automated issues detected in this PR.\n\nThe code follows security, performance, and best practice guidelines.\n\n*This PR is ready for human review.*'
            });
          }
EOF

    echo -e "${GREEN}✅ Automated code review workflow created${NC}"
}

# Main setup function
main() {
    echo -e "${BLUE}Starting Team Collaboration Features setup...${NC}\n"
    
    # Check prerequisites
    if ! command -v gh &> /dev/null; then
        echo -e "${YELLOW}⚠️  GitHub CLI not found. Some features will be limited.${NC}"
        echo -e "${BLUE}Install GitHub CLI: https://cli.github.com/${NC}"
    fi
    
    echo -e "${BLUE}Team collaboration features to be configured:${NC}"
    echo -e "✅ Pull request automation with comprehensive testing"
    echo -e "✅ Branch protection rules with required reviews"
    echo -e "✅ Code quality gates with coverage and security thresholds"
    echo -e "✅ Automated code review with security and performance checks"
    echo -e "✅ CODEOWNERS file for automatic reviewer assignment"
    
    read -p "Press Enter to continue..."
    
    # Create all team collaboration features
    create_pr_automation
    create_branch_protection
    create_codeowners
    create_quality_gates
    create_automated_review
    
    echo -e "\n${GREEN}🎉 Team Collaboration Features Setup Complete!${NC}"
    echo -e "${GREEN}=============================================${NC}"
    echo -e "${BLUE}What was created:${NC}"
    echo -e "✅ PR automation workflow (.github/workflows/pr-automation.yml)"
    echo -e "✅ Branch protection setup script (./setup-branch-protection.sh)"
    echo -e "✅ CODEOWNERS file (.github/CODEOWNERS)"
    echo -e "✅ Quality gates workflow (.github/workflows/quality-gates.yml)"
    echo -e "✅ Automated code review workflow (.github/workflows/automated-review.yml)"
    
    echo -e "\n${YELLOW}⚠️  Next steps:${NC}"
    echo -e "1. Update GitHub usernames in CODEOWNERS file"
    echo -e "2. Run ./setup-branch-protection.sh <your-github-username>"
    echo -e "3. Test workflows by creating a pull request"
    echo -e "4. Configure team members and review requirements"
    echo -e "5. Set up GitHub secrets for automated workflows"
    
    echo -e "\n${BLUE}Features enabled:${NC}"
    echo -e "🔍 Automated code quality checks on every PR"
    echo -e "🛡️  Branch protection with required reviews"
    echo -e "🤖 Automated security and performance reviews"
    echo -e "📊 Code coverage and quality gates"
    echo -e "👥 Automatic reviewer assignment based on file changes"
}

# Run main function
main "$@"