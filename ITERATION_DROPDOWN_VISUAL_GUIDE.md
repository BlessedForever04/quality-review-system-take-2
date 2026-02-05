# Visual Guide: Iteration Dropdown Feature

## What You'll See

### 1. Question with Iteration History

When a checklist has been reverted (creating iterations), each question will show a dropdown button:

```
┌──────────────────────────────────────────────────────────────┐
│  p1 question                           [Current (v3) ▼ 📖]   │  ← Green badge + dropdown
│                                                                │
│  ○ Yes                                                        │
│  ⦿ No   ← Currently selected                                 │
│                                                                │
│  Remark: [This is my current remark                        ] │
│                                                                │
│  📷  [Image thumbnails here if any]                          │
│                                                                │
│  Defect Category: [Critical ▼]          Severity: [High ▼]  │
└──────────────────────────────────────────────────────────────┘
```

### 2. Dropdown Menu Options

Click the dropdown to see all available iterations:

```
┌─────────────────────────┐
│ ● Current (v3)         │  ← Green dot = current/editable
│ 📖 Iteration 2         │  ← History icon = past iteration
│ 📖 Iteration 1         │  ← Oldest iteration
└─────────────────────────┘
```

### 3. Viewing Past Iteration (Read-Only Mode)

After selecting "Iteration 2":

```
┌──────────────────────────────────────────────────────────────┐
│  p1 question                           [Iteration 2 ▼ 📖]    │  ← Orange badge
│                                                                │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ ⓘ Viewing Iteration 2 (Read-only)                     │  │  ← Warning banner
│  └────────────────────────────────────────────────────────┘  │
│                                                                │
│  ⦿ Yes   ← Historical answer (disabled)                      │
│  ○ No                                                         │
│                                                                │
│  Remark: [This was my remark in iteration 2              ]   │  ← Disabled/grayed out
│                                                                │
│  📷  [Historical images from iteration 2]                    │
│                                                                │
│  Defect Category: [Minor ▼]             Severity: [Low ▼]   │  ← Disabled
└──────────────────────────────────────────────────────────────┘
```

### 4. Color Coding

**Current Iteration (Editable):**
- Background: Light green (#E8F5E9)
- Border: Green (#81C784)
- Icon: Green dot ●
- Status: All fields editable

**Past Iteration (Read-Only):**
- Background: Light orange (#FFF3E0)
- Border: Orange (#FFB74D)
- Icon: History 📖
- Status: All fields disabled
- Warning banner displayed

### 5. Question States Side-by-Side

You can view different iterations on different questions simultaneously:

```
┌──────────────────────────────────────────────────────────────┐
│  Question 1                            [Current (v3) ▼ 📖]   │  ← Green (current)
│  ⦿ Yes     Remark: [Latest answer here]                     │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│  Question 2                            [Iteration 2 ▼ 📖]    │  ← Orange (past)
│  ┌────────────────────────────────────────────────────────┐  │
│  │ ⓘ Viewing Iteration 2 (Read-only)                     │  │
│  └────────────────────────────────────────────────────────┘  │
│  ⦿ No      Remark: [Historical answer from iter 2]          │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│  Question 3                            [Iteration 1 ▼ 📖]    │  ← Orange (past)
│  ┌────────────────────────────────────────────────────────┐  │
│  │ ⓘ Viewing Iteration 1 (Read-only)                     │  │
│  └────────────────────────────────────────────────────────┘  │
│  ⦿ Yes     Remark: [Original answer from iter 1]            │
└──────────────────────────────────────────────────────────────┘
```

### 6. Executor vs Reviewer Views

**Same question, same iteration, different roles see different data:**

**Executor View (Iteration 1):**
```
┌──────────────────────────────────────────────────────────────┐
│  p1 question                           [Iteration 1 ▼ 📖]    │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ ⓘ Viewing Iteration 1 (Read-only)                     │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                                │
│  ⦿ Yes   ← Executor's answer                                 │
│  Remark: [Executor's remark here]                            │
│  📷 [Executor's images]                                      │
└──────────────────────────────────────────────────────────────┘
```

**Reviewer View (Iteration 1):**
```
┌──────────────────────────────────────────────────────────────┐
│  p1 question                           [Iteration 1 ▼ 📖]    │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ ⓘ Viewing Iteration 1 (Read-only)                     │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                                │
│  ⦿ No    ← Reviewer's answer                                 │
│  Remark: [Reviewer's remark here]                            │
│  📷 [Reviewer's images]                                      │
│  Defect Category: [Critical ▼]  Severity: [High ▼]          │
└──────────────────────────────────────────────────────────────┘
```

### 7. No Iterations Available

When a checklist has never been reverted:

```
┌──────────────────────────────────────────────────────────────┐
│  p1 question                                                  │  ← No dropdown button
│                                                                │
│  ⦿ Yes                                                        │
│  Remark: [Current answer]                                    │
└──────────────────────────────────────────────────────────────┘
```

## User Workflow

### Scenario: Reviewing Previous Work

1. **Open Checklist**
   - You see green dropdown badges on questions
   - This means iterations are available

2. **Click Dropdown on Question 1**
   - Dropdown opens showing "Current (v3)", "Iteration 2", "Iteration 1"

3. **Select "Iteration 1"**
   - Badge turns orange
   - Warning banner appears: "Viewing Iteration 1 (Read-only)"
   - Question shows your original answer from iteration 1
   - All fields are disabled (can't edit)

4. **Compare with Current**
   - Click dropdown again
   - Select "Current (v3)"
   - Badge turns green
   - Warning banner disappears
   - Shows your latest answer
   - All fields become editable again

5. **Check Another Question's History**
   - Each question has its own dropdown
   - You can view different iterations on different questions
   - Helps compare what changed across iterations

## Keyboard Navigation

- **Tab** - Move focus to dropdown button
- **Enter/Space** - Open dropdown menu
- **Arrow Up/Down** - Navigate menu items
- **Enter** - Select iteration
- **Escape** - Close dropdown

## Mobile/Tablet View

The dropdown button automatically adjusts for smaller screens:
- Button size remains touch-friendly
- Dropdown menu scrolls if many iterations
- Warning banner text wraps appropriately

## Tips for Best Experience

1. **Use iteration view to:**
   - See what changed since last review
   - Understand why reviewer reverted
   - Track your improvement over iterations

2. **Remember:**
   - Orange = viewing history (read-only)
   - Green = current work (editable)
   - Each question is independent

3. **Workflow suggestion:**
   - First, view current iteration (default)
   - If confused, check previous iteration
   - Compare answers to understand changes needed
   - Switch back to current to make edits

## Visual Indicators Summary

| Element | Current Iteration | Past Iteration |
|---------|------------------|----------------|
| Badge Color | 🟢 Green | 🟠 Orange |
| Icon | ● Green dot | 📖 History |
| Warning Banner | Hidden | Visible |
| Radio Buttons | Enabled | Disabled |
| Remark Field | Enabled | Disabled (grayed) |
| Image Picker | Enabled | Disabled |
| Dropdowns | Enabled | Disabled |
| Save Changes | ✅ Yes | ❌ No |

---

**This feature acts like a "time machine" for your checklist answers - you can peek into the past, but you can only edit the present! 🕐**
