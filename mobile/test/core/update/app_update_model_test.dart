import 'package:corehives/core/update/app_update_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReleaseTagVersion', () {
    test('parses Flutter version tags without v prefix', () {
      final parsed = ReleaseTagVersion.parse('0.4.0+5');

      expect(parsed.versionName, '0.4.0');
      expect(parsed.buildNumber, 5);
    });

    test('parses Flutter version tags with v prefix', () {
      final parsed = ReleaseTagVersion.parse('v0.4.0+5');

      expect(parsed.versionName, '0.4.0');
      expect(parsed.buildNumber, 5);
    });
  });

  test('detects newer APK build with same versionName', () {
    const update = AppUpdateModel(
      currentVersion: '0.4.0',
      currentBuildNumber: 4,
      latestVersion: '0.4.0',
      latestBuildNumber: 5,
      minimumBuildNumber: 0,
      forceUpdate: false,
      apkUrl:
          'https://github.com/waleed52531/corehives/releases/download/0.4.0%2B5/app-release.apk',
      releaseNotes: '',
      releaseUrl:
          'https://github.com/waleed52531/corehives/releases/tag/0.4.0%2B5',
      assetName: 'app-release.apk',
    );

    expect(update.isUpdateAvailable, isTrue);
    expect(update.status, UpdateStatus.optional);
  });
}
