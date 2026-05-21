import '../game/sokoban_rules.dart';
import '../models/board_position.dart';

const Map<int, List<String>> _encodedBuiltInSokobanStandardSolutions = {};

final Map<int, List<SokobanPushHint>> _decodedBuiltInSokobanStandardSolutions =
    <int, List<SokobanPushHint>>{};

List<SokobanPushHint> builtInSokobanStandardSolution(int levelNumber) {
  return _decodedBuiltInSokobanStandardSolutions.putIfAbsent(levelNumber, () {
    final encodedSolution =
        _encodedBuiltInSokobanStandardSolutions[levelNumber];
    if (encodedSolution == null) {
      return const <SokobanPushHint>[];
    }

    return encodedSolution.map(_decodePushHint).toList(growable: false);
  });
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
