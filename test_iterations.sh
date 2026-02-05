#!/bin/bash

echo "=========================================="
echo "Testing Checklist Iteration System"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

BASE_URL="http://localhost:8000/api/v1"

# You'll need to replace these with actual IDs from your database
PROJECT_ID="69847f71fc618a2107aee208"  # Replace with your project ID
STAGE_ID=""  # Will be fetched
PHASE=1

echo -e "${BLUE}Step 1: Get Project to find Stage ID${NC}"
PROJECT_RESPONSE=$(curl -s "${BASE_URL}/projects/${PROJECT_ID}")
echo "Project fetched"
echo ""

echo -e "${BLUE}Step 2: Get stages for this project${NC}"
STAGES_RESPONSE=$(curl -s "${BASE_URL}/projects/${PROJECT_ID}/stages")
echo "$STAGES_RESPONSE" | python3 -m json.tool 2>/dev/null | head -30
echo ""

# Extract first stage ID (you may need to adjust based on your data structure)
STAGE_ID=$(echo "$STAGES_RESPONSE" | grep -o '"_id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$STAGE_ID" ]; then
    echo -e "${RED}❌ Could not find stage ID${NC}"
    echo "Please create a project with stages first"
    exit 1
fi

echo -e "${GREEN}✅ Using Stage ID: $STAGE_ID${NC}"
echo ""

echo -e "${BLUE}Step 3: Check current checklist iterations${NC}"
ITERATIONS_RESPONSE=$(curl -s "${BASE_URL}/projects/${PROJECT_ID}/stages/${STAGE_ID}/project-checklist/iterations")
echo "$ITERATIONS_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$ITERATIONS_RESPONSE"
echo ""

echo -e "${YELLOW}Expected Response:${NC}"
echo '{
  "success": true,
  "data": {
    "iterations": [],
    "currentIteration": 1,
    "totalIterations": 0
  }
}'
echo ""

echo "=========================================="
echo -e "${GREEN}✅ Iteration System Test Complete${NC}"
echo "=========================================="
echo ""
echo "To see iterations in action:"
echo "1. Have executor fill and submit the checklist"
echo "2. Have reviewer review and revert to executor"
echo "3. Re-run this script to see the saved iteration"
echo ""
echo "Each revert will create a new iteration preserving:"
echo "  - All answers (executor & reviewer)"
echo "  - All remarks and images"
echo "  - Defect categories and severities"
echo "  - Who reverted and when"
