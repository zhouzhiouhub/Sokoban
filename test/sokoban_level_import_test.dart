import 'package:flutter_test/flutter_test.dart';

import 'package:app/src/levels/sokoban_level_import.dart';

void main() {
  group('parseImportedSokobanLevelJson', () {
    test('parses a generated level json payload', () {
      final level = parseImportedSokobanLevelJson(_validLevelJson);

      expect(level.number, 41);
      expect(level.title, '自定义关卡');
      expect(level.description, '把箱子推到目标点。');
      expect(level.layout, hasLength(6));
      expect(level.initialPlayerPosition.row, 1);
      expect(level.initialPlayerPosition.column, 1);
    });

    test('uses fallback title when the imported title is blank', () {
      final level = parseImportedSokobanLevelJson(
        _validLevelJson.replaceFirst('"自定义关卡"', '"   "'),
      );

      expect(level.title, '自定义关卡');
    });

    test('rejects invalid json', () {
      expect(
        () => parseImportedSokobanLevelJson('{'),
        throwsA(isA<SokobanLevelImportException>()),
      );
    });

    test('rejects missing required fields', () {
      expect(
        () => parseImportedSokobanLevelJson('{"number": 1}'),
        throwsA(
          isA<SokobanLevelImportException>().having(
            (error) => error.message,
            'message',
            contains('title'),
          ),
        ),
      );
    });

    test('rejects non-rectangular layouts', () {
      expect(
        () => parseImportedSokobanLevelJson(
          _validLevelJson.replaceFirst('"#####"', '"####"'),
        ),
        throwsA(
          isA<SokobanLevelImportException>().having(
            (error) => error.message,
            'message',
            contains('长度与第 1 行不一致'),
          ),
        ),
      );
    });

    test('rejects illegal layout symbols', () {
      expect(
        () => parseImportedSokobanLevelJson(
          _validLevelJson.replaceFirst('"# B #"', '"# X #"'),
        ),
        throwsA(
          isA<SokobanLevelImportException>().having(
            (error) => error.message,
            'message',
            contains('非法字符'),
          ),
        ),
      );
    });

    test('rejects mismatched box and target counts', () {
      expect(
        () => parseImportedSokobanLevelJson(
          _validLevelJson.replaceFirst('"#   #"', '"# T #"'),
        ),
        throwsA(
          isA<SokobanLevelImportException>().having(
            (error) => error.message,
            'message',
            contains('箱子数量必须与目标点数量一致'),
          ),
        ),
      );
    });

    test('rejects player positions on walls', () {
      expect(
        () => parseImportedSokobanLevelJson(
          _validLevelJson.replaceFirst(
            '"row": 1,\n    "column": 1',
            '"row": 0,\n    "column": 0',
          ),
        ),
        throwsA(
          isA<SokobanLevelImportException>().having(
            (error) => error.message,
            'message',
            contains('可通行地块'),
          ),
        ),
      );
    });

    test('rejects player positions on boxes', () {
      expect(
        () => parseImportedSokobanLevelJson(
          _validLevelJson.replaceFirst(
            '"row": 1,\n    "column": 1',
            '"row": 2,\n    "column": 2',
          ),
        ),
        throwsA(
          isA<SokobanLevelImportException>().having(
            (error) => error.message,
            'message',
            contains('不能和箱子重叠'),
          ),
        ),
      );
    });

    test('rejects oversized layouts', () {
      expect(
        () => parseImportedSokobanLevelJson(
          _validLevelJson,
          options: const SokobanLevelValidationOptions(maxRows: 4),
        ),
        throwsA(
          isA<SokobanLevelImportException>().having(
            (error) => error.message,
            'message',
            contains('最多支持 4 行'),
          ),
        ),
      );
    });

    test('treats star cells as both box and target cells', () {
      final level = parseImportedSokobanLevelJson(_levelWithBoxOnTargetJson);

      expect(level.layout[1][2], '*');
      expect(level.initialPlayerPosition.row, 2);
      expect(level.initialPlayerPosition.column, 2);
    });
  });
}

const String _validLevelJson = '''
{
  "number": 41,
  "title": "自定义关卡",
  "description": "把箱子推到目标点。",
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

const String _levelWithBoxOnTargetJson = '''
{
  "number": 42,
  "title": "已完成关卡",
  "description": "箱子已经在目标点上。",
  "layout": [
    "#####",
    "# * #",
    "#   #",
    "#####"
  ],
  "initialPlayerPosition": {
    "row": 2,
    "column": 2
  }
}
''';
