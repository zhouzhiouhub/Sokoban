import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ui/level_selection_page.dart';
import '../ui/sokoban_wall_page.dart';

enum AppRoute {
  home('home', '/'),
  level('level', '/level/:index');

  const AppRoute(this.name, this.path);

  final String name;
  final String path;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(
        name: AppRoute.home.name,
        path: AppRoute.home.path,
        builder: (context, state) => const LevelSelectionPage(),
      ),
      GoRoute(
        name: AppRoute.level.name,
        path: AppRoute.level.path,
        pageBuilder: (context, state) {
          final index = int.tryParse(state.pathParameters['index'] ?? '') ?? 0;
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: SokobanWallPage(initialLevelIndex: index),
            transitionsBuilder: _levelTransition,
          );
        },
      ),
    ],
  );
});

Widget _levelTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final curvedAnimation = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  return FadeTransition(
    opacity: curvedAnimation,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.04, 0),
        end: Offset.zero,
      ).animate(curvedAnimation),
      child: child,
    ),
  );
}
