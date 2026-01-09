# Startup Menu & Permission Flow Plan

## Problem
Currently, when Ventry needs file access permissions, it immediately presents a mini Finder window (`NSOpenPanel`). This can be confusing and intrusive for users who may not understand why they are being asked to select a directory.

## Solution
Implement a "Welcome / Setup" flow that appears when the user opens Ventry for the first time (or when permissions are missing).

### User Experience
1. **Welcome Window:** A dedicated window or modal view appears on launch.
2. **Context:** The window explains *why* Ventry needs access (to scan applications and manage assets).
3. **Action:** A clear "Grant Access" button.
4. **Result:** Clicking the button triggers the necessary system permission requests (e.g., the `NSOpenPanel` to select the Applications folder or a prompt for Full Disk Access, depending on implementation strategy).

## Implementation Details

### 1. New Views
- Create `WelcomeView.swift`:
    - Title: "Welcome to Ventry"
    - Description: Explanation of features and required permissions.
    - Button: "Grant Access" (calls `PermissionManager`).

### 2. State Management
- Update `AppState.swift` or `VentryApp.swift` to check for:
    - First launch status (UserDefaults).
    - Current permission status (`PermissionManager.shared.hasDirectoryAccess`).
- If permissions are missing, show `WelcomeView` instead of `ContentView` (or overlay it).

### 3. PermissionManager Updates
- Ensure `requestDirectoryAccess` is called only when the user explicitly clicks the "Grant Access" button in the `WelcomeView`.
- Handle the success/failure state to transition the user to the main `ContentView` upon success.

### 4. Collections & Path Validation
- **Problem:** Collections paths fail to load, potentially due to alias issues or missing permissions.
- **Requirement:** Ventry MUST have permissions to default paths (like `/Applications` or paths used in Collections) to function.
- **Solution:**
    - Validate paths on startup.
    - If a required path is inaccessible:
        - Identify if it's due to missing permissions or a broken alias.
        - Prompt the user to re-grant access or fix the path.
    - Ensure `PermissionManager` checks cover these additional required paths, not just `/Applications`.

## Next Steps
1. Design and implement `WelcomeView` in SwiftUI.
2. Modify `VentryApp.swift` to handle the conditional routing (Welcome vs. Main App).
3. Test the flow to ensure the `NSOpenPanel` only appears after the user interaction.
