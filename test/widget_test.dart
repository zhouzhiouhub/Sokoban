import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import 'package:app/src/game/sokoban_rules.dart';
import 'package:app/src/levels/sokoban_levels.dart';
import 'package:app/src/sokoban_app.dart';
import 'package:app/src/ui/sokoban_board.dart';

void main() {
  test('has twenty designed levels with valid basic structure', () {
    expect(sokobanLevels.length, 20);

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

  test('all levels are solvable by the game rules', () {
    for (final level in sokobanLevels) {
      final bricks = positionsForSymbol(level.layout, 'B');
      final targets = positionsForSymbol(level.layout, 'T');
      final deadTiles = computeDeadTiles(level.layout, targets);

      expect(
        isSokobanStateSolvable(
          layout: level.layout,
          playerPosition: level.initialPlayerPosition,
          brickPositions: bricks,
          targetPositions: targets,
          deadTiles: deadTiles,
        ),
        isTrue,
        reason: '${level.displayName} should be solvable.',
      );
    }
  });

  testWidgets('renders the first Sokoban level', (tester) async {
    await tester.pumpWidget(const SokobanApp());

    expect(find.text('推箱子 - Level 1 — 第一份货物'), findsOneWidget);
    expect(find.byType(SokobanBoard), findsOneWidget);
    expect(_tilesWithPrefix('wall-'), findsNWidgets(20));
    expect(_tilesWithPrefix('brick-'), findsNWidgets(1));
    expect(_tilesWithPrefix('floor-'), findsNWidgets(14));
  });
}

Finder _tilesWithPrefix(String prefix) {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith(prefix);
  });
}
