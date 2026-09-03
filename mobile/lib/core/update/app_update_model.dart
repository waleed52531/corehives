enum UpdateStatus {
  none,
  optional,
  mandatory,
}

class SemanticVersion implements Comparable<SemanticVersion> {
  final int major;
  final int minor;
  final int patch;

  const SemanticVersion(this.major, this.minor, this.patch);

  factory SemanticVersion.parse(String value) {
    final normalized = value.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final main = normalized.split(RegExp(r'[-+]')).first;
    final parts = main.split('.');

    if (parts.isEmpty || parts.length > 3) {
      throw FormatException('Invalid semantic version: $value');
    }

    int parsePart(int index) {
      if (index >= parts.length) return 0;
      final parsed = int.tryParse(parts[index]);
      if (parsed == null || parsed < 0) {
        throw FormatException('Invalid semantic version: $value');
      }
      return parsed;
    }

    return SemanticVersion(
      parsePart(0),
      parsePart(1),
      parsePart(2),
    );
  }

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';
}

class UpdatePolicy {
  final int minimumBuildNumber;
  final bool forceUpdate;

  const UpdatePolicy({
    this.minimumBuildNumber = 0,
    this.forceUpdate = false,
  });

  factory UpdatePolicy.fromMap(Map<String, dynamic> map) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim()) ?? 0;
      return 0;
    }

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final lower = value.trim().toLowerCase();
        return lower == 'true' || lower == '1' || lower == 'yes';
      }
      return false;
    }

    return UpdatePolicy(
      minimumBuildNumber: parseInt(map['minimumBuildNumber']),
      forceUpdate: parseBool(map['forceUpdate']),
    );
  }
}

class ReleaseTagVersion {
  final String versionName;
  final int buildNumber;

  const ReleaseTagVersion({
    required this.versionName,
    required this.buildNumber,
  });

  factory ReleaseTagVersion.parse(String tag) {
    final normalized = normalizeTag(tag);
    final parts = normalized.split('+');
    final versionName = parts.first.trim();
    final buildNumber =
        parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 0 : 0;

    if (versionName.isEmpty) {
      throw FormatException('Invalid release tag: $tag');
    }

    SemanticVersion.parse(versionName);

    return ReleaseTagVersion(
      versionName: versionName,
      buildNumber: buildNumber,
    );
  }

  static String normalizeTag(String tag) {
    final value = tag.trim();
    if (value.toLowerCase().startsWith('v')) {
      return value.substring(1);
    }
    return value;
  }
}

class AppUpdateModel {
  final String currentVersion;
  final int currentBuildNumber;
  final String latestVersion;
  final int latestBuildNumber;
  final int minimumBuildNumber;
  final bool forceUpdate;
  final String apkUrl;
  final String releaseNotes;
  final String releaseUrl;
  final String assetName;

  const AppUpdateModel({
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.minimumBuildNumber,
    required this.forceUpdate,
    required this.apkUrl,
    required this.releaseNotes,
    required this.releaseUrl,
    required this.assetName,
  });

  bool get isUpdateAvailable {
    if (latestBuildNumber > currentBuildNumber) {
      return true;
    }

    return SemanticVersion.parse(latestVersion).compareTo(
          SemanticVersion.parse(currentVersion),
        ) >
        0;
  }

  bool get isForceUpdate {
    if (!isUpdateAvailable) return false;
    if (forceUpdate) return true;
    return minimumBuildNumber > 0 && currentBuildNumber < minimumBuildNumber;
  }

  UpdateStatus get status {
    if (!isUpdateAvailable) return UpdateStatus.none;
    return isForceUpdate ? UpdateStatus.mandatory : UpdateStatus.optional;
  }

  List<String> get releaseNotesList {
    if (releaseNotes.trim().isEmpty) return const [];
    return releaseNotes
        .split('\n')
        .map((line) => line.replaceFirst(RegExp(r'^[•\-\*]\s*'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  String get sessionKey => '$latestVersion+$latestBuildNumber';

  String get currentDisplayVersion => '$currentVersion+$currentBuildNumber';

  String get latestDisplayVersion => '$latestVersion+$latestBuildNumber';

  @override
  String toString() {
    return 'AppUpdateModel(currentVersion: $currentDisplayVersion, latestVersion: $latestDisplayVersion, minimumBuildNumber: $minimumBuildNumber, forceUpdate: $forceUpdate, apkUrl: $apkUrl, assetName: $assetName)';
  }
}
