import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/src/game/sokoban_rules.dart';
import 'package:app/src/levels/level_catalog.dart';
import 'package:app/src/models/board_position.dart';
import 'package:app/src/models/sokoban_level.dart';
import 'package:app/src/ui/sokoban_wall_page.dart';

void main() {
  test('findNextSokobanPushHint returns the first solving push', () {
    const layout = ['#####', '#   #', '# B #', '# T #', '#   #', '#####'];
    final targets = positionsForSymbol(layout, 'T');
    final result = findNextSokobanPushHint(
      layout: layout,
      playerPosition: const BoardPosition(row: 1, column: 1),
      brickPositions: positionsForSymbol(layout, 'B'),
      targetPositions: targets,
      deadTiles: computeDeadTiles(layout, targets),
    );

    expect(result.status, SokobanHintSearchStatus.found);
    expect(result.hint?.brickPosition, const BoardPosition(row: 2, column: 2));
    expect(result.hint?.direction, const BoardPosition(row: 1, column: 0));
    expect(
      result.hint?.nextBrickPosition,
      const BoardPosition(row: 3, column: 2),
    );
  });

  test(
    'findNextSokobanPushHint reports a dead starting state as no solution',
    () {
      const layout = ['#####', '#B  #', '#   #', '#  T#', '#   #', '#####'];
      final targets = positionsForSymbol(layout, 'T');
      final result = findNextSokobanPushHint(
        layout: layout,
        playerPosition: const BoardPosition(row: 2, column: 2),
        brickPositions: positionsForSymbol(layout, 'B'),
        targetPositions: targets,
        deadTiles: computeDeadTiles(layout, targets),
      );

      expect(result.status, SokobanHintSearchStatus.noSolution);
    },
  );

  testWidgets('hint button escalates from strategic hints to next push', (
    tester,
  ) async {
    final customCatalog = [
      LevelCatalogItem(
        id: 'custom_hint_level',
        source: LevelSource.custom,
        level: SokobanLevel(
          number: 99,
          title: '提示测试关卡',
          description: '用于验证提示按钮。',
          layout: const ['#####', '#   #', '# B #', '# T #', '#   #', '#####'],
          initialPlayerPosition: const BoardPosition(row: 1, column: 1),
        ),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(home: SokobanWallPage(levelCatalog: customCatalog)),
    );

    await _tapHint(tester);
    expect(find.textContaining('提示 1/3'), findsOneWidget);

    await _tapHint(tester);
    expect(find.textContaining('提示 2/3'), findsOneWidget);

    await _tapHint(tester);
    expect(find.textContaining('提示 3/3'), findsOneWidget);

    await _tapHint(tester);
    expect(find.textContaining('下一步'), findsOneWidget);
    expect(find.textContaining('向下推一格'), findsOneWidget);
  });
}

Future<void> _tapHint(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, '提示'));
  await tester.pump();
}
