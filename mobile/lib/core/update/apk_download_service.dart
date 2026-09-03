import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class DownloadProgress {
  final double progress; // 0.0 to 1.0
  final int receivedBytes;
  final int totalBytes;
  final bool isCompleted;
  final String? error;
  final File? file;

  const DownloadProgress({
    required this.progress,
    required this.receivedBytes,
    required this.totalBytes,
    this.isCompleted = false,
    this.error,
    this.file,
  });

  int get percentage => (progress * 100).clamp(0, 100).toInt();

  factory DownloadProgress.initial() => const DownloadProgress(
        progress: 0.0,
        receivedBytes: 0,
        totalBytes: 0,
      );

  factory DownloadProgress.error(String message) => DownloadProgress(
        progress: 0.0,
        receivedBytes: 0,
        totalBytes: 0,
        error: message,
      );

  factory DownloadProgress.completed(File file, int total) => DownloadProgress(
        progress: 1.0,
        receivedBytes: total,
        totalBytes: total,
        isCompleted: true,
        file: file,
      );
}

class ApkDownloadService {
  http.Client? _client;
  bool _isCancelled = false;

  /// Downloads the APK file from [apkUrl] with streaming progress updates.
  Stream<DownloadProgress> downloadApk({
    required String apkUrl,
    required String targetVersion,
  }) async* {
    _isCancelled = false;
    _client = http.Client();

    try {
      final uri = Uri.tryParse(apkUrl);
      if (uri == null ||
          !uri.hasScheme ||
          (!uri.isScheme('https') && !uri.isScheme('http'))) {
        yield DownloadProgress.error('Invalid APK URL.');
        return;
      }

      debugPrint('[UpdateService] Download request: $apkUrl');

      final tempDir = await getTemporaryDirectory();
      final updateDir = Directory('${tempDir.path}/app_updates');
      if (!await updateDir.exists()) {
        await updateDir.create(recursive: true);
      }

      // Clean up older APKs in update directory
      try {
        final entities = updateDir.listSync();
        for (final entity in entities) {
          if (entity is File && entity.path.endsWith('.apk')) {
            entity.deleteSync();
          }
        }
      } catch (e) {
        debugPrint('[UpdateService] APK cleanup warning: $e');
      }

      final safeVersion =
          targetVersion.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final targetFile = File('${updateDir.path}/corehives_v$safeVersion.apk');

      final request = http.Request('GET', uri);
      final response = await _client!.send(request).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException(
              'Connection timed out while connecting to update server.');
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        yield DownloadProgress.error(
            'Server returned HTTP ${response.statusCode}');
        return;
      }

      final contentLength = response.contentLength ?? 0;
      int receivedBytes = 0;

      final sink = targetFile.openWrite();

      await for (final chunk in response.stream) {
        if (_isCancelled) {
          await sink.close();
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
          yield DownloadProgress.error('Download cancelled.');
          return;
        }

        sink.add(chunk);
        receivedBytes += chunk.length;

        final progress =
            contentLength > 0 ? (receivedBytes / contentLength) : 0.0;

        yield DownloadProgress(
          progress: progress,
          receivedBytes: receivedBytes,
          totalBytes: contentLength,
        );
      }

      await sink.flush();
      await sink.close();

      debugPrint(
          '[UpdateService] Download completed. Size: ${await targetFile.length()} bytes');

      yield DownloadProgress.completed(targetFile, receivedBytes);
    } catch (e) {
      debugPrint('[UpdateService] Download error: $e');
      yield DownloadProgress.error(e is TimeoutException
          ? 'Download timed out. Please check your connection.'
          : 'Download failed: $e');
    } finally {
      _client?.close();
      _client = null;
    }
  }

  void cancelDownload() {
    _isCancelled = true;
    _client?.close();
    _client = null;
  }
}
