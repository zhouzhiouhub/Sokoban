import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:app/src/levels/custom_level_store.dart';
import 'package:app/src/levels/level_catalog.dart';
import 'package:app/src/levels/sokoban_level_import.dart';

void main() {
  late Directory tempDirectory;
  late File storageFile;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'sokoban_custom_level_store_test_',
    );
    storageFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}custom_levels.json',
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('imports and reloads custom level catalog items', () async {
    final store = CustomLevelStore(
      storageFile: storageFile,
      clock: () => DateTime(2026, 5, 13, 10, 11, 12, 13),
    );

    final importedItem = await store.importLevelJson(_validLevelJson);

    expect(importedItem.id, startsWith('custom_20260513_101112_013'));
    expect(importedItem.source, LevelSource.custom);
    expect(importedItem.level.title, '导入测试');
    expect(await storageFile.exists(), isTrue);

    final reloadedItems = await CustomLevelStore(
      storageFile: storageFile,
    ).loadCatalogItems();

    expect(reloadedItems, hasLength(1));
    expect(reloadedItems.single.id, importedItem.id);
    expect(reloadedItems.single.source, LevelSource.custom);
    expect(reloadedItems.single.level.number, 91);
    expect(reloadedItems.single.level.title, '导入测试');
  });

  test('rejects invalid json without writing a catalog file', () async {
    final store = CustomLevelStore(storageFile: storageFile);

    expect(
      () => store.importLevelJson('{'),
      throwsA(isA<SokobanLevelImportException>()),
    );
    expect(await storageFile.exists(), isFalse);
  });
}

const String _validLevelJson = '''
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
