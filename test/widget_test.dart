import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/src/app_branding.dart';
import 'package:app/src/game/sokoban_rules.dart';
import 'package:app/src/levels/custom_level_store.dart';
import 'package:app/src/levels/level_catalog.dart';
import 'package:app/src/levels/sokoban_level_import.dart';
import 'package:app/src/levels/sokoban_levels.dart';
import 'package:app/src/models/sokoban_level.dart';
import 'package:app/src/sokoban_app.dart';
import 'package:app/src/ui/level_selection_page.dart';
import 'package:app/src/ui/sokoban_board.dart';
import 'package:app/src/ui/sokoban_wall_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<SokobanLevel> generatedLevels;

  setUpAll(() async {
    generatedLevels = await loadSokobanLevels();
  });

  test('has generated levels with valid basic structure', () {
    expect(generatedLevels, isNotEmpty);

    for (final level in generatedLevels) {
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
        greaterThan(0),
        reason: '${level.displayName} must have a visible board height.',
      );
      expect(
        viewportSize.columns,
        greaterThan(0),
        reason: '${level.displayName} must have a visible board width.',
      );
      expect(
        viewportSize.rows,
        lessThanOrEqualTo(level.layout.length),
        reason: '${level.displayName} should hide padded rows.',
      );
      expect(
        viewportSize.columns,
        lessThanOrEqualTo(expectedColumnCount),
        reason: '${level.displayName} should hide padded columns.',
      );
    }
  });

  test('generated levels are sorted by level number', () {
    for (var index = 1; index < generatedLevels.length; index++) {
      expect(
        generatedLevels[index].number,
        greaterThanOrEqualTo(generatedLevels[index - 1].number),
      );
    }
  });

  test('board viewport size follows visible layout dimensions', () {
    final smallViewport = SokobanBoard.viewportSizeForLayout(
      List<String>.filled(5, '#####'),
    );
    final wideViewport = SokobanBoard.viewportSizeForLayout(
      List<String>.filled(3, '#######################'),
    );
    final paddedViewport = SokobanBoard.viewportSizeForLayout(const [
      '       ',
      '  ###  ',
      '  #T#  ',
      '  ###  ',
      '       ',
    ]);

    expect(smallViewport.rows, 5);
    expect(smallViewport.columns, 5);
    expect(wideViewport.rows, 3);
    expect(wideViewport.columns, 23);
    expect(paddedViewport.rows, 3);
    expect(paddedViewport.columns, 3);
  });

  test('generated levels can be wrapped in the built-in catalog', () {
    final catalog = buildBuiltInLevelCatalog(generatedLevels);

    expect(catalog, hasLength(generatedLevels.length));
    expect(catalog.every((item) => item.source == LevelSource.builtIn), isTrue);
  });

  testWidgets('renders the level selection page', (tester) async {
    await tester.pumpWidget(SokobanApp(customLevelStore: _MemoryLevelStore()));
    await _pumpUntilFound(tester, find.text('1'));

    expect(find.byType(LevelSelectionPage), findsOneWidget);
    expect(find.text(appName), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(
      find.text('${generatedLevels.last.number}'),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('opens a selected Sokoban level', (tester) async {
    await tester.pumpWidget(SokobanApp(customLevelStore: _MemoryLevelStore()));
    final secondLevelTooltip = find.byTooltip(
      '第 ${generatedLevels[1].number} 关 - ${generatedLevels[1].title}',
    );
    await _pumpUntilFound(tester, secondLevelTooltip);

    await tester.tap(secondLevelTooltip);
    await tester.pumpAndSettle();

    final level = generatedLevels[1];

    expect(find.text(appLevelTitle(level.title)), findsOneWidget);
    expect(find.text('第 ${level.number} 关'), findsOneWidget);
    expect(find.text('切换关卡'), findsNothing);
    expect(find.byType(SokobanBoard), findsOneWidget);

    final emptyCount = _visibleCellCount(level.layout, '_');
    final wallCount = _visibleCellCount(level.layout, '#');
    final brickCount = positionsForSymbol(level.layout, 'B').length;
    final cellCount = _visibleCellCount(level.layout);
    final floorCount = cellCount - emptyCount - wallCount - brickCount;

    expect(_tilesWithPrefix('empty-'), findsNWidgets(emptyCount));
    expect(_tilesWithPrefix('wall-'), findsNWidgets(wallCount));
    expect(_tilesWithPrefix('brick-'), findsNWidgets(brickCount));
    expect(_tilesWithPrefix('floor-'), findsNWidgets(floorCount));
  });

  testWidgets(
    'opens the selected level while custom levels are still loading',
    (tester) async {
      await tester.pumpWidget(
        SokobanApp(customLevelStore: _PendingLevelStore()),
      );
      final secondLevelTooltip = find.byTooltip(
        '第 ${generatedLevels[1].number} 关 - ${generatedLevels[1].title}',
      );
      await _pumpUntilFound(tester, secondLevelTooltip);

      await tester.tap(secondLevelTooltip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final level = generatedLevels[1];

      expect(find.text(appLevelTitle(level.title)), findsOneWidget);
      expect(find.text('第 ${level.number} 关'), findsOneWidget);
      expect(find.text('第 1 关'), findsNothing);
    },
  );

  testWidgets('renders every visible cell for a wide designed level', (
    tester,
  ) async {
    final levelIndex = generatedLevels.indexWhere(
      (level) => level.number == 19,
    );
    expect(levelIndex, isNot(-1));
    final level = generatedLevels[levelIndex];

    await tester.pumpWidget(
      MaterialApp(
        home: SokobanWallPage(
          initialLevelIndex: levelIndex,
          levelCatalog: buildBuiltInLevelCatalog(generatedLevels),
        ),
      ),
    );

    final viewportSize = SokobanBoard.viewportSizeForLayout(level.layout);
    final viewportRegion = SokobanBoard.viewportRegionForLayout(level.layout);
    expect(viewportSize.rows, viewportRegion.rows);
    expect(viewportSize.columns, viewportRegion.columns);
    expect(_sokobanTileKeys(), findsNWidgets(_visibleCellCount(level.layout)));
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

    expect(find.text(appLevelTitle('导入测试')), findsOneWidget);
    expect(find.byType(SokobanBoard), findsOneWidget);
  });
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

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }

  expect(finder, findsOneWidget);
}

int _visibleCellCount(List<String> layout, [String? symbol]) {
  final region = SokobanBoard.viewportRegionForLayout(layout);
  var count = 0;

  for (var row = region.firstRow; row <= region.lastRow; row++) {
    final line = layout[row];
    if (region.firstColumn >= line.length) {
      continue;
    }

    final lastColumn = region.lastColumn < line.length
        ? region.lastColumn
        : line.length - 1;
    for (var column = region.firstColumn; column <= lastColumn; column++) {
      if (symbol == null || line[column] == symbol) {
        count += 1;
      }
    }
  }

  return count;
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

class _PendingLevelStore extends CustomLevelStore {
  _PendingLevelStore() : super(storageFile: File('unused_custom_levels.json'));

  final Completer<List<LevelCatalogItem>> _loadCompleter = Completer();

  @override
  Future<List<LevelCatalogItem>> loadCatalogItems() {
    return _loadCompleter.future;
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
