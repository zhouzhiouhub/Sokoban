import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/src/controllers/game_controller.dart';
import 'package:app/src/game/sokoban_rules.dart';
import 'package:app/src/levels/level_catalog.dart';
import 'package:app/src/levels/sokoban_standard_solutions.dart';
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

  test('parseSokobanStandardSolution decodes semicolon separated pushes', () {
    final solution = parseSokobanStandardSolution('2,3,U;2,2,L\n');

    expect(solution, hasLength(2));
    expect(
      solution.first.brickPosition,
      const BoardPosition(row: 2, column: 3),
    );
    expect(solution.first.direction, const BoardPosition(row: -1, column: 0));
    expect(solution.last.brickPosition, const BoardPosition(row: 2, column: 2));
    expect(solution.last.direction, const BoardPosition(row: 0, column: -1));
  });

  test('built-in standard hint asks to undo after leaving the path', () {
    final container = ProviderContainer(
      overrides: [
        activeLevelCatalogProvider.overrideWithValue([
          LevelCatalogItem(
            id: 'built_in_hint_level',
            source: LevelSource.builtIn,
            level: SokobanLevel(
              number: 99,
              title: '标准提示测试关卡',
              description: '用于验证标准答案提示。',
              layout: const [
                '#######',
                '#     #',
                '#  T  #',
                '#  B  #',
                '#     #',
                '#######',
              ],
              initialPlayerPosition: const BoardPosition(row: 4, column: 3),
            ),
            standardSolution: const [
              SokobanPushHint(
                brickPosition: BoardPosition(row: 3, column: 3),
                direction: BoardPosition(row: -1, column: 0),
              ),
            ],
          ),
        ]),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(gameControllerProvider.notifier);
    final firstHint = controller.showHint();
    expect(firstHint.message, contains('向上推一格'));

    controller.movePlayer(0, 1);
    controller.movePlayer(-1, 0);
    controller.movePlayer(0, -1);

    final recoveryHint = controller.showHint();
    final state = container.read(gameControllerProvider);
    expect(recoveryHint.message, contains('偏离标准答案'));
    expect(recoveryHint.message, contains('撤销 1 步'));
    expect(state.hintedBrickPosition, isNull);
  });

  testWidgets('hint button shows next push immediately', (tester) async {
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
    expect(find.textContaining('下一步'), findsOneWidget);
    expect(find.textContaining('向下推一格'), findsOneWidget);
    expect(find.textContaining('提示 1/3'), findsNothing);
  });
}

Future<void> _tapHint(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, '提示'));
  await tester.pump();
}
