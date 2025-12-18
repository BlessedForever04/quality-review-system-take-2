# Template & Checkpoint API Documentation

## Overview
This document describes the **Template**, **Checklist**, and **Checkpoint** APIs integrated from V3 into QRP-backend-main.

### Key Concepts

1. **Template**: A single system-wide document containing predefined checklist structures organized by stages (phase1, phase2, phase3). Used as a blueprint when creating new projects.

2. **Checklist**: Actual checklist instances tied to specific stages. The existing QRP-backend-main checklist model remains unchanged.

3. **Checkpoint**: Individual questions/checkpoints within checklists. Stores executor and reviewer responses with support for Yes/No answers, remarks, and images.

---

## Template APIs

Base URL: `/api/v1/templates`

### 1. Create Template (One-Time Setup)

**POST** `/api/v1/templates`

Creates the initial template. Only ONE template should exist in the system.

**Auth Required**: Yes

**Request Body**:
```json
{
  "name": "Quality Review Template" // optional, defaults to "Default Quality Review Template"
}
```

**Response** (201):
```json
{
  "statusCode": 201,
  "data": {
    "_id": "template_id",
    "name": "Quality Review Template",
    "stage1": [],
    "stage2": [],
    "stage3": [],
    "createdAt": "2024-01-01T00:00:00.000Z",
    "updatedAt": "2024-01-01T00:00:00.000Z"
  },
  "message": "Template created successfully",
  "success": true
}
```

---

### 2. Get Template

**GET** `/api/v1/templates`

Fetches the single template document with all stages and their checklists/checkpoints.

**Auth Required**: No (can be changed based on requirements)

**Response** (200):
```json
{
  "statusCode": 200,
  "data": {
    "_id": "template_id",
    "name": "Quality Review Template",
    "stage1": [
      {
        "_id": "checklist_1",
        "text": "Verification",
        "checkpoints": [
          {
            "_id": "checkpoint_1",
            "text": "Original BDF available?"
          },
          {
            "_id": "checkpoint_2",
            "text": "Revised input file checked?"
          }
        ]
      }
    ],
    "stage2": [...],
    "stage3": [...],
    "modifiedBy": "user_id",
    "createdAt": "2024-01-01T00:00:00.000Z",
    "updatedAt": "2024-01-01T10:30:00.000Z"
  },
  "message": "Template fetched successfully",
  "success": true
}
```

---

### 3. Add Checklist to Template

**POST** `/api/v1/templates/checklists`

Adds a new checklist group to a specific stage in the template.

**Auth Required**: Yes

**Request Body**:
```json
{
  "stage": "stage1",  // Must be: "stage1", "stage2", or "stage3"
  "text": "Geometry Preparation"
}
```

**Response** (200):
```json
{
  "statusCode": 200,
  "data": {
    "_id": "template_id",
    "stage1": [
      // ... existing checklists
      {
        "_id": "new_checklist_id",
        "text": "Geometry Preparation",
        "checkpoints": []
      }
    ],
    // ...
  },
  "message": "Checklist added to template successfully",
  "success": true
}
```

---

### 4. Update Checklist in Template

**PATCH** `/api/v1/templates/checklists/:checklistId`

Updates the text/name of a checklist in the template.

**Auth Required**: Yes

**Request Body**:
```json
{
  "stage": "stage1",
  "text": "Updated Checklist Name"
}
```

**Response** (200):
```json
{
  "statusCode": 200,
  "data": { /* updated template */ },
  "message": "Checklist updated successfully",
  "success": true
}
```

---

### 5. Delete Checklist from Template

**DELETE** `/api/v1/templates/checklists/:checklistId`

Removes a checklist from the template.

**Auth Required**: Yes

**Request Body**:
```json
{
  "stage": "stage1"
}
```

**Response** (200):
```json
{
  "statusCode": 200,
  "data": { /* updated template */ },
  "message": "Checklist deleted successfully",
  "success": true
}
```

---

### 6. Add Checkpoint to Checklist in Template

**POST** `/api/v1/templates/checklists/:checklistId/checkpoints`

Adds a checkpoint (question) to a checklist within the template.

**Auth Required**: Yes

**Request Body**:
```json
{
  "stage": "stage1",
  "text": "Is imported geometry correct?"
}
```

**Response** (200):
```json
{
  "statusCode": 200,
  "data": { /* updated template with new checkpoint */ },
  "message": "Checkpoint added successfully",
  "success": true
}
```

---

### 7. Update Checkpoint in Template

**PATCH** `/api/v1/templates/checkpoints/:checkpointId`

Updates a checkpoint's text within the template.

**Auth Required**: Yes

**Request Body**:
```json
{
  "stage": "stage1",
  "checklistId": "checklist_id",
  "text": "Updated question text?"
}
```

**Response** (200):
```json
{
  "statusCode": 200,
  "data": { /* updated template */ },
  "message": "Checkpoint updated successfully",
  "success": true
}
```

---

### 8. Delete Checkpoint from Template

**DELETE** `/api/v1/templates/checkpoints/:checkpointId`

Removes a checkpoint from the template.

**Auth Required**: Yes

**Request Body**:
```json
{
  "stage": "stage1",
  "checklistId": "checklist_id"
}
```

**Response** (200):
```json
{
  "statusCode": 200,
  "data": { /* updated template */ },
  "message": "Checkpoint deleted successfully",
  "success": true
}
```

---

## Checkpoint APIs

Base URL: `/api/v1`

### 1. Create Checkpoint

**POST** `/api/v1/checklists/:checklistId/checkpoints`

Creates a new checkpoint (question) for a checklist instance.

**Auth Required**: Yes

**Request Body**:
```json
{
  "question": "Are all welds inspected?"
}
```

**Response** (201):
```json
{
  "statusCode": 201,
  "data": {
    "_id": "checkpoint_id",
    "checklistId": "checklist_id",
    "question": "Are all welds inspected?",
    "executorResponse": {},
    "reviewerResponse": {},
    "createdAt": "2024-01-01T00:00:00.000Z",
    "updatedAt": "2024-01-01T00:00:00.000Z"
  },
  "message": "Checkpoint created successfully",
  "success": true
}
```

---

### 2. Get Checkpoints by Checklist ID

**GET** `/api/v1/checklists/:checklistId/checkpoints`

Fetches all checkpoints for a specific checklist (without image binary data for performance).

**Auth Required**: No

**Response** (200):
```json
{
  "statusCode": 200,
  "data": [
    {
      "_id": "checkpoint_id",
      "checklistId": "checklist_id",
      "question": "Are all welds inspected?",
      "executorResponse": {
        "answer": true,  // true = Yes, false = No, null = not answered
        "remark": "All welds pass inspection",
        "respondedAt": "2024-01-01T10:00:00.000Z"
      },
      "reviewerResponse": {
        "answer": true,
        "remark": "Verified",
        "reviewedAt": "2024-01-01T11:00:00.000Z"
      },
      "createdAt": "2024-01-01T00:00:00.000Z",
      "updatedAt": "2024-01-01T11:00:00.000Z"
    }
  ],
  "message": "Checkpoints fetched successfully",
  "success": true
}
```

---

### 3. Get Checkpoint by ID

**GET** `/api/v1/checkpoints/:checkpointId`

Fetches a single checkpoint by its ID (without image binary data).

**Auth Required**: No

**Response** (200):
```json
{
  "statusCode": 200,
  "data": {
    "_id": "checkpoint_id",
    "checklistId": "checklist_id",
    "question": "Are all welds inspected?",
    "executorResponse": { /* ... */ },
    "reviewerResponse": { /* ... */ },
    "createdAt": "2024-01-01T00:00:00.000Z",
    "updatedAt": "2024-01-01T11:00:00.000Z"
  },
  "message": "Checkpoint fetched successfully",
  "success": true
}
```

---

### 4. Update Checkpoint Response

**PATCH** `/api/v1/checkpoints/:checkpointId`

Updates executor or reviewer response for a checkpoint. Supports image uploads via multipart/form-data.

**Auth Required**: Yes

**Request Body** (JSON or multipart/form-data):
```json
{
  "executorResponse": {
    "answer": true,  // true = Yes, false = No
    "remark": "All checks passed"
  }
  // OR
  "reviewerResponse": {
    "answer": false,
    "remark": "Needs correction"
  }
}
```

**For Image Uploads** (use multipart/form-data):
- Field name: `images` (array, max 5 files)
- Images will be stored as Buffer in `executorResponse.images`

**Response** (200):
```json
{
  "statusCode": 200,
  "data": {
    "_id": "checkpoint_id",
    "executorResponse": {
      "answer": true,
      "remark": "All checks passed",
      "respondedAt": "2024-01-01T10:30:00.000Z",
      "images": [
        {
          "_id": "image_id",
          "contentType": "image/jpeg"
          // Note: 'data' field (Buffer) is excluded from response
        }
      ]
    },
    // ...
  },
  "message": "Checkpoint updated successfully",
  "success": true
}
```

---

### 5. Delete Checkpoint

**DELETE** `/api/v1/checkpoints/:checkpointId`

Deletes a checkpoint by its ID.

**Auth Required**: Yes

**Response** (200):
```json
{
  "statusCode": 200,
  "data": null,
  "message": "Checkpoint deleted successfully",
  "success": true
}
```

---

## Integration with Existing Systems

### How Template Works with Projects

1. **Admin creates/edits template** using Template APIs
2. **When a new project is created**, the frontend can:
   - Fetch template via `GET /api/v1/templates`
   - Use template structure to initialize project checklists/checkpoints
   - Create actual Checklist instances via existing `POST /api/v1/stages/:stageId/checklists`
   - Create Checkpoints for each checklist via `POST /api/v1/checklists/:checklistId/checkpoints`

### Relationship Between Models

```
Template (singleton)
  └─ stage1/stage2/stage3 (arrays)
      └─ Checklist Templates
          └─ Checkpoint Templates

Project
  └─ Stage (instance)
      └─ Checklist (instance)
          └─ Checkpoint (instance)
              ├─ executorResponse
              └─ reviewerResponse
```

---

## Error Responses

All endpoints follow the same error format:

```json
{
  "statusCode": 400,
  "data": null,
  "message": "Error description here",
  "success": false,
  "errors": []
}
```

Common status codes:
- `400` - Bad Request (invalid parameters)
- `401` - Unauthorized (auth required)
- `404` - Not Found (resource doesn't exist)
- `500` - Internal Server Error

---

## Migration Notes

### Differences from V3

1. **Naming Conventions**: 
   - V3's camelCase preserved in new models (checklistId, executorResponse, reviewerResponse)
   - Matches V3's original implementation for team familiarity

2. **Response Format**:
   - V3 uses `ApiResponse` class → QRP-backend-main uses same format
   - Both follow: `{ statusCode, data, message, success }`

3. **Authentication**:
   - Both use `authMiddleware` from existing QRP-backend-main
   - JWT token required in `Authorization` header

4. **Database**:
   - All models use existing MongoDB connection
   - Follow QRP-backend-main's schema patterns

---

## Testing Recommendations

### 1. Template Setup
```bash
# Create template
POST /api/v1/templates
{ "name": "QR Template" }

# Add checklist to Phase 1
POST /api/v1/templates/checklists
{ "stage": "stage1", "text": "Verification" }

# Add checkpoint to checklist
POST /api/v1/templates/checklists/{checklistId}/checkpoints
{ "stage": "stage1", "text": "BDF available?" }

# Verify
GET /api/v1/templates
```

### 2. Checkpoint Usage
```bash
# Create checklist instance (existing API)
POST /api/v1/stages/{stageId}/checklists
{ "checklist_name": "Phase 1 Verification" }

# Create checkpoint
POST /api/v1/checklists/{checklistId}/checkpoints
{ "question": "Original BDF available?" }

# Update executor response
PATCH /api/v1/checkpoints/{checkpointId}
{ "executorResponse": { "answer": true, "remark": "Verified" } }

# Fetch checkpoints
GET /api/v1/checklists/{checklistId}/checkpoints
```

---

## Frontend Integration Example

```javascript
// Fetch template and initialize project checklists
const response = await fetch('/api/v1/templates');
const template = await response.json();

// For each stage in the template, create checklist instances
for (const checklistTemplate of template.data.stage1) {
  // Create checklist instance
  const checklist = await createChecklist(stageId, {
    checklist_name: checklistTemplate.text
  });
  
  // Create checkpoints for this checklist
  for (const checkpointTemplate of checklistTemplate.checkpoints) {
    await createCheckpoint(checklist.id, {
      question: checkpointTemplate.text
    });
  }
}
```

---

## Backward Compatibility

✅ **No Breaking Changes**:
- Existing checklist APIs remain unchanged
- New routes use different paths (`/templates`, `/checkpoints`)
- Existing checklist model extended but not modified
- All existing project/stage/checklist functionality preserved

---

## Next Steps

1. **Test all endpoints** with Postman/Insomnia
2. **Update Flutter frontend** to use new APIs
3. **Add seed data** for default template
4. **Consider adding image retrieval endpoint** if needed
5. **Add validation middleware** for stage parameter
6. **Add pagination** for checkpoint lists if needed
7. **Consider caching** template data since it changes infrequently

---

**Integration Date**: December 18, 2025  
**Integrated From**: V3 Backend  
**Integrated Into**: QRP-backend-main  
**Maintainer**: Development Team
