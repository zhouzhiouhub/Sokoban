import 'package:flutter/services.dart';

import '../game/sokoban_rules.dart';
import '../models/board_position.dart';

const String sokobanSolutionAssetDirectory = 'tools/solution_levels/';

Future<Map<int, List<SokobanPushHint>>> loadBuiltInSokobanStandardSolutions({
  AssetBundle? bundle,
}) async {
  final effectiveBundle = bundle ?? rootBundle;
  final manifest = await AssetManifest.loadFromAssetBundle(effectiveBundle);
  final solutionAssets =
      manifest.listAssets().where(_isStandardSolutionAsset).toList()..sort();

  final solutions = <int, List<SokobanPushHint>>{};
  for (final assetPath in solutionAssets) {
    final levelNumber = _levelNumberFromSolutionAsset(assetPath);
    if (levelNumber == null) {
      continue;
    }

    final source = await effectiveBundle.loadString(assetPath);
    final solution = parseSokobanStandardSolution(source);
    if (solution.isNotEmpty) {
      solutions[levelNumber] = solution;
    }
  }

  return Map<int, List<SokobanPushHint>>.unmodifiable(solutions);
}

List<SokobanPushHint> parseSokobanStandardSolution(String source) {
  final trimmedSource = source.trim();
  if (trimmedSource.isEmpty) {
    return const <SokobanPushHint>[];
  }

  return trimmedSource
      .split(RegExp(r'[;\s]+'))
      .where((encodedPush) => encodedPush.isNotEmpty)
      .map(_decodePushHint)
      .toList(growable: false);
}

bool _isStandardSolutionAsset(String assetPath) {
  return assetPath.startsWith(sokobanSolutionAssetDirectory) &&
      assetPath.endsWith('.txt');
}

int? _levelNumberFromSolutionAsset(String assetPath) {
  final fileName = assetPath.split('/').last;
  final match = RegExp(r'^level_(\d+)\.txt$').firstMatch(fileName);
  if (match == null) {
    return null;
  }

  return int.parse(match.group(1)!);
}

SokobanPushHint _decodePushHint(String encodedPush) {
  final parts = encodedPush.split(',');
  if (parts.length != 3) {
    throw FormatException('Invalid Sokoban push hint: $encodedPush');
  }

  return SokobanPushHint(
    brickPosition: BoardPosition(
      row: int.parse(parts[0]),
      column: int.parse(parts[1]),
    ),
    direction: _decodeDirection(parts[2]),
  );
}

BoardPosition _decodeDirection(String value) {
  return switch (value) {
    'U' => const BoardPosition(row: -1, column: 0),
    'D' => const BoardPosition(row: 1, column: 0),
    'L' => const BoardPosition(row: 0, column: -1),
    'R' => const BoardPosition(row: 0, column: 1),
    _ => throw FormatException('Invalid Sokoban push direction: $value'),
  };
}
