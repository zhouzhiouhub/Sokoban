import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_branding.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'controllers/level_catalog_controller.dart';
import 'levels/custom_level_store.dart';

class SokobanApp extends StatelessWidget {
  const SokobanApp({super.key, this.customLevelStore});

  final CustomLevelStore? customLevelStore;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        if (customLevelStore != null)
          customLevelStoreProvider.overrideWithValue(customLevelStore!),
      ],
      child: const _SokobanMaterialApp(),
    );
  }
}

class _SokobanMaterialApp extends ConsumerWidget {
  const _SokobanMaterialApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: appName,
      theme: buildSokobanTheme(),
      routerConfig: router,
    );
  }
}
