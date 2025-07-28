#!/bin/bash

# Validate CI/CD Pipeline Components
# This script tests the CI/CD pipeline components locally before pushing to GitHub

set -e

echo "🧪 Validating CI/CD Pipeline Components"
echo "======================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
tests_passed=0
tests_failed=0

# Function to run test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -e "\n${YELLOW}🔍 Testing: $test_name${NC}"
    
    if eval "$test_command"; then
        echo -e "${GREEN}✅ PASS: $test_name${NC}"
        ((tests_passed++))
    else
        echo -e "${RED}❌ FAIL: $test_name${NC}"
        ((tests_failed++))
    fi
}

# Change to project directory
cd google-cloud-toy-api

echo -e "${YELLOW}📂 Testing in directory: $(pwd)${NC}"

# Test 1: Package.json scripts exist
run_test "Package.json has required scripts" "
    grep -q '\"build\":' package.json &&
    grep -q '\"test\":' package.json &&
    grep -q '\"lint\":' package.json &&
    grep -q '\"type-check\":' package.json
"

# Test 2: Dependencies are installable
run_test "Dependencies install successfully" "npm install --silent"

# Test 3: TypeScript compilation
run_test "TypeScript compilation" "npm run type-check"

# Test 4: Build process
run_test "Build process" "npm run build"

# Test 5: Test script runs
run_test "Test script execution" "npm test"

# Test 6: Lint script runs
run_test "Lint script execution" "npm run lint"

# Change back to root for Terraform tests
cd ..

# Test 7: Terraform modules validate
for env in dev staging prod; do
    run_test "Terraform $env environment validation" "
        cd google-cloud-toy-api/terraform/environments/$env &&
        terraform init -backend=false > /dev/null 2>&1 &&
        terraform validate &&
        cd ../../..
    "
done

# Test 8: GitHub workflow syntax
run_test "GitHub Actions workflow syntax" "
    if command -v yamllint >/dev/null 2>&1; then
        yamllint .github/workflows/deploy.yml
    else
        # Basic YAML check
        python3 -c 'import yaml; yaml.safe_load(open(\".github/workflows/deploy.yml\"))'
    fi
"

# Test 9: API is still working
run_test "Current API functionality" "
    curl -sf 'https://toy-api-function-dev-ox3pqfvcqq-uc.a.run.app/public' | grep -q 'Hello from the public endpoint'
"

# Test 10: Authentication endpoint
run_test "Authenticated API endpoint" "
    curl -sf -H 'x-api-key: dev-api-key-123' 'https://toy-api-function-dev-ox3pqfvcqq-uc.a.run.app/items' | grep -q '\\['
"

# Summary
echo -e "\n${YELLOW}📊 Test Summary${NC}"
echo "================"
echo -e "${GREEN}✅ Tests Passed: $tests_passed${NC}"
echo -e "${RED}❌ Tests Failed: $tests_failed${NC}"

if [ $tests_failed -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All tests passed! Your CI/CD pipeline is ready.${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Run: ./setup-cicd.sh (to create service accounts)"
    echo "2. Create GitHub repository and add secrets"
    echo "3. Push to GitHub: git push origin main"
    echo "4. Watch the GitHub Actions workflow run!"
    exit 0
else
    echo -e "\n${RED}⚠️  Some tests failed. Please fix the issues before setting up CI/CD.${NC}"
    exit 1
fi