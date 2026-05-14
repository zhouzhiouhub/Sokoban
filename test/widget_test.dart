import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/src/game/sokoban_rules.dart';
import 'package:app/src/levels/custom_level_store.dart';
import 'package:app/src/levels/level_catalog.dart';
import 'package:app/src/levels/sokoban_level_import.dart';
import 'package:app/src/levels/sokoban_levels.dart';
import 'package:app/src/sokoban_app.dart';
import 'package:app/src/ui/level_selection_page.dart';
import 'package:app/src/ui/sokoban_board.dart';
import 'package:app/src/ui/sokoban_wall_page.dart';

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

      final viewportSize = SokobanBoard.viewportSizeForLayout(level.layout);
      expect(
        viewportSize.rows,
        greaterThanOrEqualTo(level.layout.length),
        reason: '${level.displayName} must fit vertically in the board.',
      );
      expect(
        viewportSize.columns,
        greaterThanOrEqualTo(expectedColumnCount),
        reason: '${level.displayName} must fit horizontally in the board.',
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

  test('board viewport size follows the layout dimensions', () {
    final smallViewport = SokobanBoard.viewportSizeForLayout(
      List<String>.filled(5, '#####'),
    );
    final wideViewport = SokobanBoard.viewportSizeForLayout(
      List<String>.filled(3, '#######################'),
    );

    expect(smallViewport.rows, 5);
    expect(smallViewport.columns, 5);
    expect(wideViewport.rows, 3);
    expect(wideViewport.columns, 23);
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
    await tester.pumpWidget(SokobanApp(customLevelStore: _MemoryLevelStore()));
    await tester.pump();

    expect(find.byType(LevelSelectionPage), findsOneWidget);
    expect(find.text('选择关卡'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('${sokobanLevels.length}'), findsOneWidget);
  });

  testWidgets('opens a selected Sokoban level', (tester) async {
    await tester.pumpWidget(SokobanApp(customLevelStore: _MemoryLevelStore()));
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

  testWidgets('renders every cell for a wide designed level', (tester) async {
    final levelIndex = sokobanLevels.indexWhere((level) => level.number == 19);
    final level = sokobanLevels[levelIndex];

    await tester.pumpWidget(
      MaterialApp(home: SokobanWallPage(initialLevelIndex: levelIndex)),
    );

    final viewportSize = SokobanBoard.viewportSizeForLayout(level.layout);
    expect(viewportSize.rows, level.layout.length);
    expect(viewportSize.columns, level.layout.first.length);
    expect(_sokobanTileKeys(), findsNWidgets(_layoutCellCount(level.layout)));
  });

  testWidgets('imports pasted json and opens the custom level', (tester) async {
    await tester.pumpWidget(SokobanApp(customLevelStore: _MemoryLevelStore()));
    await tester.pump();

    await tester.tap(find.byTooltip('导入关卡'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText), _importedLevelJson);
    await tester.tap(find.widgetWithText(FilledButton, '导入'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
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

Finder _sokobanTileKeys() {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.split('-').length == 4;
  });
}

int _layoutCellCount(List<String> layout) {
  return layout.fold<int>(0, (count, row) => count + row.length);
}

class _MemoryLevelStore extends CustomLevelStore {
  _MemoryLevelStore() : super(storageFile: File('unused_custom_levels.json'));

  final List<LevelCatalogItem> _items = [];

  @override
  Future<List<LevelCatalogItem>> loadCatalogItems() async {
    return List<LevelCatalogItem>.unmodifiable(_items);
  }

  @override
  Future<LevelCatalogItem> importLevelJson(String source) async {
    final level = parseImportedSokobanLevelJson(source);
    final item = LevelCatalogItem(
      id: 'custom_test_${_items.length + 1}',
      source: LevelSource.custom,
      level: level,
    );
    _items.add(item);
    return item;
  }
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
