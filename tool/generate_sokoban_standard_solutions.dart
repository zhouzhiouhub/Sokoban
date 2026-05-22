import 'dart:io';

import 'package:app/src/game/sokoban_rules.dart';
import 'package:app/src/levels/sokoban_level_import.dart';
import 'package:app/src/models/board_position.dart';
import 'package:app/src/models/sokoban_level.dart';

const SokobanLevelValidationOptions _generatedLevelValidationOptions =
    SokobanLevelValidationOptions(validateInitialDeadTiles: false);

void main(List<String> arguments) {
  final selectedLevelNumbers = _selectedLevelNumbers(arguments);
  final maxVisitedStates = _intOption(
    arguments,
    '--max-visited',
    fallback: 250000,
  );
  final writeFile = !arguments.contains('--check');

  final solvedLevels = <int, List<SokobanPushHint>>{};
  final failedLevels = <String>[];

  for (final level in _loadGeneratedLevels()) {
    if (selectedLevelNumbers.isNotEmpty &&
        !selectedLevelNumbers.contains(level.number)) {
      continue;
    }

    final result = _solveLevel(level, maxVisitedStates: maxVisitedStates);
    if (result.status == SokobanHintSearchStatus.found) {
      solvedLevels[level.number] = result.solution;
      stdout.writeln('Level ${level.number}: ${result.solution.length} pushes');
    } else {
      failedLevels.add('Level ${level.number}: ${result.status.name}');
      stdout.writeln(failedLevels.last);
    }
  }

  if (writeFile) {
    File(
      'lib/src/levels/sokoban_standard_solutions.dart',
    ).writeAsStringSync(_renderSolutionsFile(solvedLevels));
  }

  if (failedLevels.isNotEmpty) {
    stderr.writeln('Unsolved levels:');
    for (final failedLevel in failedLevels) {
      stderr.writeln(failedLevel);
    }
    exitCode = 1;
  }
}

List<SokobanLevel> _loadGeneratedLevels() {
  final directory = Directory('tools/generated_levels');
  if (!directory.existsSync()) {
    throw StateError('Missing tools/generated_levels directory.');
  }

  final files =
      directory
          .listSync()
          .whereType<File>()
          .where(_isGeneratedLevelFile)
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  if (files.isEmpty) {
    throw StateError('No generated level files found.');
  }

  final levels =
      files
          .map(
            (file) => (
              path: file.path,
              level: _parseGeneratedLevelFile(
                file.path,
                file.readAsStringSync(),
              ),
            ),
          )
          .toList()
        ..sort((a, b) {
          final numberOrder = a.level.number.compareTo(b.level.number);
          if (numberOrder != 0) {
            return numberOrder;
          }

          return a.path.compareTo(b.path);
        });

  return levels.map((loadedLevel) => loadedLevel.level).toList(growable: false);
}

bool _isGeneratedLevelFile(File file) {
  return file.path.endsWith('.json') || file.path.endsWith('.dart.txt');
}

SokobanLevel _parseGeneratedLevelFile(String path, String source) {
  try {
    if (path.endsWith('.json')) {
      return parseImportedSokobanLevelJson(
        source,
        options: _generatedLevelValidationOptions,
      );
    }

    return parseGeneratedSokobanLevelDartSnippet(
      source,
      options: _generatedLevelValidationOptions,
    );
  } on SokobanLevelImportException catch (error) {
    throw FormatException('Generated level $path is invalid: ${error.message}');
  }
}

Set<int> _selectedLevelNumbers(List<String> arguments) {
  final values = <int>{};
  for (var index = 0; index < arguments.length; index++) {
    if (arguments[index] != '--level' || index + 1 >= arguments.length) {
      continue;
    }

    values.add(int.parse(arguments[index + 1]));
  }

  return values;
}

int _intOption(List<String> arguments, String option, {required int fallback}) {
  final optionIndex = arguments.indexOf(option);
  if (optionIndex < 0 || optionIndex + 1 >= arguments.length) {
    return fallback;
  }

  return int.parse(arguments[optionIndex + 1]);
}

SokobanHintSearchResult _solveLevel(
  SokobanLevel level, {
  required int maxVisitedStates,
}) {
  final targetPositions = positionsForSymbol(level.layout, 'T');
  return findNextSokobanPushHint(
    layout: level.layout,
    playerPosition: level.initialPlayerPosition,
    brickPositions: positionsForSymbol(level.layout, 'B'),
    targetPositions: targetPositions,
    deadTiles: computeDeadTiles(level.layout, targetPositions),
    maxVisitedStates: maxVisitedStates,
  );
}

String _renderSolutionsFile(Map<int, List<SokobanPushHint>> solutions) {
  final buffer = StringBuffer()
    ..writeln("import '../game/sokoban_rules.dart';")
    ..writeln("import '../models/board_position.dart';")
    ..writeln()
    ..writeln(
      'const Map<int, List<String>> '
      '_encodedBuiltInSokobanStandardSolutions = {',
    );

  final levelNumbers = solutions.keys.toList()..sort();
  for (final levelNumber in levelNumbers) {
    buffer.writeln('  $levelNumber: [');
    for (final push in solutions[levelNumber]!) {
      buffer.writeln("    '${_encodePush(push)}',");
    }
    buffer.writeln('  ],');
  }

  buffer
    ..writeln('};')
    ..writeln()
    ..writeln(
      'final Map<int, List<SokobanPushHint>> '
      '_decodedBuiltInSokobanStandardSolutions =',
    )
    ..writeln('    <int, List<SokobanPushHint>>{};')
    ..writeln()
    ..writeln('List<SokobanPushHint> builtInSokobanStandardSolution(')
    ..writeln('  int levelNumber,')
    ..writeln(') {')
    ..writeln('  return _decodedBuiltInSokobanStandardSolutions.putIfAbsent(')
    ..writeln('    levelNumber,')
    ..writeln('    () {')
    ..writeln('      final encodedSolution =')
    ..writeln('          _encodedBuiltInSokobanStandardSolutions[levelNumber];')
    ..writeln('      if (encodedSolution == null) {')
    ..writeln('        return const <SokobanPushHint>[];')
    ..writeln('      }')
    ..writeln()
    ..writeln('      return encodedSolution.map(_decodePushHint).toList(')
    ..writeln('        growable: false,')
    ..writeln('      );')
    ..writeln('    },')
    ..writeln('  );')
    ..writeln('}')
    ..writeln()
    ..writeln('SokobanPushHint _decodePushHint(String encodedPush) {')
    ..writeln("  final parts = encodedPush.split(',');")
    ..writeln('  if (parts.length != 3) {')
    ..writeln(
      "    throw FormatException('Invalid Sokoban push hint: "
      r"$encodedPush');",
    )
    ..writeln('  }')
    ..writeln()
    ..writeln('  return SokobanPushHint(')
    ..writeln('    brickPosition: BoardPosition(')
    ..writeln('      row: int.parse(parts[0]),')
    ..writeln('      column: int.parse(parts[1]),')
    ..writeln('    ),')
    ..writeln('    direction: _decodeDirection(parts[2]),')
    ..writeln('  );')
    ..writeln('}')
    ..writeln()
    ..writeln('BoardPosition _decodeDirection(String value) {')
    ..writeln('  return switch (value) {')
    ..writeln("    'U' => const BoardPosition(row: -1, column: 0),")
    ..writeln("    'D' => const BoardPosition(row: 1, column: 0),")
    ..writeln("    'L' => const BoardPosition(row: 0, column: -1),")
    ..writeln("    'R' => const BoardPosition(row: 0, column: 1),")
    ..writeln(
      "    _ => throw FormatException('Invalid Sokoban push direction: "
      r"$value'),",
    )
    ..writeln('  };')
    ..writeln('}');

  return buffer.toString();
}

String _encodePush(SokobanPushHint push) {
  return '${push.brickPosition.row},${push.brickPosition.column},'
      '${_encodeDirection(push.direction)}';
}

String _encodeDirection(BoardPosition direction) {
  if (direction.row < 0) {
    return 'U';
  }
  if (direction.row > 0) {
    return 'D';
  }
  if (direction.column < 0) {
    return 'L';
  }

  return 'R';
}
