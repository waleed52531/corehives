# CoreHives APK Updates

CoreHives checks GitHub Releases for APK updates at app startup. The release repository is configured in:

`mobile/lib/core/update/update_config.dart`

Set `githubOwner` and `githubRepo` there if the release repository changes.

## Release Flow

1. Increase `version` in `mobile/pubspec.yaml`.
2. Commit and push the source code.
3. Build the APK:

   ```bash
   cd mobile
   flutter clean
   flutter pub get
   flutter build apk --release
   ```

4. Create a GitHub Release with a tag like `v1.0.1`.
5. Upload the APK asset to that release.

The app ignores draft releases, invalid semantic-version tags, and releases without a `.apk` asset.

## Forced Updates

Forced update policy is controlled by `update.json` at the repository root:

```json
{
  "minimumBuildNumber": 1,
  "forceUpdate": false
}
```

The app only blocks startup when it successfully reads this policy and conclusively determines that the installed build is below the supported build. If GitHub or `update.json` is unavailable, startup continues normally.

## Repository Privacy

Unauthenticated GitHub API and APK downloads require the release repository to be public. Do not embed a GitHub Personal Access Token in the APK. For a private repository, use a backend/proxy or another secure internal distribution mechanism.

## Signing

Android updates install over the existing app only when every APK uses the same `applicationId`, the same signing certificate, and a higher version code. The current release build is still signed with the debug signing config in `mobile/android/app/build.gradle.kts`; replace that with a stable private release keystore before relying on over-the-air updates across machines.
