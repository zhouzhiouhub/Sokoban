import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/src/game/sokoban_rules.dart';
import 'package:app/src/levels/custom_level_store.dart';
import 'package:app/src/levels/sokoban_levels.dart';
import 'package:app/src/sokoban_app.dart';
import 'package:app/src/ui/level_selection_page.dart';
import 'package:app/src/ui/sokoban_board.dart';

void main() {
  test('has designed levels with valid basic structure', () {
    expect(sokobanLevels.length, 40);

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

  test('designed levels are solvable', () {
    for (final level in sokobanLevels) {
      final bricks = positionsForSymbol(level.layout, 'B');
      final targets = positionsForSymbol(level.layout, 'T');

      expect(
        isSokobanStateSolvable(
          layout: level.layout,
          playerPosition: level.initialPlayerPosition,
          brickPositions: bricks,
          targetPositions: targets,
          deadTiles: computeDeadTiles(level.layout, targets),
        ),
        isTrue,
        reason: '${level.displayName} must have at least one solution.',
      );
    }
  });

  testWidgets('renders the level selection page', (tester) async {
    await tester.pumpWidget(
      SokobanApp(customLevelStore: await _createTempStore()),
    );
    await tester.pump();

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
    await tester.pumpWidget(
      SokobanApp(customLevelStore: await _createTempStore()),
    );
    await tester.pump();

    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    expect(find.text('推箱子 - 第一关'), findsOneWidget);
    expect(find.text('切换关卡'), findsNothing);
    expect(find.byType(SokobanBoard), findsOneWidget);

    final level = sokobanLevels.first;
    final emptyCount = _cellCount(level.layout, '_');
    final wallCount = _cellCount(level.layout, '#');
    final brickCount = positionsForSymbol(level.layout, 'B').length;
    final cellCount = level.layout.fold<int>(
      0,
      (count, row) => count + row.length,
    );
    final floorCount = cellCount - emptyCount - wallCount - brickCount;

    expect(_tilesWithPrefix('empty-'), findsNWidgets(emptyCount));
    expect(_tilesWithPrefix('wall-'), findsNWidgets(wallCount));
    expect(_tilesWithPrefix('brick-'), findsNWidgets(brickCount));
    expect(_tilesWithPrefix('floor-'), findsNWidgets(floorCount));
  });

  testWidgets('imports pasted json and opens the custom level', (tester) async {
    await tester.pumpWidget(
      SokobanApp(customLevelStore: await _createTempStore()),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('导入关卡'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText), _importedLevelJson);
    await tester.tap(find.widgetWithText(FilledButton, '导入'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('自定义 1 - 导入测试'), findsOneWidget);

    await tester.tap(find.byTooltip('自定义 1 - 导入测试'));
    await tester.pumpAndSettle();

    expect(find.text('推箱子 - 导入测试'), findsOneWidget);
    expect(find.byType(SokobanBoard), findsOneWidget);
  });
}

int _cellCount(List<String> layout, String symbol) {
  return layout.fold<int>(
    0,
    (count, row) => count + symbol.allMatches(row).length,
  );
}

Finder _tilesWithPrefix(String prefix) {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith(prefix);
  });
}

Future<CustomLevelStore> _createTempStore() async {
  final tempDirectory = await Directory.systemTemp.createTemp(
    'sokoban_widget_test_',
  );
  final storageFile = File(
    '${tempDirectory.path}${Platform.pathSeparator}custom_levels.json',
  );
  addTearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  return CustomLevelStore(storageFile: storageFile);
}

const String _importedLevelJson = '''
{
  "number": 91,
  "title": "导入测试",
  "description": "从测试导入。",
  "layout": [
    "#####",
    "#   #",
    "# B #",
    "# T #",
    "#   #",
    "#####"
  ],
  "initialPlayerPosition": {
    "row": 1,
    "column": 1
  }
}
''';
