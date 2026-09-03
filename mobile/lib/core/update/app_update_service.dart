import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'app_update_model.dart';
import 'update_config.dart';

class InstalledAppInfo {
  final String version;
  final int versionCode;

  const InstalledAppInfo({
    required this.version,
    required this.versionCode,
  });
}

class UpdateCheckResult {
  final UpdateStatus status;
  final InstalledAppInfo installedInfo;
  final AppUpdateModel? updateModel;
  final String? errorMessage;

  const UpdateCheckResult({
    required this.status,
    required this.installedInfo,
    this.updateModel,
    this.errorMessage,
  });

  bool get hasUpdate => status != UpdateStatus.none && updateModel != null;
  bool get isMandatory => status == UpdateStatus.mandatory;
  bool get isOptional => status == UpdateStatus.optional;
}

class _GitHubReleaseCandidate {
  final String version;
  final int buildNumber;
  final String tag;
  final String apkUrl;
  final String releaseNotes;
  final String releaseUrl;
  final String assetName;
  final DateTime? publishedAt;

  const _GitHubReleaseCandidate({
    required this.version,
    required this.buildNumber,
    required this.tag,
    required this.apkUrl,
    required this.releaseNotes,
    required this.releaseUrl,
    required this.assetName,
    required this.publishedAt,
  });
}

class AppUpdateService {
  final http.Client _client;
  String? _dismissedVersionInSession;

  AppUpdateService({http.Client? client}) : _client = client ?? http.Client();

  Future<InstalledAppInfo> getInstalledAppInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final versionCode = int.tryParse(info.buildNumber.trim()) ?? 1;
      return InstalledAppInfo(
        version: info.version.isNotEmpty ? info.version : '1.0.0',
        versionCode: versionCode,
      );
    } catch (e) {
      debugPrint('[UpdateService] Failed to read installed package info: $e');
      return const InstalledAppInfo(version: '1.0.0', versionCode: 1);
    }
  }

  Future<UpdateCheckResult> checkForUpdate(
      {bool ignoreSessionDismissal = false}) async {
    final installedInfo = await getInstalledAppInfo();

    debugPrint(
      '[UpdateService] Installed version: ${installedInfo.version}',
    );
    debugPrint('[UpdateService] Installed build: ${installedInfo.versionCode}');

    if (!Platform.isAndroid) {
      debugPrint('[UpdateService] APK update skipped: not Android.');
      return UpdateCheckResult(
        status: UpdateStatus.none,
        installedInfo: installedInfo,
      );
    }

    try {
      final release = await _fetchLatestValidRelease().timeout(
        const Duration(seconds: 7),
      );

      if (release == null) {
        debugPrint(
            '[UpdateService] No valid GitHub release with APK asset found.');
        return UpdateCheckResult(
          status: UpdateStatus.none,
          installedInfo: installedInfo,
        );
      }

      final policy = await _fetchUpdatePolicy().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint(
              '[UpdateService] update.json timed out; forced update disabled.');
          return const UpdatePolicy();
        },
      );

      final updateModel = AppUpdateModel(
        currentVersion: installedInfo.version,
        currentBuildNumber: installedInfo.versionCode,
        latestVersion: release.version,
        latestBuildNumber: release.buildNumber,
        minimumBuildNumber: policy.minimumBuildNumber,
        forceUpdate: policy.forceUpdate,
        apkUrl: release.apkUrl,
        releaseNotes: release.releaseNotes,
        releaseUrl: release.releaseUrl,
        assetName: release.assetName,
      );

      final status = updateModel.status;

      debugPrint('[UpdateService] GitHub tag: ${release.tag}');
      debugPrint(
          '[UpdateService] Latest version: ${updateModel.latestVersion}');
      debugPrint(
          '[UpdateService] Latest build: ${updateModel.latestBuildNumber}');
      debugPrint('[UpdateService] APK found: ${updateModel.apkUrl.isNotEmpty}');
      debugPrint(
          '[UpdateService] Update available: ${updateModel.isUpdateAvailable}');
      debugPrint('[UpdateService] Forced: ${updateModel.isForceUpdate}');
      debugPrint('[UpdateService] APK URL: ${updateModel.apkUrl}');

      if (status == UpdateStatus.optional &&
          !ignoreSessionDismissal &&
          _dismissedVersionInSession == updateModel.sessionKey) {
        debugPrint(
            '[UpdateService] Optional update already dismissed this session.');
        return UpdateCheckResult(
          status: UpdateStatus.none,
          installedInfo: installedInfo,
          updateModel: updateModel,
        );
      }

      return UpdateCheckResult(
        status: status,
        installedInfo: installedInfo,
        updateModel: updateModel,
      );
    } catch (e) {
      debugPrint('[UpdateService] Check failed; continuing startup: $e');
      return UpdateCheckResult(
        status: UpdateStatus.none,
        installedInfo: installedInfo,
        errorMessage: e.toString(),
      );
    }
  }

  Future<_GitHubReleaseCandidate?> _fetchLatestValidRelease() async {
    debugPrint(
        '[UpdateService] Checking GitHub latest release: ${UpdateConfig.latestReleaseUri}');

    final response = await _client.get(
      UpdateConfig.latestReleaseUri,
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'CoreHives-Android-Updater',
      },
    );

    debugPrint(
        '[UpdateService] GitHub latest release HTTP status: ${response.statusCode}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
          'GitHub latest release API returned HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
          'GitHub latest release response was not an object.');
    }

    if (decoded['draft'] == true) {
      debugPrint('[UpdateService] Latest GitHub release is a draft; ignoring.');
      return null;
    }

    final tag = (decoded['tag_name'] ?? '').toString().trim();
    if (tag.isEmpty) {
      debugPrint('[UpdateService] Latest GitHub release has no tag.');
      return null;
    }

    late final ReleaseTagVersion parsedTag;
    try {
      parsedTag = ReleaseTagVersion.parse(tag);
    } catch (e) {
      debugPrint(
          '[UpdateService] Latest GitHub release tag is invalid: $tag ($e)');
      return null;
    }

    final assets = decoded['assets'];
    if (assets is! List) {
      debugPrint('[UpdateService] Latest GitHub release assets are missing.');
      return null;
    }

    Map<String, dynamic>? apkAsset;
    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final name = (asset['name'] ?? '').toString();
      final downloadUrl = (asset['browser_download_url'] ?? '').toString();
      if (name.toLowerCase().endsWith('.apk') &&
          downloadUrl.startsWith('http')) {
        apkAsset = asset;
        break;
      }
    }

    debugPrint('[UpdateService] APK found: ${apkAsset != null}');

    if (apkAsset == null) return null;

    return _GitHubReleaseCandidate(
      version: parsedTag.versionName,
      buildNumber: parsedTag.buildNumber,
      tag: tag,
      apkUrl: apkAsset['browser_download_url'].toString(),
      releaseNotes: (decoded['body'] ?? '').toString(),
      releaseUrl: (decoded['html_url'] ?? '').toString(),
      assetName: (apkAsset['name'] ?? 'corehives-${parsedTag.versionName}.apk')
          .toString(),
      publishedAt:
          DateTime.tryParse((decoded['published_at'] ?? '').toString()),
    );
  }

  Future<UpdatePolicy> _fetchUpdatePolicy() async {
    try {
      debugPrint(
          '[UpdateService] Checking update policy: ${UpdateConfig.updatePolicyUri}');

      final response = await _client.get(
        UpdateConfig.updatePolicyUri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'CoreHives-Android-Updater',
        },
      );

      debugPrint(
          '[UpdateService] update.json HTTP status: ${response.statusCode}');

      if (response.statusCode == 404) {
        debugPrint(
            '[UpdateService] update.json not found; forced update disabled.');
        return const UpdatePolicy();
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
            '[UpdateService] update.json HTTP ${response.statusCode}; forced update disabled.');
        return const UpdatePolicy();
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        debugPrint(
            '[UpdateService] update.json malformed; forced update disabled.');
        return const UpdatePolicy();
      }

      return UpdatePolicy.fromMap(decoded);
    } catch (e) {
      debugPrint(
          '[UpdateService] update.json failed; forced update disabled: $e');
      return const UpdatePolicy();
    }
  }

  void dismissOptionalUpdateInSession(String updateSessionKey) {
    _dismissedVersionInSession = updateSessionKey;
  }
}

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  final service = AppUpdateService();
  ref.onDispose(service._client.close);
  return service;
});

final pendingOptionalUpdateProvider =
    StateProvider<UpdateCheckResult?>((ref) => null);

/// Holds the active mandatory update blocking state if the installed version is blocked.
final isMandatoryUpdateActiveProvider = StateProvider<bool>((ref) => false);

/// Tracks whether the startup splash update check has finished.
final isSplashCheckDoneProvider = StateProvider<bool>((ref) => false);
