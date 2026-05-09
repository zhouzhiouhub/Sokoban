import 'package:flutter/material.dart';

import 'ui/sokoban_wall_page.dart';

class SokobanApp extends StatelessWidget {
  const SokobanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '推箱子',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF526652)),
        useMaterial3: true,
      ),
      home: const SokobanWallPage(),
    );
  }
}
