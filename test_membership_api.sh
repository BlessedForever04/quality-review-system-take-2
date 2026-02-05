#!/bin/bash

# Test script to check project membership API
# Usage: ./test_membership_api.sh <project_id>

PROJECT_ID=${1:-"69847f81fc618a2107aee20a"}
BASE_URL="http://localhost:8000/api/v1"

echo "Testing Project Membership API"
echo "================================"
echo "Project ID: $PROJECT_ID"
echo ""

echo "Fetching project members..."
curl -s "${BASE_URL}/projects/members?project_id=${PROJECT_ID}" | jq '.'

echo ""
echo "================================"
echo "Test complete"
