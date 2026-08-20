import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'theme.dart';

class CoreHivesApp extends ConsumerWidget {
  const CoreHivesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'CoreHives',
      debugShowCheckedModeBanner: false,
      theme: CoreHivesTheme.light,
      darkTheme: CoreHivesTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
