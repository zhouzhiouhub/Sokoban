import 'board_position.dart';

class GameSnapshot {
  GameSnapshot({
    required this.playerPosition,
    required Set<BoardPosition> brickPositions,
    required this.stepCount,
  }) : brickPositions = Set<BoardPosition>.from(brickPositions);

  final BoardPosition playerPosition;
  final Set<BoardPosition> brickPositions;
  final int stepCount;
}
