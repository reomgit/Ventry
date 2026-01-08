# Folder Browser Component

A comprehensive, native macOS folder browsing interface for Ventry that provides a Finder-like experience for managing creative assets.

## Architecture

### Core Components

#### Models
- **FolderBrowserItem.swift**: Rich file/folder metadata model with UTType detection, custom icons for creative file types (.psd, .ai, .aep, etc.), and formatted display strings

#### ViewModels
- **FolderBrowserViewModel.swift**: Centralized state management with:
  - Navigation history (back/forward)
  - Directory loading with debouncing
  - Selection management
  - Sorting options
  - File operations (delete, rename, reveal)

#### Views
- **FolderBrowserView.swift**: Main container view with toolbar, content switching, context menus, and keyboard shortcuts
- **FolderBrowserGridView.swift**: Grid layout with large icons (inspired by Finder icon view)
- **FolderBrowserListView.swift**: Detailed list with file size, dates, and columns
- **FolderBrowserColumnView.swift**: Compact multi-column layout
- **FolderBrowserToolbar.swift**: Navigation controls, breadcrumbs, view mode switcher, and sort menu
- **QuickLookPreview.swift**: Native Quick Look integration using QLPreviewPanel

## Features

### Navigation
- **Back/Forward buttons**: Full navigation history with index tracking
- **Up button**: Navigate to parent directory
- **Breadcrumb trail**: Click any path component to jump to that level
- **History stack**: Maintains browsing history with forward/back support

### View Modes
- **Grid View**: Large icons with file names (default)
- **List View**: Detailed table with size, modification date, alternating row backgrounds
- **Column View**: Compact multi-column layout with metadata
- Persistent view mode preference using @AppStorage

### File Operations
- **Quick Look**: Press spacebar to preview selected files
- **Open**: Double-click or press Return to open files/folders
- **Delete**: Move items to Trash (with confirmation alert)
- **Rename**: Rename single items with validation
- **Duplicate**: Create copies with automatic naming (item copy 1, item copy 2, etc.)
- **Copy**: Copy file URLs to pasteboard
- **Copy Path**: Copy file path as text
- **Reveal in Finder**: Open Finder at file location
- **Get Info**: Open Finder's Get Info window

### Context Menu
Right-click any item to access:
- Open
- Quick Look (files only)
- Get Info
- Rename (single item)
- Copy
- Duplicate
- Move to Trash
- Reveal in Finder
- Copy Path (single file)

### Keyboard Shortcuts
- **Space**: Quick Look preview
- **Return/Enter**: Open selected item
- **Delete/Backspace**: Move to Trash
- **Cmd+A**: Select all
- **Cmd+Click**: Toggle selection

### Performance Optimizations
- Lazy loading with LazyVGrid/LazyVStack
- 100ms debounce on directory navigation
- Efficient UTType-based file detection
- Cancellable async tasks

### UI/UX
- Clean, minimal macOS-native design
- Automatic Dark Mode support
- Smooth animations and transitions
- Loading states and error messages
- Empty state handling
- Icon colors for different file types

## Integration

### Usage Example

```swift
import SwiftUI

struct MyView: View {
    var body: some View {
        FolderBrowserView(
            title: "My Documents",
            path: "/Users/username/Documents"
        )
    }
}
```

### Compatibility

The old `FileBrowserView` has been preserved as `FileBrowserView_old.swift`. The current `FileBrowserView.swift` is a compatibility wrapper that redirects to `FolderBrowserView`.

To use the new implementation directly:
```swift
FolderBrowserView(title: "Plugins", path: directory.path)
```

To use the compatibility wrapper:
```swift
FileBrowserView(title: "Plugins", path: directory.path)
```

## File Type Support

### Creative Applications
- **Adobe**: .psd, .psb, .ai, .eps, .aep, .prproj
- **Sketch**: .sketch
- **Figma**: .fig, .figma
- **3D**: .c4d, .blend, .ma, .mb, .fbx, .obj
- **Video**: .fcpx, .fcp (Final Cut Pro)
- **Fonts**: .ttf, .otf, .woff, .woff2

### Standard Types
- Images: .jpg, .png, .gif, .svg, .webp, etc.
- Videos: .mov, .mp4, .avi, .mkv, .webm
- Audio: .mp3, .wav, .aiff, .flac, .ogg
- Documents: .pdf, .txt, .rtf
- Archives: .zip, .rar, .7z

## Sandbox Compatibility

All file operations respect macOS App Sandbox constraints:
- Uses `FileManager.default` for all operations
- Checks file existence before operations
- Handles permission errors gracefully
- Uses security-scoped URLs (inherited from parent directory access)

## Sort Options

- Name (A-Z)
- Name (Z-A)
- Size (Smallest first)
- Size (Largest first)
- Date (Oldest first)
- Date (Newest first)

Directories always appear before files regardless of sort order.

## Error Handling

- User-friendly error alerts for failed operations
- Console logging for debugging
- Graceful degradation (empty state instead of crashes)
- Specific error messages for different failure scenarios

## Future Enhancements

Potential improvements for future versions:
- Thumbnail generation for images/videos
- Drag-and-drop support for moving files
- Multi-selection with shift-click
- Custom file type icons using NSWorkspace
- File size filtering
- Search within directory
- Tag support
- Hidden files toggle
- Column view with preview pane (Miller columns)
- Tabbed browsing for multiple directories
- Recent folders history
- Favorites/bookmarks
