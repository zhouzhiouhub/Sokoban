import 'dart:io';

import 'package:app/src/game/sokoban_rules.dart';
import 'package:app/src/levels/sokoban_level_import.dart';
import 'package:app/src/models/board_position.dart';
import 'package:app/src/models/sokoban_level.dart';

const SokobanLevelValidationOptions _generatedLevelValidationOptions =
    SokobanLevelValidationOptions(validateInitialDeadTiles: false);
const String _defaultSolutionDirectoryPath = 'tools/solution_levels';

void main(List<String> arguments) {
  final selectedLevelNumbers = _selectedLevelNumbers(arguments);
  final maxVisitedStates = _intOption(
    arguments,
    '--max-visited',
    fallback: 250000,
  );
  final outputDirectoryPath =
      _stringOption(arguments, '--output-dir') ?? _defaultSolutionDirectoryPath;
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
    _writeSolutionFiles(
      solvedLevels,
      outputDirectoryPath: outputDirectoryPath,
      removeStaleFiles: selectedLevelNumbers.isEmpty,
    );
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

String? _stringOption(List<String> arguments, String option) {
  final optionIndex = arguments.indexOf(option);
  if (optionIndex < 0 || optionIndex + 1 >= arguments.length) {
    return null;
  }

  return arguments[optionIndex + 1];
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

void _writeSolutionFiles(
  Map<int, List<SokobanPushHint>> solutions, {
  required String outputDirectoryPath,
  required bool removeStaleFiles,
}) {
  final directory = Directory(outputDirectoryPath)..createSync(recursive: true);
  if (removeStaleFiles) {
    final staleSolutionFiles = directory.listSync().whereType<File>().where(
      (file) => _solutionFileNamePattern.hasMatch(_fileName(file)),
    );
    for (final file in staleSolutionFiles) {
      file.deleteSync();
    }
  }

  final levelNumbers = solutions.keys.toList()..sort();
  for (final levelNumber in levelNumbers) {
    final outputFile = File(
      '${directory.path}${Platform.pathSeparator}${_solutionFileName(levelNumber)}',
    );
    outputFile.writeAsStringSync(_renderSolutionFile(solutions[levelNumber]!));
    stdout.writeln('Wrote ${outputFile.path}');
  }
}

final RegExp _solutionFileNamePattern = RegExp(r'^level_\d{3}\.txt$');

String _fileName(File file) {
  return file.path.split(RegExp(r'[\\/]')).last;
}

String _solutionFileName(int levelNumber) {
  return 'level_${levelNumber.toString().padLeft(3, '0')}.txt';
}

String _renderSolutionFile(List<SokobanPushHint> solution) {
  return '${solution.map(_encodePush).join(';')}\n';
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
