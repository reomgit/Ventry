# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Codebase Analysis (CRITICAL)

**You MUST use `@.claude/agents/gemini-analyzer.md` for ANY AND EVERY kind of codebase analysis.** Do not analyze manually; delegate to Gemini CLI via the agent. (This include simple project explorations)

## Project Overview

Ventry is a macOS SwiftUI application that helps designers and creators organize creative assets (fonts, icons, plugins, presets) stored locally. It provides a Finder-like interface for browsing and managing design resources across multiple applications.

**Technology Stack:**
- Swift/SwiftUI (AppKit integration acceptable)
- macOS 15.5+ deployment target
- App Sandbox enabled with user-selected files entitlement

## Build & Run

**Standard Workflow:**
```bash
# Build the project
xcodebuild -scheme Ventry -configuration Debug build

# Run the app (via Xcode)
# Open Ventry.xcodeproj in Xcode and run the Ventry scheme
```

**Testing:**
```bash
# Run all tests
xcodebuild -scheme Ventry test

# Unit tests are in VentryTests/
# UI tests are in VentryUITests/
```

## Architecture Overview

### State Management Pattern

The app uses a centralized `AppState` (@StateObject) injected via `.environmentObject()` from `VentryApp.swift:12`. All views access shared state through this object.

**Key responsibilities:**
- `AppState` (Models/AppState.swift): Central observable state managing collections, applications, and user data
- `ApplicationManager` (Models/ApplicationManager.swift): Handles application discovery, scanning logic, and multi-installation handling
- `AppLoader` (Scanners/AppLoader.swift): Recursively discovers .app bundles in /Applications before scanning

### Application Discovery Flow

1. **Pre-loading (on app launch)**: `AppState.loadApplicationsFromSystem()` discovers all .app files via `AppLoader.shared.loadAllApplications()`
2. **User-driven scanning**: User selects which loaded apps to scan for their directories
3. **Directory resolution**: `ApplicationManager` checks JSON config and resolves paths
4. **Multiple installations handling**: When multiple versions exist (e.g., After Effects 2025/2026), shows selection sheet via `MultipleInstallationsView`

### Supported Applications Configuration

Applications are defined in `Ventry/Configuration/SupportedApplications.json`:
```json
{
  "supportedApplications": {
    "com.adobe.AfterEffects": {
      "displayName": "Adobe After Effects",
      "appPaths": ["/Applications/Adobe After Effects 2025/..."],
      "paths": [
        {
          "name": "Plugins",
          "path": "/Applications/Adobe After Effects {year}/Plug-ins/",
          "type": "plugins",
          "icon": "puzzlepiece.extension"
        }
      ]
    }
  }
}
```

`ApplicationManager.loadSupportedApplications()` parses this at init time. Paths support `{year}` placeholder for version-aware applications.

### Key Data Models

**SidebarModels.swift** contains core domain types:
- `Application`: Represents a detected app with `bundleIdentifier`, `directories[]`, etc.
- `AppDirectory`: A scannable path (plugins, presets, etc.) with `DirectoryType` enum
- `StarredItem`, `UserTag`, `RegularFolder`: Sidebar organization structures

**AppState.swift** orchestrates:
- `@Published var loadedApps: [AppLoader.LoadedApp]`: All discovered apps before scanning
- `@Published var applications: [Application]`: Scanned apps with resolved directories
- `pendingInstallationSelection`: Drives multi-installation selection sheet

### Permission & Sandbox Handling

The app operates under macOS App Sandbox with **user-selected files** entitlement. File access requires explicit user permission via `NSOpenPanel` or Full Disk Access (future migration planned per instructions.md:49).

**Current implementation:**
- `PermissionManager.swift` handles folder access permissions
- Custom directory paths added via Finder selection dialogs

## Development Guidelines

**Code Style:**
- Clear naming with minimal nesting
- Protocol-based abstractions where appropriate
- Sandbox-safe file operations (always check FileManager existence)

**UI Conventions:**
- Minimal macOS-native design aesthetic
- NavigationSplitView layout (sidebar + detail)
- System SF Symbols for icons (see DirectoryType.systemImage, etc.)

**Issue Format (from instructions.md):**
When creating issues, use this structure:
```
# 🧩 Issue Title
### Context
(Brief background or current state)

### Problem
(Clear explanation of what's wrong or missing)

### Proposed Solution
(Detailed plan to fix or improve it)

### Notes
(Optional dependencies or hints)
```

## Common File Patterns

**Adding support for a new application:**
1. Add entry to `SupportedApplications.json` with bundle ID, display name, app paths, and directory definitions
2. `ApplicationManager` will auto-detect on next scan
3. Test with `AppLoader` to ensure .app is discovered correctly

**Scanning directories for assets:**
- `DirectoryScanner.scanForAssets(at:)` recursively walks paths
- Returns `[Asset]` typed by file extension (image, video, document, etc.)
- Asset type detection in `determineAssetType(for:)` checks UTType conformance

**Adding custom directories:**
- `AppState.addCustomDirectory(for:directory:)` updates both ApplicationManager and local applications array
- Custom paths stored per-application via `ApplicationManager.addCustomDirectory()`

## Future Architecture Notes

From instructions.md:
- Tabbed browsing for multiple app paths
- Full Disk Access migration (eliminate per-folder prompts)
- Real-time folder event listening for auto-refresh
- Application-specific metadata and previews
