# Folder Browser Implementation Guide

## Overview

A complete, native macOS folder browsing component has been implemented for Ventry. This provides a Finder-like interface for managing files in application directories, collections, and custom paths.

## Implementation Summary

### Files Created

#### Models
- `/Ventry/Models/FolderBrowserItem.swift` - Enhanced file metadata model with creative file type support

#### ViewModels
- `/Ventry/ViewModels/FolderBrowserViewModel.swift` - Centralized state management with navigation history

#### Views
- `/Ventry/Views/FolderBrowser/FolderBrowserView.swift` - Main browser container
- `/Ventry/Views/FolderBrowser/FolderBrowserGridView.swift` - Grid layout view mode
- `/Ventry/Views/FolderBrowser/FolderBrowserListView.swift` - List layout view mode
- `/Ventry/Views/FolderBrowser/FolderBrowserColumnView.swift` - Column layout view mode
- `/Ventry/Views/FolderBrowser/FolderBrowserToolbar.swift` - Navigation and view controls
- `/Ventry/Views/FolderBrowser/QuickLookPreview.swift` - Native Quick Look integration

#### Compatibility
- `/Ventry/Views/FileBrowserView.swift` - Wrapper for backward compatibility
- `/Ventry/Views/FileBrowserView_old.swift` - Original implementation (backup)

## Key Features

### 1. Multiple View Modes
- **Grid View**: Large icons with file names (Finder icon view style)
- **List View**: Detailed table with size, modification date
- **Column View**: Compact multi-column layout

View mode persists across app launches using `@AppStorage`.

### 2. Navigation System
- **Back/Forward buttons**: Full history navigation
- **Up button**: Navigate to parent directory
- **Breadcrumb trail**: Click-to-navigate path components
- **History stack**: Maintains browsing session history

### 3. Quick Look Integration
- Press **Spacebar** to preview selected files
- Uses native `QLPreviewPanel` via AppKit integration
- Supports all file types that macOS Quick Look supports

### 4. File Operations
All operations respect App Sandbox constraints:
- **Open**: Double-click or Return key
- **Delete**: Move to Trash with confirmation
- **Rename**: Single-item rename with duplicate name checking
- **Duplicate**: Automatic copy naming (file copy 1, copy 2, etc.)
- **Copy**: Copy file URLs to pasteboard
- **Reveal in Finder**: Open containing folder
- **Get Info**: macOS native info window

### 5. Sorting Options
- Name (A-Z / Z-A)
- Size (Smallest / Largest)
- Date (Oldest / Newest)

Folders always appear before files.

### 6. Keyboard Shortcuts
- **Space**: Quick Look preview
- **Return**: Open selected item
- **Delete**: Move to Trash
- **Cmd+A**: Select all
- **Cmd+Click**: Multi-select toggle

### 7. Creative File Type Support
Custom icons and colors for:
- Adobe: .psd, .psb, .ai, .eps, .aep, .prproj
- Sketch, Figma, XD
- 3D: .c4d, .blend, .ma, .mb, .fbx, .obj
- Fonts: .ttf, .otf, .woff, .woff2
- Video editing: .fcpx, .fcp

## Integration with Existing Codebase

### Using the Folder Browser

#### Option 1: Direct Usage
```swift
import SwiftUI

FolderBrowserView(
    title: "My Plugins",
    path: "/Applications/Adobe After Effects 2025/Plug-ins"
)
```

#### Option 2: Via FileBrowserView (Backward Compatible)
```swift
// Existing code continues to work
FileBrowserView(
    title: directory.name,
    path: directory.path
)
```

### Integration Points

#### With AppState
The browser can be enhanced to integrate with AppState for:
- Storing navigation history across sessions
- Tracking selected assets
- Syncing with application directories

Example enhancement:
```swift
// In FolderBrowserView
@EnvironmentObject var appState: AppState

// Update AppState when selection changes
.onChange(of: viewModel.selectedItems) { items in
    // Convert to Asset models and update AppState
}
```

#### With DirectoryScanner
The existing `DirectoryScanner` is complementary:
- DirectoryScanner: Recursive scanning for asset collections
- FolderBrowser: Interactive browsing of single directory

They can work together:
```swift
// User browses with FolderBrowser
// Then scans selected directory with DirectoryScanner
Button("Scan This Folder") {
    if let currentDir = viewModel.currentDirectory {
        DirectoryScanner.shared.scanForAssets(at: currentDir.path)
    }
}
```

#### With Application Directories
Perfect for browsing `AppDirectory` paths:
```swift
// In ApplicationDirectoryView or similar
NavigationLink(destination: FolderBrowserView(
    title: directory.name,
    path: directory.path
)) {
    DirectoryCard(directory: directory)
}
```

## Architecture Details

### State Management Pattern
The implementation follows Ventry's centralized state pattern:

```
FolderBrowserView (View)
    ├── FolderBrowserViewModel (@StateObject)
    │   ├── @Published items
    │   ├── @Published selectedItems
    │   ├── @Published navigationHistory
    │   └── File operations
    ├── View Mode (@AppStorage)
    └── Subviews (Grid/List/Column)
```

### Performance Optimizations
1. **Lazy Loading**: Uses `LazyVGrid` and `LazyVStack` for thousands of items
2. **Debouncing**: 100ms delay on directory loading to prevent rapid navigation issues
3. **Task Cancellation**: Previous loads cancelled when navigating
4. **Efficient Sorting**: Directory sorting happens once on load

### Sandbox Safety
All operations verify file existence and handle errors:
```swift
guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
      isDirectory.boolValue else {
    // Show error, don't crash
    return
}
```

## Testing Checklist

### Basic Functionality
- [ ] Navigate to a directory with files
- [ ] Switch between Grid, List, Column views
- [ ] Select single file and press Spacebar (Quick Look)
- [ ] Double-click folder to navigate
- [ ] Use Back/Forward buttons
- [ ] Click breadcrumb components

### File Operations
- [ ] Right-click file → Reveal in Finder
- [ ] Right-click file → Copy Path
- [ ] Right-click file → Duplicate
- [ ] Right-click file → Rename
- [ ] Select file → Press Delete → Confirm
- [ ] Select multiple files (Cmd+Click)

### Edge Cases
- [ ] Navigate to empty folder
- [ ] Navigate to folder without permission (error handling)
- [ ] Navigate to directory with 1000+ files (performance)
- [ ] Switch view modes rapidly
- [ ] Navigate back/forward rapidly

### Visual
- [ ] Dark mode appearance
- [ ] Icon colors for different file types
- [ ] Loading state during directory scan
- [ ] Error state for invalid paths
- [ ] Empty state for empty directories

## Known Limitations

1. **Thumbnails**: Currently uses SF Symbols icons, not actual file thumbnails
   - Future: Integrate `NSWorkspace.icon(forFile:)` or QuickLook thumbnail generation

2. **Selection**: Multi-select works with Cmd+Click but not Shift+Click
   - Future: Implement range selection with Shift

3. **Drag & Drop**: Not implemented yet
   - Future: Add drag-to-move and drop-to-copy support

4. **Search**: No in-folder search
   - Future: Add search bar to toolbar

5. **Hidden Files**: Currently hidden, no toggle
   - Future: Add "Show Hidden Files" option (already in ViewModel, needs UI)

## Future Enhancements

### Short Term
- [ ] Thumbnail generation for images/videos using QuickLook
- [ ] Show hidden files toggle in toolbar
- [ ] Shift+Click range selection
- [ ] File size/type filtering

### Medium Term
- [ ] Drag-and-drop file operations
- [ ] Search within directory
- [ ] Custom file type icons using NSWorkspace
- [ ] Tag support (read/write macOS tags)
- [ ] Recent folders menu

### Long Term
- [ ] Tabbed browsing for multiple directories
- [ ] Column view with preview pane (Miller columns)
- [ ] File preview generation cache
- [ ] Real-time folder change monitoring (FSEvents)
- [ ] Smart folders (saved searches)

## Migration Guide

### For Existing FileBrowserView Users
No changes required! The old `FileBrowserView` API is preserved:
```swift
FileBrowserView(title: "...", path: "...")
```

This now internally uses the new `FolderBrowserView`.

### To Access New Features
Use `FolderBrowserView` directly:
```swift
FolderBrowserView(title: "...", path: "...")
```

Then add custom integrations:
```swift
FolderBrowserView(title: "...", path: "...")
    .onAppear {
        // Custom setup
    }
    .onChange(of: viewModel.selectedItems) { items in
        // React to selection changes
    }
```

## Troubleshooting

### Quick Look Not Working
- Ensure file URL is accessible (sandbox permissions)
- Check that file type supports Quick Look
- Verify QLPreviewPanel is available (macOS 10.6+)

### Navigation History Not Working
- Check that `navigationHistory` array is populated
- Verify `currentHistoryIndex` is within bounds
- Look for console errors during navigation

### Performance Issues
- Check directory size (10,000+ files may be slow)
- Verify lazy loading is working (scroll should be smooth)
- Look for excessive re-renders in view updates

### Context Menu Not Appearing
- Ensure items are selected
- Check SwiftUI version (contextMenu requires macOS 11+)
- Verify right-click events are captured

## Support

For issues or questions:
1. Check console logs for error messages
2. Verify file paths exist and have proper permissions
3. Test with a simple directory first
4. Review the implementation in `FolderBrowserView.swift`

## Credits

Implementation follows macOS Human Interface Guidelines and Finder UX patterns.
Built with SwiftUI and AppKit integration for native macOS experience.
