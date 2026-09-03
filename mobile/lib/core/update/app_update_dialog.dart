import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_update_model.dart';
import 'app_update_service.dart';
import 'apk_download_service.dart';
import 'apk_installer_service.dart';

enum DialogDownloadState {
  idle,
  downloading,
  completed,
  failed,
}

class AppUpdateDialog extends ConsumerStatefulWidget {
  final AppUpdateModel updateModel;
  final InstalledAppInfo installedInfo;
  final bool isMandatory;
  final VoidCallback? onDismissed;

  const AppUpdateDialog({
    super.key,
    required this.updateModel,
    required this.installedInfo,
    required this.isMandatory,
    this.onDismissed,
  });

  static Future<void> show(
    BuildContext context, {
    required AppUpdateModel updateModel,
    required InstalledAppInfo installedInfo,
    required bool isMandatory,
    VoidCallback? onDismissed,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (ctx) => PopScope(
        canPop: !isMandatory,
        child: AppUpdateDialog(
          updateModel: updateModel,
          installedInfo: installedInfo,
          isMandatory: isMandatory,
          onDismissed: onDismissed,
        ),
      ),
    );
  }

  @override
  ConsumerState<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends ConsumerState<AppUpdateDialog> {
  final ApkDownloadService _downloadService = ApkDownloadService();
  final ApkInstallerService _installerService = ApkInstallerService();

  StreamSubscription<DownloadProgress>? _downloadSub;
  DialogDownloadState _state = DialogDownloadState.idle;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;
  File? _downloadedFile;

  @override
  void dispose() {
    _downloadSub?.cancel();
    _downloadService.cancelDownload();
    super.dispose();
  }

  void _startDownload() {
    if (_state == DialogDownloadState.downloading) return;

    debugPrint('[UpdateService] Download started');
    setState(() {
      _state = DialogDownloadState.downloading;
      _progress = 0.0;
      _receivedBytes = 0;
      _totalBytes = 0;
      _errorMessage = null;
    });

    _downloadSub?.cancel();
    _downloadSub = _downloadService
        .downloadApk(
      apkUrl: widget.updateModel.apkUrl,
      targetVersion: widget.updateModel.latestVersion,
    )
        .listen(
      (event) {
        if (!mounted) return;

        if (event.error != null) {
          setState(() {
            _state = DialogDownloadState.failed;
            _errorMessage = event.error;
          });
        } else if (event.isCompleted && event.file != null) {
          debugPrint('[UpdateService] Download completed');
          setState(() {
            _state = DialogDownloadState.completed;
            _progress = 1.0;
            _downloadedFile = event.file;
          });
          _triggerInstallation(event.file!);
        } else {
          setState(() {
            _progress = event.progress;
            _receivedBytes = event.receivedBytes;
            _totalBytes = event.totalBytes;
          });
        }
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _state = DialogDownloadState.failed;
          _errorMessage = err.toString();
        });
      },
    );
  }

  Future<void> _triggerInstallation(File file) async {
    debugPrint('[UpdateService] Opening installer');
    final result = await _installerService.installApk(file);
    if (!mounted) return;

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(result.message ?? 'Could not launch package installer.'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    final releaseNotesList = widget.updateModel.releaseNotesList;
    final latestDisplayVersion = widget.updateModel.latestDisplayVersion;
    final installedDisplayVersion =
        '${widget.installedInfo.version}+${widget.installedInfo.versionCode}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 16,
      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with Icon
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: widget.isMandatory
                          ? (isDark
                              ? const Color(0xFF3B1E1E)
                              : const Color(0xFFFFECEC))
                          : (isDark
                              ? const Color(0xFF1C2A3A)
                              : const Color(0xFFE8F2FF)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      widget.isMandatory
                          ? Icons.system_security_update_warning
                          : Icons.system_update_rounded,
                      color: widget.isMandatory
                          ? Colors.red.shade600
                          : primaryColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isMandatory
                              ? 'Update Required'
                              : 'Update Available',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.isMandatory
                              ? 'A newer version of CoreHives is required.'
                              : 'CoreHives v$latestDisplayVersion is ready to install.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Version comparison tag
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF21262D)
                      : const Color(0xFFF6F8FA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF30363D)
                        : const Color(0xFFE1E4E8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Installed: v$installedDisplayVersion',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.arrow_forward_rounded,
                            size: 14,
                            color: isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          'Latest: v$latestDisplayVersion',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Content based on state
              if (_state == DialogDownloadState.idle) ...[
                if (releaseNotesList.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    "What's New:",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 140),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: releaseNotesList.map((note) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin:
                                      const EdgeInsets.only(top: 6, right: 8),
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    note,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.35,
                                      color: isDark
                                          ? Colors.grey.shade300
                                          : Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                // Actions
                Row(
                  children: [
                    if (!widget.isMandatory) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ref
                                .read(appUpdateServiceProvider)
                                .dismissOptionalUpdateInSession(
                                    widget.updateModel.sessionKey);
                            Navigator.of(context).pop();
                            widget.onDismissed?.call();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Later'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: widget.isMandatory ? 1 : 1,
                      child: FilledButton(
                        onPressed: _startDownload,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(widget.isMandatory
                            ? 'Update CoreHives'
                            : 'Update Now'),
                      ),
                    ),
                  ],
                ),
              ] else if (_state == DialogDownloadState.downloading) ...[
                const SizedBox(height: 24),
                Text(
                  'Downloading latest version...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(_progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                    if (_totalBytes > 0)
                      Text(
                        '${_formatBytes(_receivedBytes)} / ${_formatBytes(_totalBytes)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Please don't close the application.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                  ),
                ),
                if (!widget.isMandatory) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      _downloadService.cancelDownload();
                      setState(() => _state = DialogDownloadState.idle);
                    },
                    child: const Text('Cancel Download'),
                  ),
                ],
              ] else if (_state == DialogDownloadState.completed) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF193222)
                        : const Color(0xFFEDFBF0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.green, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Download complete! Opening Android installer...',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.green.shade200
                                : Colors.green.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    if (_downloadedFile != null) {
                      _triggerInstallation(_downloadedFile!);
                    }
                  },
                  icon: const Icon(Icons.install_mobile_rounded),
                  label: const Text('Install Now'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ] else if (_state == DialogDownloadState.failed) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF3B1E1E)
                        : const Color(0xFFFFECEC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: Colors.red.shade700, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Update Failed',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.red.shade800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _errorMessage ??
                                  'Could not download the update. Please check your internet connection.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.red.shade200
                                    : Colors.red.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (!widget.isMandatory) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onDismissed?.call();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: _startDownload,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Retry'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
