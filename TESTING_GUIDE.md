# 🚀 Quick Testing Guide - Dynamic Stages System

## ✅ What Was Fixed

The system now properly **persists** dynamic stage fields to MongoDB. Previously, stages were reported as "added" but weren't actually saved to the database.

**What you can now do:**
- ✅ Add phases with custom names
- ✅ Names are persisted to MongoDB
- ✅ Retrieve phases and names correctly
- ✅ Delete phases completely
- ✅ No hardcoded stage1/stage2/stage3 limits

---

## 🎯 Testing Checklist

### Server Setup (Backend Running)

- [ ] Backend server is running: `npm run dev` in `lib/QRP-backend-main/`
- [ ] MongoDB is connected (should see "MongoDB connected!!" message)
- [ ] Server shows "Server is running at port: 8000"

### Step 1: Create a Project

1. Start the Flutter app
2. Go to Admin Dashboard
3. Create a new project (or use existing)
4. Note the project ID

### Step 2: Add a Phase

1. Navigate to **"Checklist Template Management"**
2. Click **"+ Add Phase"** button
3. A dialog appears asking for the phase name
4. Type: **"Kick-Off Review"** (or any custom name)
5. Click OK/Save
6. ✅ **Expected**: New tab appears with your custom name

### Step 3: Add Another Phase

1. Click **"+ Add Phase"** again
2. Type: **"Design & Planning"**
3. Click OK/Save
4. ✅ **Expected**: Another tab appears

### Step 4: Verify Persistence

1. Click the **Refresh (↻)** button in the header
2. ✅ **Expected**: Both phase tabs still there with custom names intact
3. If names are missing or tabs disappeared = **Persistence failed**

### Step 5: Add Content to Phase

1. Click on the **"Kick-Off Review"** tab
2. Click **"+ Add Checklist Group"**
3. Enter: **"Pre-Flight Checks"**
4. Click OK
5. ✅ **Expected**: Checklist group appears in the tab

### Step 6: Delete a Phase

1. Click the **three-dot menu (⋮)** next to a phase tab
2. Select **"Delete"**
3. Confirm the deletion
4. ✅ **Expected**: Phase tab disappears
5. Click Refresh to verify it's gone from database

### Step 7: Create Project with New Phases

1. Go to **Project Management**
2. Create a new project
3. ✅ **Expected**: Project shows the custom phases you created (not just "Phase 1, 2, 3")

---

## 🔍 Debugging Info

### If Phases Don't Appear After Refresh

**Check the backend logs:**
- Look for errors in the server terminal
- Should show: `✅ Stage [stageName] added successfully`

### If Custom Names Are Missing

**Check MongoDB directly:**
```bash
cd lib/QRP-backend-main
node check-template.js
```

Should show both `stage1`, `stage2`, etc. AND `stageNames` object with custom names.

### If Delete Doesn't Work

Check that backend shows:
```
🗑️ Deleting stage field from template: stage2
✅ Stage stage2 deleted successfully (modified: 1)
```

---

## 📊 Expected Behavior

| Action | Before Fix | After Fix |
|--------|-----------|-----------|
| Add phase | Reports success ✓ | Actually saves ✓ |
| Refresh page | Phases disappear ✗ | Phases persist ✓ |
| Check database | Stage field missing ✗ | Stage field exists ✓ |
| Custom names | Lost on refresh ✗ | Persisted correctly ✓ |
| Delete phase | Still appears ✗ | Actually deleted ✓ |

---

## 🛠️ Backend Verification

To manually verify the fix is working:

```bash
# Reset database (removes all templates)
node reset-template.js

# Test end-to-end stage operations
node test-e2e.js

# Test delete operations
node test-delete.js

# Check actual database document
node check-template.js
```

All tests should show **"SUCCESS"** with green checkmarks.

---

## 🎓 What Changed Technically

### Mongoose Issue (OLD - BROKEN)
```javascript
template[stage] = [];
template.markModified(stage);
await template.save();  // ❌ Mongoose doesn't persist new dynamic fields
```

### MongoDB Direct (NEW - WORKING)
```javascript
await Template.collection.updateOne(
  { _id: template._id },
  { $set: { [stage]: [], [`stageNames.${stage}`]: stageName } }
);  // ✅ MongoDB native driver works with dynamic fields
```

---

## 📝 Test Results Summary

Run `test-e2e.js` and you should see:

```
✅ Template created with ID: 6975c528f610b1f3a99e6c3d
✅ Added stage1 "Requirements & Planning" (modified: 1)
✅ Added stage2 "Design & Architecture" (modified: 1)
✅ Added stage3 "Development & Testing" (modified: 1)
✅ Fetched template
   Stages found: stage1, stage2, stage3
   Stage names: {"stage1":"Requirements & Planning", ...}
✅ stage1 "Requirements & Planning" - verified!
✅ stage2 "Design & Architecture" - verified!
✅ stage3 "Development & Testing" - verified!

🎉 SUCCESS! All stages persisted and retrieved correctly!
```

---

## ⚠️ Known Limitations

Currently:
- Phases appear in order created (no drag-to-reorder yet)
- Phase limit is stage1 through stage99 (99 phases max)
- Deleting a phase deletes all its data (no undo/recovery)

These are intentional design choices, not bugs.

---

## 🆘 If Something Goes Wrong

1. **Check backend logs** - Look for error messages in terminal
2. **Restart server** - Sometimes nodemon gets confused
3. **Clear database** - Run `reset-template.js`
4. **Check MongoDB connection** - Should see "MongoDB connected!!" message
5. **Verify Flutter auth** - Make sure you're logged in as admin

---

## ✨ Success Indicators

You'll know the fix is working when:

1. ✅ You can add a phase with a custom name
2. ✅ The name appears in the tab
3. ✅ Refreshing the page keeps the phase and name
4. ✅ You can add another phase
5. ✅ You can delete a phase
6. ✅ The deleted phase is gone after refresh
7. ✅ Creating projects shows your custom phases

**All of these working = SUCCESS!** 🎉

---

**Last Tested**: January 25, 2026  
**Status**: ✅ READY FOR USER TESTING
