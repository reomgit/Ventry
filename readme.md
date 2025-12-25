# Ventry

Ventry is a macOS SwiftUI app that organizes creative assets by application, with a sidebar of curated sections and a grid view of app folders.

## Status
- Prototype UI scaffolding with placeholder actions and sample data.

## Features
- Sidebar sections for Favorites, Presets, and User Library.
- Detected Applications list with per-app folder grids.
- Finder entry point placeholder for future file browsing logic.

## Requirements
- macOS 15.5 (deployment target).
- Xcode with the macOS 15.5 SDK.

## Run
1. Open `Ventry.xcodeproj` in Xcode.
2. Select the `Ventry` scheme.
3. Run the app.

## Tests
- Unit tests live in `VentryTests`.
- UI tests live in `VentryUITests`.

## Project Layout
- `Ventry/ContentView.swift`: Primary UI layout and interactions.
- `Ventry/VentryApp.swift`: App entry point.
- `Ventry/Assets.xcassets`: App icons and colors.
- `VentryTests/`: Unit tests.
- `VentryUITests/`: UI tests.

## Security and Privacy
- App Sandbox enabled.
- User-selected files read-only entitlement enabled.

## License
See `LICENSE`.