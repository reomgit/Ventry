# Ventry

I built Ventry to solve a messy, real workflow problem: creative assets and application-specific resource folders are usually scattered across Finder, buried in app directories, and awkward to manage with a generic file browser. Ventry is a macOS app built with SwiftUI that gives those files a focused, native-feeling home by combining application discovery, supported-path scanning, permission-aware folder access, and a Finder-style interface for browsing and managing creative resources.

## What I Built

- Built a sandbox-aware macOS app that organizes creative assets and application resource folders in one place.
- Added application discovery that scans installed apps, detects supported bundles, and maps them to known resource directories through a JSON-driven configuration.
- Created a Finder-like folder browser with grid, list, and column views so users can navigate files in a way that feels native on macOS.
- Integrated Quick Look previews and native file icons to make browsing visual assets faster and more contextual.
- Implemented core file-management actions including rename, duplicate, delete, reveal in Finder, copy path, and undo/redo for folder browser mutations.
- Added permission-aware path validation and security-scoped access handling so the app works within macOS sandbox constraints instead of fighting them.
- Designed the app around creative workflows, including support for common design and 3D file types and application-specific directories such as supported Adobe After Effects and Blender paths.

## Tech Stack

- Swift
- SwiftUI
- AppKit interop for macOS-native behaviors
- Quick Look (`QLPreviewPanel`) integration
- macOS App Sandbox and security-scoped bookmark handling
- JSON-configured supported application and path resolution
- FileManager-based file operations and local directory scanning

## Engineering Focus

The hardest part of this project was not drawing a polished UI. It was making file management feel native while staying honest to macOS security rules. I had to handle sandbox and permission constraints, restore access to user-approved locations, map application-specific directories from configuration instead of hardcoding brittle paths, and build a SwiftUI-based browser that still behaves like a real macOS file tool. That meant balancing product clarity with platform realities: native navigation patterns, Quick Look, multiple view modes, and mutation flows all had to work without pretending the sandbox did not exist.

Ventry matters to me because it turns a fragmented Finder-based workflow into a purpose-built desktop tool for creative file organization.
