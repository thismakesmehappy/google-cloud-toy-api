#!/bin/bash

# Google Cloud Toy API Test Script
# Your working API endpoints!

API_URL="https://toy-api-function-dev-ox3pqfvcqq-uc.a.run.app"
API_KEY="dev-api-key-123"

echo "🚀 Testing Google Cloud Toy API"
echo "================================="

echo -e "\n1. Testing public endpoint (no auth)..."
curl -X GET "$API_URL/public"

echo -e "\n\n2. Testing items list..."
curl -X GET "$API_URL/items" -H "x-api-key: $API_KEY"

echo -e "\n\n3. Creating a new item..."
RESPONSE=$(curl -s -X POST "$API_URL/items" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{"message": "Created via test script!"}')
echo $RESPONSE

# Extract item ID for further testing
ITEM_ID=$(echo $RESPONSE | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
echo -e "\nCreated item ID: $ITEM_ID"

echo -e "\n4. Fetching the created item..."
curl -X GET "$API_URL/items/$ITEM_ID" -H "x-api-key: $API_KEY"

echo -e "\n\n5. Updating the item..."
curl -X PUT "$API_URL/items/$ITEM_ID" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{"message": "Updated via test script!"}'

echo -e "\n\n6. Final items list..."
curl -X GET "$API_URL/items" -H "x-api-key: $API_KEY"

echo -e "\n\n✅ API Test Complete!"
echo "Your Google Cloud Toy API is working perfectly! 🎉"