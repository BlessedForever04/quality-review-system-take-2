# Missing Image Error Handling - Fix Summary

## Problem
When viewing past iterations, if an image file was deleted from GridFS or never properly uploaded, the backend would crash with:
```
MongoRuntimeError: FileNotFound: file 6984939fa49df3f1b6d6e05f was not found
```

This caused:
- ❌ Backend server errors
- ❌ Broken image display
- ❌ Poor user experience

## Root Cause

### Backend Issue
The `/images/file/:fileId` endpoint would attempt to download a file even if it didn't exist in GridFS:
```javascript
// OLD CODE - Would crash
const stream = await downloadImageById(req.params.fileId);
stream.pipe(res); // Would throw if file doesn't exist
```

### Why Images Go Missing
1. **Iteration snapshots** reference images by fileId
2. **Images may be deleted** from GridFS after snapshot was created
3. **Uploads may fail** but reference is still stored
4. **Database cleanup** might remove orphaned files

## Solutions Implemented

### 1. Backend: Preemptive File Check (images.js)

**Before downloading, check if file exists:**
```javascript
const fileDoc = await db.collection('uploads.files').findOne({ _id: id });

if (!fileDoc) {
    console.warn(`⚠️ Image file not found: ${req.params.fileId}`);
    return res.status(404).json({ error: 'File not found' });
}
```

**Enhanced error handling:**
```javascript
catch (e) {
    // Check for file not found errors
    if (e.code === 'ENOENT' || String(e?.message || '').includes('not found')) {
        return res.status(404).json({ error: 'File not found' });
    }
    // ... other errors
}
```

### 2. Frontend: Better Error Display (checklist.dart)

**Loading indicator while fetching:**
```dart
loadingBuilder: (context, child, loadingProgress) {
    if (loadingProgress == null) return child;
    return Container(
        child: CircularProgressIndicator(...),
    );
}
```

**User-friendly error display:**
```dart
errorBuilder: (_, error, ___) {
    return Container(
        child: Column(
            children: [
                Icon(Icons.broken_image),
                if (_selectedIterationNumber > 0)
                    Text('Missing'), // Shows "Missing" for historical images
            ],
        ),
    );
}
```

**Debug logging:**
```dart
if (kDebugMode) {
    print('❌ Failed to load image $fileId: $error');
}
```

## How It Works Now

### Scenario: Missing Image File

**Before:**
```
1. User selects past iteration
2. Frontend requests: GET /api/v1/images/file/6984939fa49df3f1b6d6e05f
3. Backend throws MongoRuntimeError
4. Server logs error, request hangs
5. User sees loading spinner forever
```

**After:**
```
1. User selects past iteration
2. Frontend requests: GET /api/v1/images/file/6984939fa49df3f1b6d6e05f
3. Backend checks if file exists in GridFS
4. File not found → Returns 404 with JSON error
5. Frontend shows placeholder with "Missing" label
6. User continues working (no crash)
```

## Visual Indicators

### Loading State
```
┌──────────────┐
│              │
│      ⌛      │  ← Circular progress indicator
│   Loading    │
│              │
└──────────────┘
```

### Missing Image (Current Iteration)
```
┌──────────────┐
│              │
│      🔲      │  ← Broken image icon
│              │
│              │
└──────────────┘
```

### Missing Image (Past Iteration)
```
┌──────────────┐
│              │
│      🔲      │  ← Broken image icon
│   Missing    │  ← Label indicates historical
│              │
└──────────────┘
```

## Files Modified

### Backend
✅ `/lib/QRP-backend-main/src/routes/images.js`
- Added preemptive file existence check
- Enhanced error handling for ENOENT errors
- Added warning logs for missing files
- Return 404 instead of 500 for missing files

### Frontend
✅ `/lib/pages/employee_pages/checklist.dart`
- Added loading indicator during image fetch
- Enhanced error builder with iteration-aware messaging
- Added debug logging for failed image loads
- Shows "Missing" label for historical images

## Testing

### Test Case 1: Missing Image in Past Iteration
1. View an iteration with a missing image
2. **Expected:** Placeholder shows broken icon + "Missing" text
3. **Expected:** No backend crash
4. **Expected:** Console shows: `⚠️ Image file not found: [fileId]`

### Test Case 2: Valid Image in Past Iteration
1. View an iteration with valid images
2. **Expected:** Images load and display correctly
3. **Expected:** No errors in console

### Test Case 3: Slow Network
1. View iteration on slow network
2. **Expected:** Loading spinner appears while fetching
3. **Expected:** Images appear when loaded
4. **Expected:** Smooth transition from loading to loaded

## Console Output

### Backend (Missing Image)
```
⚠️ Image file not found: 6984939fa49df3f1b6d6e05f
```

### Frontend (Missing Image)
```
❌ Failed to load image 6984939fa49df3f1b6d6e05f: HTTP 404
```

### Frontend (Loading Images)
```
🖼️ Rendering image 0: {fileId: 69848bfa..., filename: image.jpg}
   bytes: null
   fileId: 69848bfa9117915cfd1656c0
   name: image.jpg
```

## Benefits

✅ **No Server Crashes** - Missing images return 404, not 500
✅ **Better UX** - Users see what went wrong
✅ **Graceful Degradation** - Missing images don't break the UI
✅ **Debug Friendly** - Clear console logs for troubleshooting
✅ **Historical Context** - "Missing" label shows it's from past iteration
✅ **Loading States** - Progress indicator improves perceived performance

## Prevention Recommendations

### For Production

1. **Implement Cascade Delete**
   - When deleting checklist, delete associated images
   - When reverting, ensure all referenced images exist

2. **Add Image Validation**
   - Before saving iteration, verify all image files exist
   - Remove references to non-existent images

3. **Periodic Cleanup**
   - Scan for orphaned image references
   - Alert on missing files in active iterations

4. **Upload Verification**
   - Confirm upload success before storing reference
   - Retry failed uploads

## Migration Script (Optional)

If you want to clean up existing data:

```javascript
// Find all iterations with missing images
const checklists = await ProjectChecklist.find({ 'iterations.0': { $exists: true } });

for (const checklist of checklists) {
    for (const iteration of checklist.iterations) {
        // Check each image reference
        for (const group of iteration.groups) {
            for (const question of group.questions) {
                // Verify executorImages
                question.executorImages = await filterExistingImages(question.executorImages);
                // Verify reviewerImages
                question.reviewerImages = await filterExistingImages(question.reviewerImages);
            }
        }
    }
    await checklist.save();
}
```

---

## Status
✅ **Backend:** Fixed - Server returns 404 for missing files
✅ **Frontend:** Enhanced - Shows user-friendly placeholders
✅ **Testing:** Ready - Restart your app and test

**Last Updated:** February 5, 2026
