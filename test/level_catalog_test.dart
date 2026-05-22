import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/src/app_branding.dart';
import 'package:app/src/levels/level_catalog.dart';
import 'package:app/src/levels/sokoban_levels.dart';
import 'package:app/src/models/board_position.dart';
import 'package:app/src/models/sokoban_level.dart';
import 'package:app/src/ui/sokoban_wall_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('built-in level catalog wraps the generated levels', () async {
    final levels = await loadSokobanLevels();
    final catalog = buildBuiltInLevelCatalog(levels);

    expect(catalog, hasLength(levels.length));
    expect(catalog.first.id, 'built_in_1');
    expect(catalog.first.source, LevelSource.builtIn);
    expect(catalog.first.level, same(levels.first));
  });

  testWidgets('SokobanWallPage uses an injected level catalog', (tester) async {
    final customCatalog = [
      LevelCatalogItem(
        id: 'custom_test_level',
        source: LevelSource.custom,
        level: SokobanLevel(
          number: 99,
          title: '测试自定义关卡',
          description: '用于验证目录注入。',
          layout: const ['#####', '#   #', '# B #', '# T #', '#   #', '#####'],
          initialPlayerPosition: const BoardPosition(row: 1, column: 1),
        ),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(home: SokobanWallPage(levelCatalog: customCatalog)),
    );

    expect(find.text(appLevelTitle('测试自定义关卡')), findsOneWidget);
    expect(find.text('第 99 关'), findsOneWidget);
  });

  testWidgets('SokobanWallPage reloads when the initial level changes', (
    tester,
  ) async {
    final levels = await loadSokobanLevels();

    await tester.pumpWidget(
      const MaterialApp(home: SokobanWallPage(initialLevelIndex: 0)),
    );
    await tester.pumpAndSettle();
    expect(find.text(appLevelTitle(levels[0].title)), findsOneWidget);
    expect(find.text('第 1 关'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(home: SokobanWallPage(initialLevelIndex: 1)),
    );
    await tester.pumpAndSettle();

    expect(find.text(appLevelTitle(levels[1].title)), findsOneWidget);
    expect(find.text('第 2 关'), findsOneWidget);
    expect(find.text('第 1 关'), findsNothing);
  });
}
