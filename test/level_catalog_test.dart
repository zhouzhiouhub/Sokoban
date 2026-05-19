import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/src/app_branding.dart';
import 'package:app/src/levels/level_catalog.dart';
import 'package:app/src/levels/sokoban_levels.dart';
import 'package:app/src/models/board_position.dart';
import 'package:app/src/models/sokoban_level.dart';
import 'package:app/src/ui/sokoban_wall_page.dart';

void main() {
  test('built-in level catalog wraps the designed levels', () {
    expect(builtInLevelCatalog, hasLength(sokobanLevels.length));
    expect(builtInLevelCatalog.first.id, 'built_in_1');
    expect(builtInLevelCatalog.first.source, LevelSource.builtIn);
    expect(builtInLevelCatalog.first.level, same(sokobanLevels.first));
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
}
