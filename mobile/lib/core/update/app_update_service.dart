import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'app_update_model.dart';

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

class AppUpdateService {
  final FirebaseFirestore _db;
  int? _dismissedVersionCodeInSession;

  AppUpdateService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  /// Retrieves the installed app's semantic version and integer versionCode.
  Future<InstalledAppInfo> getInstalledAppInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final versionCode = int.tryParse(info.buildNumber.trim()) ?? 1;
      return InstalledAppInfo(
        version: info.version.isNotEmpty ? info.version : '1.0.0',
        versionCode: versionCode,
      );
    } catch (e) {
      if (kDebugMode) print('[AppUpdateService] Error getting PackageInfo: $e');
      return const InstalledAppInfo(version: '1.0.0', versionCode: 1);
    }
  }

  /// Fetches update configuration from Firestore document `app_config/android_update`.
  Future<AppUpdateModel?> fetchUpdateConfig() async {
    try {
      final doc = await _db
          .collection('app_config')
          .doc('android_update')
          .get()
          .timeout(const Duration(seconds: 4));

      if (!doc.exists || doc.data() == null) {
        if (kDebugMode) print('[AppUpdateService] app_config/android_update document not found.');
        return null;
      }

      return AppUpdateModel.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('[AppUpdateService] Error fetching update config: $e');
      }
      return null;
    }
  }

  /// Performs a complete update check.
  Future<UpdateCheckResult> checkForUpdate({bool ignoreSessionDismissal = false}) async {
    final installedInfo = await getInstalledAppInfo();

    // In-app APK updates are Android-only
    if (!Platform.isAndroid) {
      return UpdateCheckResult(
        status: UpdateStatus.none,
        installedInfo: installedInfo,
      );
    }

    try {
      final config = await fetchUpdateConfig();

      if (config == null) {
        return UpdateCheckResult(
          status: UpdateStatus.none,
          installedInfo: installedInfo,
        );
      }

      if (kDebugMode) {
        print('[AppUpdateService] Installed: ${installedInfo.version} (${installedInfo.versionCode})');
        print('[AppUpdateService] Latest: ${config.latestVersion} (${config.latestVersionCode}), Min: ${config.minimumVersionCode}, Force: ${config.forceUpdate}');
      }

      final status = config.getUpdateStatus(installedInfo.versionCode);

      // If user dismissed this optional update in this session and it's not forced
      if (status == UpdateStatus.optional &&
          !ignoreSessionDismissal &&
          _dismissedVersionCodeInSession == config.latestVersionCode) {
        return UpdateCheckResult(
          status: UpdateStatus.none,
          installedInfo: installedInfo,
          updateModel: config,
        );
      }

      return UpdateCheckResult(
        status: status,
        installedInfo: installedInfo,
        updateModel: config,
      );
    } catch (e) {
      if (kDebugMode) print('[AppUpdateService] Check failed: $e');
      return UpdateCheckResult(
        status: UpdateStatus.none,
        installedInfo: installedInfo,
        errorMessage: e.toString(),
      );
    }
  }

  /// Marks an optional update as dismissed for the remainder of this app session.
  void dismissOptionalUpdateInSession(int versionCode) {
    _dismissedVersionCodeInSession = versionCode;
  }
}

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService();
});

/// Holds the active mandatory update blocking state if the installed version is blocked.
final isMandatoryUpdateActiveProvider = StateProvider<bool>((ref) => false);

/// Tracks whether the startup splash update check has finished.
final isSplashCheckDoneProvider = StateProvider<bool>((ref) => false);
