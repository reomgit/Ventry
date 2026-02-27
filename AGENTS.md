# Repository Guidelines

## Project Structure & Module Organization
Core app code lives in `Ventry/`:
- `Views/`: SwiftUI screens and Folder Browser UI (`FolderBrowser/` submodule).
- `ViewModels/`: UI state and interaction logic.
- `Models/`: app/domain models (`AppState`, `Application`, collections).
- `Managers/` and `Scanners/`: permission handling, app discovery, directory scanning.
- `Configuration/SupportedApplications.json`: supported app/path definitions.
- `Assets.xcassets` and `Assets/branding/`: icons and branding assets.

Planning and implementation notes are in `Planning/`. Xcode project files are in `Ventry.xcodeproj/`.

## Build, Test, and Development Commands
- `open Ventry.xcodeproj`  
  Open the project in Xcode and run scheme `Ventry`.
- `xcodebuild -project Ventry.xcodeproj -scheme Ventry -configuration Debug build`  
  CLI debug build.
- `xcodebuild -project Ventry.xcodeproj -scheme Ventry -configuration Debug analyze`  
  Static analysis pass.
- `xcodebuild -project Ventry.xcodeproj -scheme Ventry test`  
  Test action entry point (add test bundles/targets as tests are introduced).

## Coding Style & Naming Conventions
- Language/framework: Swift + SwiftUI (AppKit interop when needed).
- Use 4-space indentation and keep view logic readable with minimal nesting.
- Naming:
  - Types/protocols: `UpperCamelCase`
  - Variables/functions/properties: `lowerCamelCase`
  - SwiftUI view files end with `*View.swift`; managers end with `*Manager.swift`.
- Prefer small, composable views and keep file operations sandbox-safe.

## Testing Guidelines
Automated test targets are not currently present in this repo. For behavior validation, use:
- `Ventry/Views/FolderBrowser/TESTING_GUIDE.md` for manual regression scenarios.
- Focus checks on navigation, selection, Quick Look, rename/delete flows, and permission handling.

When adding automated tests, mirror production naming (e.g., `FolderBrowserViewModelTests`) and keep tests deterministic.

## Commit & Pull Request Guidelines
Recent commits use short, imperative subjects (for example: `Fix ...`, `Add ...`, `feat: ...`).
- Keep subject lines concise; optionally use `feat:`, `fix:`, `refactor:`.
- One logical change per commit.

PRs should include:
- What changed and why.
- Risk/impact areas (permissions, scanning, file operations).
- Screenshots or short recordings for UI changes.
- Manual test evidence (scenarios run from `TESTING_GUIDE.md`).

## Security & Configuration Notes
This macOS app is sandboxed and depends on user-granted file access. Do not hardcode machine-specific absolute paths; route file access through existing permission/scanning flows.
