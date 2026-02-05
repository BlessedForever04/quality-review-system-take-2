#!/bin/bash

echo "======================================"
echo "Testing Project Membership Fix"
echo "======================================"
echo ""

# First, let's get a list of projects to find a valid project ID
echo "1. Fetching projects..."
PROJECT_RESPONSE=$(curl -s "http://localhost:8000/api/v1/projects")

# Extract first project ID (if any)
PROJECT_ID=$(echo "$PROJECT_RESPONSE" | grep -o '"_id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$PROJECT_ID" ]; then
    echo "❌ No projects found in database"
    echo "Please create a project first through the admin UI"
    exit 1
fi

echo "✅ Found project ID: $PROJECT_ID"
echo ""

# Now test getting members for this project
echo "2. Fetching members for project $PROJECT_ID..."
MEMBERS_RESPONSE=$(curl -s "http://localhost:8000/api/v1/projects/members?project_id=$PROJECT_ID")

echo "$MEMBERS_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$MEMBERS_RESPONSE"
echo ""

# Check if the response indicates success
if echo "$MEMBERS_RESPONSE" | grep -q '"success":true'; then
    MEMBER_COUNT=$(echo "$MEMBERS_RESPONSE" | grep -o '"members":\[' | wc -l)
    echo "✅ API call successful"
    echo "Members data structure is present"
else
    echo "❌ API call failed or returned error"
fi

echo ""
echo "======================================"
echo "Test Complete"
echo "======================================"
