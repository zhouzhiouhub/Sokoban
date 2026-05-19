import 'package:flutter/material.dart';

import 'app_branding.dart';
import 'levels/custom_level_store.dart';
import 'ui/level_selection_page.dart';

class SokobanApp extends StatelessWidget {
  const SokobanApp({super.key, this.customLevelStore});

  final CustomLevelStore? customLevelStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: appName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF526652)),
        useMaterial3: true,
      ),
      home: LevelSelectionPage(customLevelStore: customLevelStore),
    );
  }
}
