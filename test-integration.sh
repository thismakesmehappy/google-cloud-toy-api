#!/bin/bash

# Integration Test Suite for Toy API
# Usage: ./test-integration.sh <service_url> <api_key> [environment]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SERVICE_URL="$1"
API_KEY="$2"
ENVIRONMENT="${3:-unknown}"

if [ -z "$SERVICE_URL" ] || [ -z "$API_KEY" ]; then
    echo -e "${RED}❌ Usage: $0 <service_url> <api_key> [environment]${NC}"
    exit 1
fi

echo -e "${BLUE}🧪 Running integration tests for $ENVIRONMENT environment${NC}"
echo -e "${BLUE}Service URL: $SERVICE_URL${NC}"

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0
TEST_RESULTS=()

# Helper function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_code="${3:-0}"
    
    echo -e "${YELLOW}🔍 Testing: $test_name${NC}"
    
    if eval "$test_command" &>/dev/null; then
        local actual_code=$?
        if [ $actual_code -eq $expected_code ]; then
            echo -e "${GREEN}✅ PASS: $test_name${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            TEST_RESULTS+=("✅ $test_name")
        else
            echo -e "${RED}❌ FAIL: $test_name (exit code: $actual_code, expected: $expected_code)${NC}"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            TEST_RESULTS+=("❌ $test_name")
        fi
    else
        echo -e "${RED}❌ FAIL: $test_name (command failed)${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TEST_RESULTS+=("❌ $test_name")
    fi
}

# Wait for service to be ready
echo -e "${YELLOW}⏳ Waiting for service to be ready...${NC}"
sleep 15

# Test 1: Health check - root endpoint
run_test "Root endpoint health check" \
    "curl -s -f --max-time 10 '$SERVICE_URL/'"

# Test 2: Public endpoint
run_test "Public endpoint accessibility" \
    "curl -s -f --max-time 10 '$SERVICE_URL/public'"

# Test 3: Public endpoint returns expected JSON
run_test "Public endpoint returns JSON" \
    "curl -s --max-time 10 '$SERVICE_URL/public' | grep -q 'message'"

# Test 4: Private endpoint without auth (should fail)
run_test "Private endpoint rejects unauthorized access" \
    "curl -s --max-time 10 '$SERVICE_URL/items'" 1

# Test 5: Private endpoint with auth
run_test "Authenticated endpoint with API key" \
    "curl -s -f --max-time 10 -H 'x-api-key: $API_KEY' '$SERVICE_URL/items'"

# Test 6: Create item endpoint
run_test "Create item with authentication" \
    "curl -s -f --max-time 10 -X POST -H 'x-api-key: $API_KEY' -H 'Content-Type: application/json' -d '{\"message\":\"test item\"}' '$SERVICE_URL/items'"

# Test 7: Auth token endpoint
run_test "Auth token generation endpoint" \
    "curl -s -f --max-time 10 -X POST -H 'Content-Type: application/json' -d '{\"uid\":\"test-user\"}' '$SERVICE_URL/auth/token'"

# Test 8: Invalid API key (should fail)
run_test "Invalid API key rejection" \
    "curl -s --max-time 10 -H 'x-api-key: invalid-key-123' '$SERVICE_URL/items'" 1

# Test 9: Response time check (should respond within 3 seconds)
run_test "Response time under 3 seconds" \
    "timeout 3s curl -s -f '$SERVICE_URL/public'"

# Test 10: Service returns proper HTTP headers
run_test "Service returns proper Content-Type header" \
    "curl -s -I --max-time 10 '$SERVICE_URL/public' | grep -q 'content-type.*json'"

# Summary
echo -e "\n${BLUE}📊 Test Results Summary for $ENVIRONMENT:${NC}"
echo -e "${GREEN}✅ Tests Passed: $TESTS_PASSED${NC}"
echo -e "${RED}❌ Tests Failed: $TESTS_FAILED${NC}"

echo -e "\n${BLUE}📋 Detailed Results:${NC}"
for result in "${TEST_RESULTS[@]}"; do
    echo "  $result"
done

# Exit with appropriate code
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All integration tests passed for $ENVIRONMENT!${NC}"
    exit 0
else
    echo -e "\n${RED}💥 $TESTS_FAILED integration tests failed for $ENVIRONMENT${NC}"
    exit 1
fi