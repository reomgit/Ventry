# Bug Fixes & Improvements Plan

## 1. UI Hitboxes & Interactions
- **Problem:** Buttons and sidebar rows (Collections, Starred, Folders, Apps, Tags) have dead zones; only text/icons are clickable.
- **Fix:** Add `.contentShape(Rectangle())` to the root `HStack` of all `*RowView` components in `Ventry/Views/SidebarView.swift`.
- **Also:** Apply the same fix to toolbar buttons in `Ventry/Views/FolderBrowser/FolderBrowserToolbar.swift`.

## 2. Navigation Logic
- **Problem:** Switching between Collections in the sidebar doesn't update `FolderBrowserView` content.
- **Fix:** In `Ventry/Views/FolderBrowser/FolderBrowserView.swift`, add `.onChange(of: path)` to trigger `viewModel.navigateTo(url: ...)` so the view updates when the navigation link changes the path parameter.

## 3. Application Management
- **Problem:** Added apps appear in the "Add App" list again; manual addition permits duplicates without warning.
- **Fix:**
  - **Auto-Discovery:** In `Ventry/Views/ApplicationInstallationFlowView.swift`, filter `detectedApps` in the init or body to exclude those already present in `AppState.applications` (by `bundleIdentifier`).
  - **Manual Add:** In `Ventry/Views/IndividualAppInstallationView.swift`, specifically for the "Unsupported App" flow (manual path addition), add a check before confirming: if the app ID exists in `AppState`, show an alert "Application already added".

## 4. Context Menus & Icons
- **Problem:**
  - Context menus missing on Grid/Stack views.
  - Context menus lack icons.
- **Fix:**
  - **Icons:** In `Ventry/Views/FolderBrowser/FolderBrowserView.swift` inside `contextMenuContent(for:)`, replace `Button("Title")` with `Button(action: {}) { Label("Title", systemImage: "icon.name") }`.
  - **Grid Support:** Verify `FolderBrowserGridView.swift` is correctly receiving the `contextMenuBuilder`. (It appears to be generic; ensure `FolderBrowserView` passes the builder correctly).

## 5. Quick Look & Spacebar
- **Problem:**
  - Spacebar doesn't trigger Quick Look.
  - Quick Look fails in Grid/Stack views.
- **Fix:**
  - **Native QL:** Implement `QLPreviewPanel` support via a `NSViewController` representable or coordinator if possible.
  - **Spacebar:** Add a hidden button with `.keyboardShortcut(.space, modifiers: [])` in `FolderBrowserView` to toggle the preview state.
  - **Grid/Stack:** Ensure the Quick Look trigger (spacebar or menu) works regardless of the active view mode (Grid/List/Column).

## 6. Get Info
- **Problem:** "Get Info" should open Finder's property window.
- **Fix:**
  - Use `NSWorkspace.shared.activateFileViewerSelecting([url])` to reveal the file in Finder, which allows the user to press Cmd+I.
  - *Alternative:* Use AppleScript to tell Finder to open the info window: `tell application "Finder" to open information window of item (POSIX file "...")`. This is the most direct "Open Get Info" solution, provided the Sandbox allows AppleScript (user selected files entitlement + apple events entitlement).
  - *Fallback:* If AppleScript is blocked, "Reveal in Finder" is the standard behavior.

## 7. Documents Folder & "Design Assets"
- **Problem:** "Design Assets" folder isn't created; Ventry lacks permissions for `~/Documents`.
- **Fix:**
  - **Permissions:** In `Ventry/Managers/PermissionManager.swift`, add `requestDocumentsAccess()`.
  - **Setup Flow:** Update `Ventry/Views/WelcomeView.swift` to:
    1. Request `/Applications` access (existing).
    2. Request `~/Documents` access.
    3. Once granted, create `~/Documents/Ventry/Design Assets`.
  - **Path Resolution:** Fix the warning "homeDirectoryForCurrentUser returned container path" by ensuring we use the security-scoped URL from the `NSOpenPanel` result (which is the real user path) rather than relying on `FileManager.default.homeDirectoryForCurrentUser` which points to the sandbox container. Store the resolved bookmark for Documents just like Applications.

