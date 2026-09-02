import 'package:cloud_firestore/cloud_firestore.dart';

enum UpdateStatus {
  none,
  optional,
  mandatory,
}

class AppUpdateModel {
  final String latestVersion;
  final int latestVersionCode;
  final int minimumVersionCode;
  final bool forceUpdate;
  final String apkUrl;
  final String releaseNotes;

  const AppUpdateModel({
    required this.latestVersion,
    required this.latestVersionCode,
    required this.minimumVersionCode,
    required this.forceUpdate,
    required this.apkUrl,
    required this.releaseNotes,
  });

  /// Evaluates whether this update is mandatory for the given installed build number.
  bool isMandatoryFor(int installedVersionCode) {
    if (forceUpdate) return true;
    if (minimumVersionCode > 0 && installedVersionCode < minimumVersionCode) {
      return true;
    }
    return false;
  }

  /// Evaluates whether an update is available for the given installed build number.
  bool isUpdateAvailable(int installedVersionCode) {
    return apkUrl.trim().isNotEmpty && installedVersionCode < latestVersionCode;
  }

  /// Determines the update status category (none, optional, or mandatory).
  UpdateStatus getUpdateStatus(int installedVersionCode) {
    if (!isUpdateAvailable(installedVersionCode)) {
      return UpdateStatus.none;
    }
    if (isMandatoryFor(installedVersionCode)) {
      return UpdateStatus.mandatory;
    }
    return UpdateStatus.optional;
  }

  /// Converts bulleted release notes or paragraphs into formatted bullet points.
  List<String> get releaseNotesList {
    if (releaseNotes.trim().isEmpty) return const [];
    return releaseNotes
        .split('\n')
        .map((line) => line.replaceFirst(RegExp(r'^[•\-\*]\s*'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  factory AppUpdateModel.fromMap(Map<String, dynamic> map) {
    // Helper to safely parse int from dynamic (int, double, string)
    int parseInt(dynamic val, int defaultVal) {
      if (val == null) return defaultVal;
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) {
        final parsed = int.tryParse(val.trim());
        if (parsed != null) return parsed;
      }
      return defaultVal;
    }

    // Helper to safely parse bool from dynamic (bool, string, int)
    bool parseBool(dynamic val, bool defaultVal) {
      if (val == null) return defaultVal;
      if (val is bool) return val;
      if (val is String) {
        final s = val.trim().toLowerCase();
        if (s == 'true' || s == '1') return true;
        if (s == 'false' || s == '0') return false;
      }
      if (val is num) return val != 0;
      return defaultVal;
    }

    return AppUpdateModel(
      latestVersion: (map['latestVersion'] ?? map['android_latest_version'] ?? '').toString().trim(),
      latestVersionCode: parseInt(map['latestVersionCode'] ?? map['android_latest_version_code'], 0),
      minimumVersionCode: parseInt(map['minimumVersionCode'] ?? map['android_minimum_version_code'], 0),
      forceUpdate: parseBool(map['forceUpdate'] ?? map['android_force_update'], false),
      apkUrl: (map['apkUrl'] ?? map['android_apk_url'] ?? '').toString().trim(),
      releaseNotes: (map['releaseNotes'] ?? map['android_release_notes'] ?? '').toString().trim(),
    );
  }

  factory AppUpdateModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    if (!doc.exists || doc.data() == null) {
      return const AppUpdateModel(
        latestVersion: '',
        latestVersionCode: 0,
        minimumVersionCode: 0,
        forceUpdate: false,
        apkUrl: '',
        releaseNotes: '',
      );
    }
    return AppUpdateModel.fromMap(doc.data()!);
  }

  Map<String, dynamic> toMap() {
    return {
      'latestVersion': latestVersion,
      'latestVersionCode': latestVersionCode,
      'minimumVersionCode': minimumVersionCode,
      'forceUpdate': forceUpdate,
      'apkUrl': apkUrl,
      'releaseNotes': releaseNotes,
    };
  }

  @override
  String toString() {
    return 'AppUpdateModel(latestVersion: $latestVersion, latestVersionCode: $latestVersionCode, minVersionCode: $minimumVersionCode, forceUpdate: $forceUpdate, apkUrl: $apkUrl)';
  }
}
