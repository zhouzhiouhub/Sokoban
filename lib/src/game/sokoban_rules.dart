import 'dart:collection';

import '../models/board_position.dart';
import '../models/board_tile.dart';

const List<BoardPosition> cardinalDirections = [
  BoardPosition(row: -1, column: 0),
  BoardPosition(row: 1, column: 0),
  BoardPosition(row: 0, column: -1),
  BoardPosition(row: 0, column: 1),
];

class SokobanSearchState {
  SokobanSearchState({
    required this.playerPosition,
    required Set<BoardPosition> brickPositions,
  }) : brickPositions = Set<BoardPosition>.from(brickPositions);

  final BoardPosition playerPosition;
  final Set<BoardPosition> brickPositions;
}

BoardTile tileAt(List<String> layout, int row, int column) {
  return switch (layout[row][column]) {
    '_' => BoardTile.empty,
    '#' => BoardTile.wall,
    _ => BoardTile.floor,
  };
}

Set<BoardPosition> positionsForSymbol(List<String> layout, String symbol) {
  final positions = <BoardPosition>{};

  for (var row = 0; row < layout.length; row++) {
    for (var column = 0; column < layout[row].length; column++) {
      if (layout[row][column] == symbol) {
        positions.add(BoardPosition(row: row, column: column));
      }
    }
  }

  return positions;
}

bool isInsideLayout(List<String> layout, BoardPosition position) {
  if (position.row < 0 || position.row >= layout.length) {
    return false;
  }

  return position.column >= 0 && position.column < layout[position.row].length;
}

bool isFloorTile(List<String> layout, BoardPosition position) {
  return isInsideLayout(layout, position) &&
      tileAt(layout, position.row, position.column) == BoardTile.floor;
}

bool isSolvedState(
  Set<BoardPosition> brickPositions,
  Set<BoardPosition> targetPositions,
) {
  return targetPositions.isNotEmpty &&
      brickPositions.length == targetPositions.length &&
      brickPositions.every(targetPositions.contains);
}

String positionsKey(Iterable<BoardPosition> positions) {
  final sortedPositions = positions.toList()
    ..sort((left, right) {
      final rowCompare = left.row.compareTo(right.row);
      if (rowCompare != 0) {
        return rowCompare;
      }

      return left.column.compareTo(right.column);
    });

  return sortedPositions
      .map((position) => '${position.row},${position.column}')
      .join(';');
}

String searchStateKey(
  BoardPosition playerPosition,
  Set<BoardPosition> brickPositions,
) {
  return '${playerPosition.row},${playerPosition.column}|'
      '${positionsKey(brickPositions)}';
}

Set<BoardPosition> computeDeadTiles(
  List<String> layout,
  Set<BoardPosition> targetPositions,
) {
  final reachablePositions = <BoardPosition>{
    for (final targetPosition in targetPositions)
      if (isFloorTile(layout, targetPosition)) targetPosition,
  };
  final queue = ListQueue<BoardPosition>()..addAll(reachablePositions);

  while (queue.isNotEmpty) {
    final currentPosition = queue.removeFirst();

    for (final direction in cardinalDirections) {
      final previousBoxPosition = currentPosition.move(
        -direction.row,
        -direction.column,
      );
      final playerSupportPosition = previousBoxPosition.move(
        -direction.row,
        -direction.column,
      );

      if (!isFloorTile(layout, previousBoxPosition) ||
          !isFloorTile(layout, playerSupportPosition)) {
        continue;
      }

      if (reachablePositions.add(previousBoxPosition)) {
        queue.add(previousBoxPosition);
      }
    }
  }

  final deadTiles = <BoardPosition>{};

  for (var row = 0; row < layout.length; row++) {
    for (var column = 0; column < layout[row].length; column++) {
      final position = BoardPosition(row: row, column: column);
      if (!isFloorTile(layout, position) ||
          targetPositions.contains(position)) {
        continue;
      }

      if (!reachablePositions.contains(position)) {
        deadTiles.add(position);
      }
    }
  }

  return deadTiles;
}

Set<BoardPosition> computeReachableFloors(
  List<String> layout,
  BoardPosition startPosition,
  Set<BoardPosition> brickPositions,
) {
  if (!isFloorTile(layout, startPosition) ||
      brickPositions.contains(startPosition)) {
    return <BoardPosition>{};
  }

  final reachablePositions = <BoardPosition>{startPosition};
  final queue = ListQueue<BoardPosition>()..add(startPosition);

  while (queue.isNotEmpty) {
    final currentPosition = queue.removeFirst();

    for (final direction in cardinalDirections) {
      final nextPosition = currentPosition.move(
        direction.row,
        direction.column,
      );
      if (!isFloorTile(layout, nextPosition) ||
          brickPositions.contains(nextPosition) ||
          !reachablePositions.add(nextPosition)) {
        continue;
      }

      queue.add(nextPosition);
    }
  }

  return reachablePositions;
}

bool formsFrozenSquareDeadlock(
  List<String> layout,
  Set<BoardPosition> brickPositions,
  Set<BoardPosition> targetPositions,
  BoardPosition anchorPosition,
) {
  final topLeftCandidates = [
    anchorPosition,
    anchorPosition.move(-1, 0),
    anchorPosition.move(0, -1),
    anchorPosition.move(-1, -1),
  ];

  for (final topLeft in topLeftCandidates) {
    final square = [
      topLeft,
      topLeft.move(0, 1),
      topLeft.move(1, 0),
      topLeft.move(1, 1),
    ];

    if (square.any((position) => !isInsideLayout(layout, position))) {
      continue;
    }

    final isFrozenSquare = square.every((position) {
      return tileAt(layout, position.row, position.column) != BoardTile.floor ||
          brickPositions.contains(position);
    });
    if (!isFrozenSquare) {
      continue;
    }

    final hasOffTargetBrick = square.any((position) {
      return brickPositions.contains(position) &&
          !targetPositions.contains(position);
    });
    if (hasOffTargetBrick) {
      return true;
    }
  }

  return false;
}

bool isSokobanStateSolvable({
  required List<String> layout,
  required BoardPosition playerPosition,
  required Set<BoardPosition> brickPositions,
  required Set<BoardPosition> targetPositions,
  required Set<BoardPosition> deadTiles,
}) {
  if (isSolvedState(brickPositions, targetPositions)) {
    return true;
  }

  for (final brickPosition in brickPositions) {
    if (!targetPositions.contains(brickPosition) &&
        deadTiles.contains(brickPosition)) {
      return false;
    }
  }

  final visitedStates = <String>{};
  final queue = ListQueue<SokobanSearchState>();
  final initialState = SokobanSearchState(
    playerPosition: playerPosition,
    brickPositions: brickPositions,
  );

  visitedStates.add(searchStateKey(playerPosition, brickPositions));
  queue.add(initialState);

  while (queue.isNotEmpty) {
    final state = queue.removeFirst();
    if (isSolvedState(state.brickPositions, targetPositions)) {
      return true;
    }

    final reachablePositions = computeReachableFloors(
      layout,
      state.playerPosition,
      state.brickPositions,
    );

    for (final brickPosition in state.brickPositions) {
      for (final direction in cardinalDirections) {
        final playerPushPosition = brickPosition.move(
          -direction.row,
          -direction.column,
        );
        final nextBrickPosition = brickPosition.move(
          direction.row,
          direction.column,
        );

        if (!reachablePositions.contains(playerPushPosition) ||
            !isFloorTile(layout, nextBrickPosition) ||
            state.brickPositions.contains(nextBrickPosition) ||
            (deadTiles.contains(nextBrickPosition) &&
                !targetPositions.contains(nextBrickPosition))) {
          continue;
        }

        final nextBrickPositions = Set<BoardPosition>.from(state.brickPositions)
          ..remove(brickPosition)
          ..add(nextBrickPosition);
        if (formsFrozenSquareDeadlock(
          layout,
          nextBrickPositions,
          targetPositions,
          nextBrickPosition,
        )) {
          continue;
        }

        final nextState = SokobanSearchState(
          playerPosition: brickPosition,
          brickPositions: nextBrickPositions,
        );
        final nextStateKey = searchStateKey(
          nextState.playerPosition,
          nextState.brickPositions,
        );
        if (visitedStates.add(nextStateKey)) {
          queue.add(nextState);
        }
      }
    }
  }

  return false;
}
