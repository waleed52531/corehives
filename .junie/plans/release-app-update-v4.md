---
sessionId: session-260903-204432-1sib
---

# Requirements

### Overview & Goals
The goal is to provide a clear, step-by-step process to release version `0.4.0+4` of the CoreHives app so that all existing users receive an in-app update notification and can upgrade seamlessly.

### Scope
- **In Scope**: Building the release APK, uploading it to GitHub Releases, and updating the Firestore configuration to point to the GitHub download URL.
- **Out of Scope**: Setting up a new Google Play Store or Apple App Store listing (this project uses a custom in-app update mechanism).

### User Story
As a developer, I want to release the new version of the app with one command so that users are automatically prompted to update to the latest features and fixes.

# Technical Design

### Current Implementation
The app uses a custom update system defined in `mobile/lib/core/update/app_update_service.dart`. It checks a Firestore document `app_config/android_update` for the latest version and APK download URL.

### Key Decisions
- **Hosting**: Using **GitHub Releases** for APK hosting. This provides a free, high-bandwidth hosting solution for public releases without the daily download limits associated with Firebase Storage's free tier.
- **Update Mechanism**: Using the existing `update-app-config.js` script to update the Firestore `android_update` document with the GitHub download URL. This ensures users are notified of the new version and can download it directly from GitHub.

### Proposed Workflow
1.  **Build**: `flutter build apk --release`
2.  **Release**: Manually create a Release on GitHub and upload the APK.
3.  **Configure**: Run `node scripts/update-app-config.js set ...` with the GitHub APK URL.
    - This updates the Firestore `android_update` document which triggers the in-app update for users.

### File Changes
- `scripts/package.json`: Add a convenience script for updating the app configuration.

# Release Guide

### Step-by-step Release Guide

Follow these steps to push the version 4 update to your users:

#### 1. Build the Release APK
Open your terminal and run:
```bash
cd mobile
flutter build apk --release
```
*Note: This will use the version `0.4.0+4` we set in the previous task.*

#### 2. Create a GitHub Release
1. Go to your GitHub repository.
2. Create a new Release tagged `v0.4.0`.
3. Upload the APK file from `mobile/build/app/outputs/flutter-apk/app-release.apk`.
4. After publishing, right-click the uploaded APK in the release assets and **Copy link address**. It should look like: `https://github.com/user/repo/releases/download/v0.4.0/app-release.apk`.

#### 3. Notify Users (Update Firestore)
Navigate to the `scripts` directory and run the update script with your GitHub URL:
```bash
cd ../scripts

# Usage: node update-app-config.js set <version> <versionCode> <minVersionCode> <forceUpdate> <apkUrl> "Release Notes"

node update-app-config.js set 0.4.0 4 1 true "YOUR_GITHUB_LINK_HERE" "Added new features and bug fixes"
```
*Note: Replace `YOUR_GITHUB_LINK_HERE` with the link you copied in the previous step.*

### Important Note on App Signing
Your `build.gradle.kts` is currently configured to use the **debug** signing key for release builds. 
- **Constraint**: If you have already distributed the app to users with this debug key, you **must** continue using it for this update.
- **Warning**: If you change to a different signing key in the future, users will be unable to install the update over the old version and will have to uninstall/reinstall the app.

# Delivery Steps

### ✓ Step 1: Add update script to package.json
Add a command to the scripts manifest to simplify updating the Firestore configuration.

- Add `"update-config": "node update-app-config.js set"` to `scripts/package.json`.

### ✓ Step 2: Build the Release APK
Build the production-ready APK for Android.

- Run `flutter build apk --release` in the `mobile/` directory.
- Verify the APK is generated at `mobile/build/app/outputs/flutter-apk/app-release.apk`.

### ✓ Step 3: Upload to GitHub and Update Firestore
Host the APK on GitHub and notify the app of the new version.

- Create a GitHub Release and upload the APK.
- Copy the direct download link for the APK.
- Run `npm run update-config -- 0.4.0 4 1 true "<GITHUB_URL>" "Release notes"` (or the direct node command).
- Verify the `app_config/android_update` document in Firestore is updated with the new URL and version 4.

### * Step 4: Verify in-app update prompt
Verify that existing users receive the update notification.

- Open an older version of the app (e.g., v3).
- Check that the update dialog appears with the new release notes.
- Verify the "Update" button successfully downloads and prompts to install the new APK.