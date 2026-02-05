#!/bin/bash

echo "🧪 Testing Stage Collection Fix"
echo "================================"
echo ""

# Replace with your actual values
API_URL="http://localhost:3000/api"
TOKEN="YOUR_AUTH_TOKEN_HERE"
PROJECT_ID="YOUR_PROJECT_ID_HERE"

echo "📝 Note: Update TOKEN and PROJECT_ID in this script before running"
echo ""

# Test 1: Create a new project (should NOT create Stage documents)
echo "Test 1: Creating new project..."
echo "Expected: No Stage documents should be created"
echo ""

# Test 2: List stages for project (should work from ProjectChecklist)
echo "Test 2: Listing stages..."
curl -X GET "$API_URL/stages/project/$PROJECT_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -s | jq '.'
echo ""

# Test 3: Verify in MongoDB
echo "Test 3: MongoDB Verification Commands"
echo "Run these in MongoDB shell:"
echo ""
echo "// Check if new Stage documents were created (should be empty or old)"
echo "db.stages.find().sort({ createdAt: -1 }).limit(5)"
echo ""
echo "// Check ProjectChecklist has stageMetadata"
echo "db.projectchecklists.find({ projectId: ObjectId('$PROJECT_ID') }, { stageMetadata: 1, stage: 1 })"
echo ""
echo "// Count stages vs projectchecklists"
echo "db.stages.countDocuments()"
echo "db.projectchecklists.countDocuments()"
echo ""

echo "✅ Test script ready!"
echo "Update TOKEN and PROJECT_ID, then run: ./test-no-stage-creation.sh"
