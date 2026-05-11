import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import 'package:app/src/game/sokoban_rules.dart';
import 'package:app/src/levels/sokoban_levels.dart';
import 'package:app/src/models/board_position.dart';
import 'package:app/src/sokoban_app.dart';
import 'package:app/src/ui/level_selection_page.dart';
import 'package:app/src/ui/sokoban_board.dart';

void main() {
  test('has designed levels with valid basic structure', () {
    expect(sokobanLevels.length, 1);

    for (final level in sokobanLevels) {
      final expectedColumnCount = level.layout.first.length;
      final bricks = positionsForSymbol(level.layout, 'B');
      final targets = positionsForSymbol(level.layout, 'T');

      expect(
        level.layout.every((row) => row.length == expectedColumnCount),
        isTrue,
        reason: '${level.displayName} must be rectangular.',
      );
      expect(
        bricks.length,
        targets.length,
        reason:
            '${level.displayName} must have matching box and target counts.',
      );
      expect(
        isFloorTile(level.layout, level.initialPlayerPosition),
        isTrue,
        reason: '${level.displayName} player must start on a floor tile.',
      );
      expect(
        bricks.contains(level.initialPlayerPosition),
        isFalse,
        reason: '${level.displayName} player must not start on a box.',
      );
    }
  });

  test('level layouts are unique', () {
    final layoutKeys = <String>{};

    for (final level in sokobanLevels) {
      final layoutKey = level.layout.join('\n');

      expect(
        layoutKeys.add(layoutKey),
        isTrue,
        reason: '${level.displayName} must not duplicate another layout.',
      );
    }
  });

  test('first level has a known solution', () {
    final level = sokobanLevels.single;
    final bricks = positionsForSymbol(level.layout, 'B');
    final targets = positionsForSymbol(level.layout, 'T');
    var playerPosition = level.initialPlayerPosition;

    const solution = [
      BoardPosition(row: -1, column: 0),
      BoardPosition(row: -1, column: 0),
      BoardPosition(row: 1, column: 0),
      BoardPosition(row: 1, column: 0),
      BoardPosition(row: 1, column: 0),
      BoardPosition(row: -1, column: 0),
      BoardPosition(row: 0, column: -1),
      BoardPosition(row: 0, column: -1),
      BoardPosition(row: 0, column: 1),
      BoardPosition(row: 0, column: 1),
      BoardPosition(row: 0, column: 1),
      BoardPosition(row: 0, column: 1),
    ];

    for (final direction in solution) {
      final nextPosition = playerPosition.move(direction.row, direction.column);
      if (bricks.contains(nextPosition)) {
        final nextBrickPosition = nextPosition.move(
          direction.row,
          direction.column,
        );
        expect(isFloorTile(level.layout, nextBrickPosition), isTrue);
        expect(bricks.contains(nextBrickPosition), isFalse);
        bricks
          ..remove(nextPosition)
          ..add(nextBrickPosition);
      } else {
        expect(isFloorTile(level.layout, nextPosition), isTrue);
      }

      playerPosition = nextPosition;
    }

    expect(isSolvedState(bricks, targets), isTrue);
  });

  testWidgets('renders the level selection page', (tester) async {
    await tester.pumpWidget(const SokobanApp());

    expect(find.byType(LevelSelectionPage), findsOneWidget);
    expect(find.text('选择关卡'), findsOneWidget);
    for (
      var levelNumber = 1;
      levelNumber <= sokobanLevels.length;
      levelNumber++
    ) {
      expect(find.text('$levelNumber'), findsOneWidget);
    }
  });

  testWidgets('opens a selected Sokoban level', (tester) async {
    await tester.pumpWidget(const SokobanApp());

    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    expect(find.text('推箱子 - 第一关'), findsOneWidget);
    expect(find.text('切换关卡'), findsNothing);
    expect(find.byType(SokobanBoard), findsOneWidget);
    expect(_tilesWithPrefix('empty-'), findsNWidgets(99));
    expect(_tilesWithPrefix('wall-'), findsNWidgets(37));
    expect(_tilesWithPrefix('brick-'), findsNWidgets(4));
    expect(_tilesWithPrefix('floor-'), findsNWidgets(10));
  });
}

Finder _tilesWithPrefix(String prefix) {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith(prefix);
  });
}
