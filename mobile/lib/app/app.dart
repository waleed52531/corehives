import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'theme.dart';
import 'theme_provider.dart';
import '../core/update/app_update_dialog.dart';
import '../core/update/app_update_service.dart';
import '../shared/services/notification_service.dart';
import '../shared/providers/auth_providers.dart';
import '../shared/models/app_user.dart';

class CoreHivesApp extends ConsumerWidget {
  const CoreHivesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<AppUser?>>(currentAppUserProvider, (previous, next) {
      final user = next.value;
      if (user != null) {
        NotificationService.registerUserDevice(user.uid);
      }
    });

    ref.listen<UpdateCheckResult?>(pendingOptionalUpdateProvider,
        (previous, next) {
      if (next == null || next.updateModel == null) return;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final context = rootNavigatorKey.currentContext;
        if (context == null) return;

        await AppUpdateDialog.show(
          context,
          updateModel: next.updateModel!,
          installedInfo: next.installedInfo,
          isMandatory: false,
        );

        ref.read(appUpdateServiceProvider).dismissOptionalUpdateInSession(
              next.updateModel!.sessionKey,
            );
        ref.read(pendingOptionalUpdateProvider.notifier).state = null;
      });
    });

    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'CoreHives',
      debugShowCheckedModeBanner: false,
      theme: CoreHivesTheme.light,
      darkTheme: CoreHivesTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
