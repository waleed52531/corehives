import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

enum InstallResultType {
  success,
  permissionDenied,
  fileNotFound,
  notAndroid,
  error,
}

class InstallResult {
  final InstallResultType type;
  final String? message;

  const InstallResult(this.type, [this.message]);

  bool get isSuccess => type == InstallResultType.success;
}

class ApkInstallerService {
  /// Checks if installing unknown apps is permitted on this device.
  Future<bool> hasInstallPermission() async {
    if (!Platform.isAndroid) return false;
    final status = await Permission.requestInstallPackages.status;
    return status.isGranted;
  }

  /// Requests the unknown app installation permission or opens system settings.
  Future<bool> requestInstallPermission() async {
    if (!Platform.isAndroid) return false;
    final status = await Permission.requestInstallPackages.request();
    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied || status.isDenied || status.isRestricted) {
      // Open settings page so user can toggle "Allow from this source"
      await openAppSettings();
    }
    return false;
  }

  /// Launches the Android Package Installer for the downloaded APK file.
  Future<InstallResult> installApk(File apkFile) async {
    if (!Platform.isAndroid) {
      return const InstallResult(InstallResultType.notAndroid, 'APK installation is only supported on Android.');
    }

    if (!await apkFile.exists()) {
      return const InstallResult(InstallResultType.fileNotFound, 'Downloaded APK file not found.');
    }

    try {
      // Check install unknown apps permission on Android 8.0+
      final hasPermission = await hasInstallPermission();
      if (!hasPermission) {
        final granted = await requestInstallPermission();
        if (!granted) {
          return const InstallResult(
            InstallResultType.permissionDenied,
            'Please allow CoreHives to install apps in system settings, then tap Install.',
          );
        }
      }

      if (kDebugMode) {
        print('[ApkInstallerService] Opening APK: ${apkFile.path}');
      }

      final result = await OpenFilex.open(
        apkFile.path,
        type: 'application/vnd.android.package-archive',
      );

      if (kDebugMode) {
        print('[ApkInstallerService] OpenFilex result: ${result.type} - ${result.message}');
      }

      if (result.type == ResultType.done) {
        return const InstallResult(InstallResultType.success);
      } else if (result.type == ResultType.permissionDenied) {
        return const InstallResult(
          InstallResultType.permissionDenied,
          'Permission to install unknown apps was denied.',
        );
      } else if (result.type == ResultType.fileNotFound) {
        return const InstallResult(InstallResultType.fileNotFound, 'APK file was not found.');
      } else {
        return InstallResult(InstallResultType.error, result.message);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ApkInstallerService] Error installing APK: $e');
      }
      return InstallResult(InstallResultType.error, 'Could not open package installer: $e');
    }
  }
}
