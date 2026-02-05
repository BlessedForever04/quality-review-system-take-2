# Checklist Iteration System - Implementation Summary

## Overview
Implemented a comprehensive iteration system that preserves complete review history when a reviewer reverts a checklist back to the executor.

## Changes Made

### 1. Database Schema Updates (`projectChecklist.models.js`)

#### New Schema: `projectChecklistIterationSchema`
```javascript
{
  iterationNumber: Number,        // Sequential iteration counter
  groups: [projectGroupSchema],   // Complete snapshot of all checklist groups
  revertedAt: Date,              // Timestamp when reverted
  revertedBy: ObjectId,          // User who triggered the revert (reviewer)
  revertNotes: String,           // Optional notes explaining the revert
  executorSubmittedAt: Date,     // When executor submitted this iteration
  reviewerSubmittedAt: Date,     // When reviewer reviewed this iteration
}
```

#### Updated: `projectChecklistSchema`
- Added `iterations` array to store historical reviews
- Added `currentIteration` number to track the active iteration
- Maintains backward compatibility with existing `groups` field

### 2. Backend Controller Updates (`approval.controller.js`)

#### Enhanced `revertToExecutor` Function
**New Behavior:**
1. Finds the current ProjectChecklist for the stage
2. Creates a complete snapshot of current state:
   - All groups with questions
   - All answers (executor and reviewer)
   - All remarks and images
   - Defect categories and severities
   - Submission timestamps
3. Saves snapshot as new iteration in `iterations` array
4. Increments `currentIteration` counter
5. Updates approval status to allow executor to re-edit
6. Increments conflict counter

**What Gets Saved Per Iteration:**
- ✅ All questions with executor answers
- ✅ All questions with reviewer answers/statuses
- ✅ Executor and reviewer remarks
- ✅ All uploaded images (fileIds and filenames)
- ✅ Defect categories and severities
- ✅ Who reverted and when
- ✅ Revert notes/reason
- ✅ Submission timestamps for both roles

### 3. New API Endpoint

```
GET /api/v1/projects/:projectId/stages/:stageId/project-checklist/iterations
```

**Response:**
```json
{
  "success": true,
  "data": {
    "iterations": [
      {
        "iterationNumber": 1,
        "groups": [ /* complete checklist data */ ],
        "revertedAt": "2026-02-05T12:00:00Z",
        "revertedBy": { "name": "Reviewer Name", "email": "reviewer@email.com" },
        "revertNotes": "Needs corrections in section 2",
        "executorSubmittedAt": "2026-02-05T10:00:00Z",
        "reviewerSubmittedAt": "2026-02-05T11:00:00Z"
      }
    ],
    "currentIteration": 2,
    "totalIterations": 1
  }
}
```

### 4. Routes Updated (`projectChecklist.routes.js`)
Added new route for fetching iterations with authentication middleware.

## How It Works

### Workflow
1. **Initial Review (Iteration 1)**
   - Executor fills checklist → submits
   - Reviewer reviews → either approves OR reverts

2. **When Reviewer Reverts**
   - System creates snapshot of current state (iteration 1)
   - Saves to `iterations` array with:
     - All Q&A data
     - Images
     - Defect info
     - Who/when/why reverted
   - Increments to iteration 2
   - Executor can now edit again

3. **Subsequent Reviews**
   - Each revert creates a new iteration
   - All historical data preserved
   - Can view any past iteration

### Data Preservation
- **Current Work**: Lives in `groups` field (editable)
- **Historical Work**: Lives in `iterations` array (read-only)
- **Iteration Counter**: Tracks which review cycle we're in

## Benefits

1. **Complete Audit Trail**: Every review cycle is preserved with full detail
2. **Accountability**: Know who reverted, when, and why
3. **Historical Analysis**: Can review past iterations to see what changed
4. **No Data Loss**: Nothing gets overwritten when executor re-edits
5. **Conflict Tracking**: Iterations count shows how many review cycles occurred

## Usage Examples

### Backend
```javascript
// Iterations are automatically saved when reverting
POST /api/v1/projects/:projectId/approval/revert-to-executor
{
  "phase": 1,
  "notes": "Please update section 2.3"
}

// Retrieve all iterations
GET /api/v1/projects/:projectId/stages/:stageId/project-checklist/iterations
```

### Database Structure
```javascript
{
  projectId: ObjectId,
  stageId: ObjectId,
  stage: "stage1",
  groups: [ /* current/active checklist */ ],
  currentIteration: 3,
  iterations: [
    { iterationNumber: 1, groups: [...], revertedAt: ..., revertNotes: "..." },
    { iterationNumber: 2, groups: [...], revertedAt: ..., revertNotes: "..." }
  ]
}
```

## Testing

### Manual Test Steps
1. Executor fills and submits checklist
2. Reviewer reviews and reverts with notes
3. Check database: `iterations` array should have 1 entry
4. Executor re-fills and submits
5. Reviewer reviews and reverts again
6. Check database: `iterations` array should have 2 entries
7. Call GET iterations endpoint to verify all data

### Verification Queries
```javascript
// Find checklist with iterations
db.projectchecklists.findOne(
  { projectId: ObjectId("..."), stageId: ObjectId("...") },
  { iterations: 1, currentIteration: 1 }
)

// Count total iterations for a project
db.projectchecklists.aggregate([
  { $match: { projectId: ObjectId("...") } },
  { $project: { iterationCount: { $size: "$iterations" } } }
])
```

## Next Steps (Frontend Integration)

1. Create Flutter service to fetch iterations
2. Add UI to display iteration history
3. Show iteration selector/viewer in checklist screen
4. Display "Iteration X of Y" indicator
5. Allow viewing past iterations in read-only mode

## Files Modified
- `/lib/QRP-backend-main/src/models/projectChecklist.models.js`
- `/lib/QRP-backend-main/src/controllers/approval.controller.js`
- `/lib/QRP-backend-main/src/controllers/projectChecklist.controller.js`
- `/lib/QRP-backend-main/src/routes/projectChecklist.routes.js`
