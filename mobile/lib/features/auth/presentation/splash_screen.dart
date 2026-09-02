import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/update/app_update_dialog.dart';
import '../../../core/update/app_update_model.dart';
import '../../../core/update/app_update_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _hasCheckedUpdate = false;

  @override
  void initState() {
    super.initState();
    _initAppAndCheckUpdate();
  }

  Future<void> _initAppAndCheckUpdate() async {
    // 1. Request notification permissions in background
    _requestNotificationPermission();

    // 2. Perform app update check
    if (!_hasCheckedUpdate) {
      _hasCheckedUpdate = true;
      try {
        final updateResult = await ref.read(appUpdateServiceProvider).checkForUpdate();

        if (!mounted) return;

        if (updateResult.status == UpdateStatus.mandatory && updateResult.updateModel != null) {
          ref.read(isMandatoryUpdateActiveProvider.notifier).state = true;
          AppUpdateDialog.show(
            context,
            updateModel: updateResult.updateModel!,
            installedInfo: updateResult.installedInfo,
            isMandatory: true,
          );
          return;
        } else if (updateResult.status == UpdateStatus.optional && updateResult.updateModel != null) {
          AppUpdateDialog.show(
            context,
            updateModel: updateResult.updateModel!,
            installedInfo: updateResult.installedInfo,
            isMandatory: false,
            onDismissed: () {
              if (mounted) {
                ref.read(isSplashCheckDoneProvider.notifier).state = true;
              }
            },
          );
          return;
        }
      } catch (e) {
        // Logging / error handled gracefully in service
      }
    }

    // If no update or non-blocking, mark splash check done
    if (mounted) {
      ref.read(isSplashCheckDoneProvider.notifier).state = true;
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      if (status.isDenied) {
        await Permission.notification.request();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'CoreHives',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
