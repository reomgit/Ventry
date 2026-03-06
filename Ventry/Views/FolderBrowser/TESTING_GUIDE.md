# Folder Browser Testing Guide

This guide provides comprehensive testing scenarios for the FolderBrowserView component.

## Prerequisites

Before testing, ensure:
- Ventry has been granted permission to access test directories
- You have sample directories with various file types
- macOS 15.5+ is installed

## Test Scenarios

### 1. Basic Navigation

#### Test 1.1: Initial Load
**Steps:**
1. Open FolderBrowserView with valid directory path
2. Verify directory contents load within 1 second
3. Check that files and folders are displayed

**Expected Result:**
- Directory loads successfully
- Files and folders appear sorted (folders first, then alphabetical)
- No error messages

#### Test 1.2: Back/Forward Navigation
**Steps:**
1. Navigate into a subfolder (double-click or press Return)
2. Click Back button
3. Click Forward button
4. Repeat with multiple folders

**Expected Result:**
- Back button navigates to previous directory
- Forward button re-enters subfolder
- Buttons are disabled when at history bounds
- Breadcrumb updates correctly

#### Test 1.3: Breadcrumb Navigation
**Steps:**
1. Navigate deep into nested folders (3+ levels)
2. Click a breadcrumb component in the middle of the path
3. Verify navigation jumps to that level

**Expected Result:**
- Clicking breadcrumb navigates to correct directory
- Forward history is cleared
- Current location highlighted in breadcrumb

#### Test 1.4: Up Navigation
**Steps:**
1. Navigate into a subfolder
2. Click Up button (chevron.up icon)
3. Verify parent directory loads

**Expected Result:**
- Navigates to parent directory
- Back button remains functional
- Breadcrumb updates

### 2. View Modes

#### Test 2.1: Grid View
**Steps:**
1. Ensure Grid view is selected
2. Verify large icons with file names
3. Verify icons match Finder for known files/apps/folders
4. Verify creative file badges appear for types like PSD/AI/AEP in Grid view

**Expected Result:**
- Icons are 40pt size
- File names appear below icons
- Icons match native macOS/Finder icon style
- Creative badges are subtle and render only in Grid view
- Grid adapts to window size

#### Test 2.2: List View
**Steps:**
1. Switch to List view
2. Verify columns: Name, Size, Modification Date
3. Check alternating row backgrounds
4. Verify no creative badges are rendered in List view

**Expected Result:**
- Three columns visible
- File sizes formatted (KB, MB, GB)
- Dates formatted as "Month DD, YYYY at HH:MM"
- Rows alternate background color
- Finder-native icons are shown without badges

#### Test 2.3: Column View
**Steps:**
1. Switch to Column view
2. Verify compact layout with metadata
3. Check multi-column grid
4. Verify no creative badges are rendered in Column view

**Expected Result:**
- 4 columns of items
- Name + size/date metadata visible
- Compact spacing
- Finder-native icons are shown without badges

#### Test 2.4: View Mode Persistence
**Steps:**
1. Select List view
2. Quit and restart application
3. Open folder browser again

**Expected Result:**
- List view is still selected
- Preference persists via @AppStorage

### 3. File Selection

#### Test 3.1: Single Selection
**Steps:**
1. Click a file
2. Verify selection highlight
3. Click another file

**Expected Result:**
- First file shows selection (blue outline/background)
- Second click deselects first, selects second
- Only one item selected at a time

#### Test 3.2: Multi-Selection
**Steps:**
1. Click a file
2. Cmd+Click another file
3. Cmd+Click a third file
4. Cmd+Click second file again

**Expected Result:**
- First file selected
- Second file added to selection
- Third file added to selection
- Second file removed from selection (toggle)

#### Test 3.3: Select All
**Steps:**
1. Press Cmd+A
2. Verify all items selected
3. Click single item

**Expected Result:**
- All items show selection
- Selection count accurate
- Single click clears multi-selection

### 4. Quick Look Integration

#### Test 4.1: Spacebar Preview
**Steps:**
1. Select an image file
2. Press Spacebar
3. Verify Quick Look panel opens

**Expected Result:**
- QLPreviewPanel appears
- Image preview renders
- Panel is centered on screen

#### Test 4.2: Multiple File Preview
**Steps:**
1. Select 3 image files
2. Press Spacebar
3. Use arrow keys to navigate between previews

**Expected Result:**
- Quick Look shows first selected file
- Arrow keys cycle through selected files
- Preview updates smoothly

#### Test 4.3: Quick Look Close
**Steps:**
1. Open Quick Look (Spacebar)
2. Press Spacebar again
3. Verify panel closes

**Expected Result:**
- Panel closes on second Spacebar press
- Or ESC key closes panel
- Selection remains

### 5. File Operations

#### Test 5.1: Delete Single File
**Steps:**
1. Select a file
2. Press Delete key
3. Confirm in alert dialog

**Expected Result:**
- Alert appears with confirmation
- File moves to Trash
- Directory refreshes
- File no longer visible

#### Test 5.2: Delete Multiple Files
**Steps:**
1. Select 3 files (Cmd+Click)
2. Press Delete
3. Verify alert shows count
4. Confirm deletion

**Expected Result:**
- Alert says "3 items"
- All files move to Trash
- Directory refreshes

#### Test 5.3: Rename File
**Steps:**
1. Right-click a file
2. Select "Rename..."
3. Enter new name
4. Click Rename

**Expected Result:**
- Rename alert appears
- TextField pre-filled with current name
- File renamed successfully
- Directory refreshes with new name

#### Test 5.4: Duplicate File
**Steps:**
1. Right-click a file named "test.txt"
2. Select "Duplicate"
3. Verify new file appears

**Expected Result:**
- New file created: "test copy 1.txt"
- Duplicating again creates "test copy 2.txt"
- Directory refreshes

#### Test 5.5: Copy to Clipboard
**Steps:**
1. Select file(s)
2. Right-click → Copy
3. Open Finder
4. Cmd+V in another location

**Expected Result:**
- File(s) copied to pasteboard as URLs
- Finder can paste successfully

#### Test 5.6: Reveal in Finder
**Steps:**
1. Select a file
2. Right-click → Reveal in Finder

**Expected Result:**
- Finder opens
- File is selected in Finder window
- Finder window comes to front

#### Test 5.7: Undo/Redo Rename
**Steps:**
1. Rename a file from `test.txt` to `test-renamed.txt`
2. Press Cmd+Z
3. Press Shift+Cmd+Z

**Expected Result:**
- Cmd+Z restores original name
- Shift+Cmd+Z reapplies renamed state
- Folder refresh remains stable and no duplicate files appear

#### Test 5.8: Undo/Redo Batch Delete
**Steps:**
1. Select 3 files
2. Delete them via Delete key and confirm
3. Press Cmd+Z once
4. Press Shift+Cmd+Z once

**Expected Result:**
- One undo restores all 3 files together
- One redo moves all 3 files to Trash again
- No partial restore/delete occurs

#### Test 5.9: Undo/Redo Duplicate
**Steps:**
1. Duplicate a single file
2. Confirm duplicate appears
3. Press Cmd+Z
4. Press Shift+Cmd+Z

**Expected Result:**
- Undo removes only the created duplicate
- Redo restores that duplicate
- Original source file is unchanged

#### Test 5.10: Undo Conflict Safety
**Steps:**
1. Rename `example.txt` to `example-new.txt`
2. Manually create a new `example.txt` in the same folder
3. Press Cmd+Z

**Expected Result:**
- Undo fails with an error alert
- Existing `example.txt` is not overwritten
- `example-new.txt` remains in place

### 6. Sorting

#### Test 6.1: Sort by Name
**Steps:**
1. Click sort menu
2. Select "Name (A-Z)"
3. Verify alphabetical order
4. Select "Name (Z-A)"

**Expected Result:**
- Files sorted alphabetically (folders first)
- Reverse alphabetical when descending
- Sort persists when navigating

#### Test 6.2: Sort by Size
**Steps:**
1. Click sort menu
2. Select "Size (Smallest)"
3. Verify smallest files first
4. Switch to "Size (Largest)"

**Expected Result:**
- Files sorted by size
- Folders shown first (size N/A)
- Largest files appear first in descending

#### Test 6.3: Sort by Date
**Steps:**
1. Click sort menu
2. Select "Date (Oldest)"
3. Verify oldest modification dates first
4. Switch to "Date (Newest)"

**Expected Result:**
- Files sorted by modification date
- Newest files first in descending order

### 7. Context Menu

#### Test 7.1: File Context Menu
**Steps:**
1. Right-click a file
2. Verify menu items

**Expected Result:**
Menu contains:
- Open
- Quick Look
- Get Info
- Rename...
- Copy
- Duplicate
- Move to Trash
- Reveal in Finder
- Copy Path

#### Test 7.2: Folder Context Menu
**Steps:**
1. Right-click a folder
2. Verify menu items

**Expected Result:**
Menu contains:
- Open
- Get Info
- Rename...
- Copy
- Duplicate
- Move to Trash
- Reveal in Finder
(No "Quick Look" or "Copy Path" for folders)

#### Test 7.3: Multiple Selection Context Menu
**Steps:**
1. Select 3 files
2. Right-click

**Expected Result:**
Menu contains:
- Get Info
- Copy
- Duplicate
- Move to Trash
- Reveal in Finder
(No "Open", "Rename", or "Quick Look")

### 8. Keyboard Shortcuts

#### Test 8.1: Return Key
**Steps:**
1. Select a folder
2. Press Return

**Expected Result:**
- Folder opens
- Same as double-click

#### Test 8.2: Delete Key
**Steps:**
1. Select file(s)
2. Press Delete
3. Cancel alert

**Expected Result:**
- Delete confirmation appears
- Cancel preserves files

#### Test 8.3: Cmd+A
**Steps:**
1. Press Cmd+A in directory with 10 files

**Expected Result:**
- All 10 files selected

#### Test 8.4: Undo/Redo Shortcuts
**Steps:**
1. Perform a rename, duplicate, or delete
2. Press Cmd+Z
3. Press Shift+Cmd+Z

**Expected Result:**
- Undo executes for supported file mutation actions
- Redo restores the undone action
- No custom shortcut conflicts with existing navigation keys

### 9. Error Handling

#### Test 9.1: Invalid Path
**Steps:**
1. Open FolderBrowserView with path "/nonexistent/path"

**Expected Result:**
- Error message appears
- "The path could not be opened"
- Retry button available

#### Test 9.2: Permission Denied
**Steps:**
1. Navigate to protected system directory without permission

**Expected Result:**
- Error message appears
- Graceful degradation
- No crash

#### Test 9.3: Rename Conflict
**Steps:**
1. Try to rename file to existing name
2. Verify error

**Expected Result:**
- Alert: "An item with the name 'X' already exists"
- Rename cancelled
- Original name preserved

### 10. Performance

#### Test 10.1: Large Directory
**Steps:**
1. Open directory with 1,000+ files
2. Measure load time
3. Scroll through list

**Expected Result:**
- Loads within 2 seconds
- Smooth scrolling (60fps)
- No lag or stuttering

#### Test 10.2: Rapid Navigation
**Steps:**
1. Navigate into subfolder
2. Immediately click Back
3. Immediately click Forward
4. Repeat 5 times rapidly

**Expected Result:**
- No crashes
- Debouncing prevents excessive loads
- Final state correct

#### Test 10.3: Memory Usage
**Steps:**
1. Navigate through 10 different directories
2. Monitor memory in Activity Monitor

**Expected Result:**
- Memory usage stays reasonable (<50MB increase)
- No memory leaks
- Previous directory data released

### 11. Visual/UI

#### Test 11.1: Dark Mode
**Steps:**
1. Switch macOS to Dark Mode
2. Verify all UI elements

**Expected Result:**
- Toolbar background adapts
- File icons visible
- Selection highlights visible
- Text readable

#### Test 11.2: Light Mode
**Steps:**
1. Switch macOS to Light Mode
2. Verify all UI elements

**Expected Result:**
- Same as dark mode expectations
- Proper contrast
- No white-on-white issues

#### Test 11.3: Window Resize
**Steps:**
1. Resize window to minimum width
2. Resize to maximum width
3. Check grid adapts

**Expected Result:**
- Grid columns adjust to window size
- No horizontal scrolling in List view
- Breadcrumbs scroll if needed

### 12. Edge Cases

#### Test 12.1: Empty Directory
**Steps:**
1. Create empty folder
2. Open in browser

**Expected Result:**
- Empty state appears
- "This folder is empty" message
- No errors

#### Test 12.2: Single File
**Steps:**
1. Open directory with only one file

**Expected Result:**
- File displays normally
- Selection works
- All operations available

#### Test 12.3: Long File Names
**Steps:**
1. Create file with 100+ character name
2. View in browser

**Expected Result:**
- Name truncates with ellipsis
- Full name visible on hover
- Grid view handles gracefully

#### Test 12.4: Special Characters
**Steps:**
1. Create files with names: "test@file.txt", "test#file.txt", "test file.txt"
2. Verify display and operations

**Expected Result:**
- All characters display correctly
- Rename, copy, delete work
- No encoding issues

## Regression Testing

After any changes, run this quick regression test:

1. Open Downloads folder ✓
2. Switch to List view ✓
3. Select 2 files ✓
4. Press Spacebar (Quick Look) ✓
5. Close Quick Look ✓
6. Navigate into subfolder ✓
7. Click Back button ✓
8. Right-click → Reveal in Finder ✓
9. Delete 1 file (confirm) ✓
10. Rename 1 file ✓
11. Cmd+Z undo rename/delete ✓
12. Shift+Cmd+Z redo rename/delete ✓

All should work without errors.

## Bug Reporting

If you find issues, report with:
- macOS version
- Steps to reproduce
- Expected vs actual behavior
- Console error messages
- Screenshots if visual issue

## Automated Testing

Future: Consider adding unit tests for:
- `FolderBrowserViewModel` navigation logic
- `FolderBrowserItem` initialization
- Sorting algorithms
- File operation error handling
