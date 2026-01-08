# 🧭 Ventry — Project Instructions

## Overview
Ventry is a macOS application that helps designers and creators organize and manage creative assets stored locally on their device. It works like a specialized file manager for design resources — fonts, icons, plugins, presets, and more — providing an intuitive way to browse, preview, and manage these assets.

## Features
- Manage and organize creative assets such as fonts, icons, and color palettes.
- Add and scan application paths to access plugins, presets, and effects.
- Browse and manage files and folders using a Finder-like interface.
- Tag and group assets into collections.
- Preview assets quickly inside the app.
- Integration with design software (planned).
- Automatic path handling and folder creation after permissions are granted.

## Implementation Guidelines
- **Language & Framework**: Swift / SwiftUI (AppKit integration acceptable).
- **UI Style**: Minimal macOS-native design.
- **Code Style**: Clear naming, minimal nesting, and protocol-based abstractions.
- **Behavior**: Ensure file management operations are sandbox-safe and respect macOS permissions.

## Development Workflow
### Issue Formatting (Linear)
Each issue should follow this format:
```
# 🧩 Issue Title
### Context
(Brief background or current state.)

### Problem
(Clear explanation of what’s wrong or missing.)

### Proposed Solution
(Detailed plan to fix or improve it.)

### Notes
(Optional notes, dependencies, or implementation hints.)
```

### Example
```
# 🔒 Switch to Full Disk Access for Folder Permissions
### Context
Ventry currently requests access for each folder.

### Problem
Repeated Finder selector panels slow down workflow.

### Proposed Solution
Use Full Disk Access instead. Remove per-folder prompts.

### Notes
Pairs with the Permission Detection Window feature.
```

## Future Plans (Just as a Reference)
- Tabbed browsing system for multiple app paths.
- Permission detection and full-disk access validation.
- Real-time folder event listening for auto-refresh.
- Application-specific metadata and previews.

I will tell you when a new issue has been created.