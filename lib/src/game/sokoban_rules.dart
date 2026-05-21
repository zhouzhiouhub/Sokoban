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

enum SokobanHintSearchStatus {
  alreadySolved,
  found,
  noSolution,
  searchLimitReached,
}

class SokobanPushHint {
  const SokobanPushHint({required this.brickPosition, required this.direction});

  final BoardPosition brickPosition;
  final BoardPosition direction;

  BoardPosition get playerPushPosition {
    return brickPosition.move(-direction.row, -direction.column);
  }

  BoardPosition get nextBrickPosition {
    return brickPosition.move(direction.row, direction.column);
  }
}

class SokobanHintSearchResult {
  const SokobanHintSearchResult._({
    required this.status,
    this.hint,
    this.solution = const [],
  });

  const SokobanHintSearchResult.alreadySolved()
    : this._(status: SokobanHintSearchStatus.alreadySolved);

  SokobanHintSearchResult.found(
    SokobanPushHint hint, {
    List<SokobanPushHint>? solution,
  }) : this._(
         status: SokobanHintSearchStatus.found,
         hint: hint,
         solution: solution ?? <SokobanPushHint>[hint],
       );

  const SokobanHintSearchResult.noSolution()
    : this._(status: SokobanHintSearchStatus.noSolution);

  const SokobanHintSearchResult.searchLimitReached()
    : this._(status: SokobanHintSearchStatus.searchLimitReached);

  final SokobanHintSearchStatus status;
  final SokobanPushHint? hint;
  final List<SokobanPushHint> solution;
}

class _SokobanHintSearchNode extends SokobanSearchState {
  _SokobanHintSearchNode({
    required super.playerPosition,
    required super.brickPositions,
    required this.pushCount,
    required this.priority,
    required this.sequence,
    this.parent,
    this.lastPush,
  });

  final int pushCount;
  final int priority;
  final int sequence;
  final _SokobanHintSearchNode? parent;
  final SokobanPushHint? lastPush;
}

class SokobanHintPathIndex {
  const SokobanHintPathIndex._(this._nextPushByStateKey);

  factory SokobanHintPathIndex.fromSolution({
    required List<String> layout,
    required BoardPosition initialPlayerPosition,
    required Set<BoardPosition> initialBrickPositions,
    required List<SokobanPushHint> solution,
  }) {
    final nextPushByStateKey = <String, SokobanPushHint>{};
    var playerPosition = initialPlayerPosition;
    var brickPositions = Set<BoardPosition>.from(initialBrickPositions);

    for (final push in solution) {
      if (!isValidSokobanPush(
        layout: layout,
        playerPosition: playerPosition,
        brickPositions: brickPositions,
        push: push,
      )) {
        return const SokobanHintPathIndex._(<String, SokobanPushHint>{});
      }

      final stateKey = normalisedSearchStateKey(
        layout,
        playerPosition,
        brickPositions,
      );
      nextPushByStateKey[stateKey] = push;

      brickPositions = applySokobanPush(brickPositions, push);
      playerPosition = push.brickPosition;
    }

    return SokobanHintPathIndex._(
      Map<String, SokobanPushHint>.unmodifiable(nextPushByStateKey),
    );
  }

  final Map<String, SokobanPushHint> _nextPushByStateKey;

  bool get isEmpty => _nextPushByStateKey.isEmpty;

  SokobanPushHint? hintForState({
    required List<String> layout,
    required BoardPosition playerPosition,
    required Set<BoardPosition> brickPositions,
  }) {
    final stateKey = normalisedSearchStateKey(
      layout,
      playerPosition,
      brickPositions,
    );
    final hint = _nextPushByStateKey[stateKey];
    if (hint == null ||
        !isValidSokobanPush(
          layout: layout,
          playerPosition: playerPosition,
          brickPositions: brickPositions,
          push: hint,
        )) {
      return null;
    }

    return hint;
  }
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
      if (_cellMatchesSymbol(layout[row][column], symbol)) {
        positions.add(BoardPosition(row: row, column: column));
      }
    }
  }

  return positions;
}

bool _cellMatchesSymbol(String cell, String symbol) {
  return switch (symbol) {
    'B' => cell == 'B' || cell == '*',
    'T' => cell == 'T' || cell == '*',
    _ => cell == symbol,
  };
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

String normalisedSearchStateKey(
  List<String> layout,
  BoardPosition playerPosition,
  Set<BoardPosition> brickPositions,
) {
  return searchStateKey(
    canonicalReachablePosition(layout, playerPosition, brickPositions),
    brickPositions,
  );
}

BoardPosition canonicalReachablePosition(
  List<String> layout,
  BoardPosition playerPosition,
  Set<BoardPosition> brickPositions,
) {
  final reachablePositions = computeReachableFloors(
    layout,
    playerPosition,
    brickPositions,
  );
  if (reachablePositions.isEmpty) {
    return playerPosition;
  }

  return reachablePositions.reduce((bestPosition, position) {
    final rowCompare = position.row.compareTo(bestPosition.row);
    if (rowCompare < 0 ||
        (rowCompare == 0 && position.column < bestPosition.column)) {
      return position;
    }

    return bestPosition;
  });
}

bool isValidSokobanPush({
  required List<String> layout,
  required BoardPosition playerPosition,
  required Set<BoardPosition> brickPositions,
  required SokobanPushHint push,
}) {
  if (!brickPositions.contains(push.brickPosition) ||
      !isFloorTile(layout, push.nextBrickPosition) ||
      brickPositions.contains(push.nextBrickPosition)) {
    return false;
  }

  return computeReachableFloors(
    layout,
    playerPosition,
    brickPositions,
  ).contains(push.playerPushPosition);
}

Set<BoardPosition> applySokobanPush(
  Set<BoardPosition> brickPositions,
  SokobanPushHint push,
) {
  return Set<BoardPosition>.from(brickPositions)
    ..remove(push.brickPosition)
    ..add(push.nextBrickPosition);
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

      if (!reachablePositions.contains(position) ||
          isNonTargetCornerDeadlock(layout, targetPositions, position)) {
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

bool isNonTargetCornerDeadlock(
  List<String> layout,
  Set<BoardPosition> targetPositions,
  BoardPosition position,
) {
  if (targetPositions.contains(position) || !isFloorTile(layout, position)) {
    return false;
  }

  final blockedAbove = _isStaticBlocker(layout, position.move(-1, 0));
  final blockedBelow = _isStaticBlocker(layout, position.move(1, 0));
  final blockedLeft = _isStaticBlocker(layout, position.move(0, -1));
  final blockedRight = _isStaticBlocker(layout, position.move(0, 1));

  return (blockedAbove || blockedBelow) && (blockedLeft || blockedRight);
}

bool hasSokobanDeadlock({
  required List<String> layout,
  required Set<BoardPosition> brickPositions,
  required Set<BoardPosition> targetPositions,
  required Set<BoardPosition> deadTiles,
  BoardPosition? movedBrickPosition,
}) {
  if (isSolvedState(brickPositions, targetPositions)) {
    return false;
  }

  for (final brickPosition in brickPositions) {
    if (targetPositions.contains(brickPosition)) {
      continue;
    }

    if (deadTiles.contains(brickPosition) ||
        isNonTargetCornerDeadlock(layout, targetPositions, brickPosition)) {
      return true;
    }
  }

  if (movedBrickPosition != null) {
    if (formsFrozenSquareDeadlock(
          layout,
          brickPositions,
          targetPositions,
          movedBrickPosition,
        ) ||
        formsFreezeDeadlock(
          layout: layout,
          brickPositions: brickPositions,
          targetPositions: targetPositions,
          deadTiles: deadTiles,
          anchorPosition: movedBrickPosition,
        )) {
      return true;
    }
  } else {
    for (final brickPosition in brickPositions) {
      if (formsFrozenSquareDeadlock(
            layout,
            brickPositions,
            targetPositions,
            brickPosition,
          ) ||
          formsFreezeDeadlock(
            layout: layout,
            brickPositions: brickPositions,
            targetPositions: targetPositions,
            deadTiles: deadTiles,
            anchorPosition: brickPosition,
          )) {
        return true;
      }
    }
  }

  return false;
}

bool formsFreezeDeadlock({
  required List<String> layout,
  required Set<BoardPosition> brickPositions,
  required Set<BoardPosition> targetPositions,
  required Set<BoardPosition> deadTiles,
  required BoardPosition anchorPosition,
}) {
  final affectedBoxes = _freezeConnectedBoxes(brickPositions, anchorPosition);
  for (final brickPosition in affectedBoxes) {
    if (targetPositions.contains(brickPosition)) {
      continue;
    }

    final probe = _FreezeProbe(layout, brickPositions, deadTiles);
    if (probe.isFrozen(brickPosition)) {
      return true;
    }
  }

  return false;
}

Set<BoardPosition> _freezeConnectedBoxes(
  Set<BoardPosition> brickPositions,
  BoardPosition anchorPosition,
) {
  if (!brickPositions.contains(anchorPosition)) {
    return const <BoardPosition>{};
  }

  final connectedBoxes = <BoardPosition>{anchorPosition};
  final queue = ListQueue<BoardPosition>()..add(anchorPosition);

  while (queue.isNotEmpty) {
    final currentPosition = queue.removeFirst();
    for (final direction in cardinalDirections) {
      final nextPosition = currentPosition.move(
        direction.row,
        direction.column,
      );
      if (brickPositions.contains(nextPosition) &&
          connectedBoxes.add(nextPosition)) {
        queue.add(nextPosition);
      }
    }
  }

  return connectedBoxes;
}

class _FreezeProbe {
  _FreezeProbe(this.layout, this.brickPositions, this.deadTiles);

  final List<String> layout;
  final Set<BoardPosition> brickPositions;
  final Set<BoardPosition> deadTiles;
  final Set<String> _axisChecks = <String>{};

  bool isFrozen(BoardPosition position) {
    return _axisBlocked(position, _FreezeAxis.horizontal) &&
        _axisBlocked(position, _FreezeAxis.vertical);
  }

  bool _axisBlocked(BoardPosition position, _FreezeAxis axis) {
    final checkKey = '${position.row},${position.column},${axis.name}';
    if (!_axisChecks.add(checkKey)) {
      return true;
    }

    final directions = switch (axis) {
      _FreezeAxis.horizontal => const [
        BoardPosition(row: 0, column: -1),
        BoardPosition(row: 0, column: 1),
      ],
      _FreezeAxis.vertical => const [
        BoardPosition(row: -1, column: 0),
        BoardPosition(row: 1, column: 0),
      ],
    };

    return directions.every((direction) {
      final nextPosition = position.move(direction.row, direction.column);
      if (_isStaticBlocker(layout, nextPosition) ||
          deadTiles.contains(nextPosition)) {
        return true;
      }

      if (!brickPositions.contains(nextPosition)) {
        return false;
      }

      return _axisBlocked(nextPosition, axis.opposite);
    });
  }
}

enum _FreezeAxis {
  horizontal,
  vertical;

  _FreezeAxis get opposite {
    return switch (this) {
      _FreezeAxis.horizontal => _FreezeAxis.vertical,
      _FreezeAxis.vertical => _FreezeAxis.horizontal,
    };
  }
}

bool _isStaticBlocker(List<String> layout, BoardPosition position) {
  return !isInsideLayout(layout, position) ||
      tileAt(layout, position.row, position.column) != BoardTile.floor;
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

  if (hasSokobanDeadlock(
    layout: layout,
    brickPositions: brickPositions,
    targetPositions: targetPositions,
    deadTiles: deadTiles,
  )) {
    return false;
  }

  final visitedStates = <String>{};
  final queue = ListQueue<SokobanSearchState>();
  final initialState = SokobanSearchState(
    playerPosition: playerPosition,
    brickPositions: brickPositions,
  );

  visitedStates.add(
    normalisedSearchStateKey(layout, playerPosition, brickPositions),
  );
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
        if (hasSokobanDeadlock(
          layout: layout,
          brickPositions: nextBrickPositions,
          targetPositions: targetPositions,
          deadTiles: deadTiles,
          movedBrickPosition: nextBrickPosition,
        )) {
          continue;
        }

        final nextState = SokobanSearchState(
          playerPosition: brickPosition,
          brickPositions: nextBrickPositions,
        );
        final nextStateKey = normalisedSearchStateKey(
          layout,
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

SokobanHintSearchResult findNextSokobanPushHint({
  required List<String> layout,
  required BoardPosition playerPosition,
  required Set<BoardPosition> brickPositions,
  required Set<BoardPosition> targetPositions,
  required Set<BoardPosition> deadTiles,
  int maxVisitedStates = 20000,
}) {
  if (isSolvedState(brickPositions, targetPositions)) {
    return const SokobanHintSearchResult.alreadySolved();
  }

  if (hasSokobanDeadlock(
    layout: layout,
    brickPositions: brickPositions,
    targetPositions: targetPositions,
    deadTiles: deadTiles,
  )) {
    return const SokobanHintSearchResult.noSolution();
  }

  if (maxVisitedStates <= 0) {
    return const SokobanHintSearchResult.searchLimitReached();
  }

  final visitedStates = <String>{};
  final queue = _PriorityQueue<_SokobanHintSearchNode>((left, right) {
    final priorityCompare = left.priority.compareTo(right.priority);
    if (priorityCompare != 0) {
      return priorityCompare;
    }

    final pushCompare = left.pushCount.compareTo(right.pushCount);
    if (pushCompare != 0) {
      return pushCompare;
    }

    return left.sequence.compareTo(right.sequence);
  });
  var sequence = 0;
  final initialState = _SokobanHintSearchNode(
    playerPosition: playerPosition,
    brickPositions: brickPositions,
    pushCount: 0,
    priority: _solutionHeuristic(brickPositions, targetPositions),
    sequence: sequence++,
  );

  visitedStates.add(
    normalisedSearchStateKey(layout, playerPosition, brickPositions),
  );
  queue.add(initialState);

  var reachedSearchLimit = false;
  while (queue.isNotEmpty) {
    final state = queue.removeFirst();
    final reachablePositions = computeReachableFloors(
      layout,
      state.playerPosition,
      state.brickPositions,
    );
    final candidates = <_SokobanPushCandidate>[];

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

        final pushHint = SokobanPushHint(
          brickPosition: brickPosition,
          direction: direction,
        );
        final nextBrickPositions = applySokobanPush(
          state.brickPositions,
          pushHint,
        );
        if (hasSokobanDeadlock(
          layout: layout,
          brickPositions: nextBrickPositions,
          targetPositions: targetPositions,
          deadTiles: deadTiles,
          movedBrickPosition: nextBrickPosition,
        )) {
          continue;
        }

        candidates.add(
          _SokobanPushCandidate(
            push: pushHint,
            brickPositions: nextBrickPositions,
            priority: _solutionHeuristic(
              nextBrickPositions,
              targetPositions,
              push: pushHint,
            ),
          ),
        );
      }
    }

    candidates.sort((left, right) => left.priority.compareTo(right.priority));

    for (final candidate in candidates) {
      final nextStateKey = normalisedSearchStateKey(
        layout,
        candidate.push.brickPosition,
        candidate.brickPositions,
      );
      if (visitedStates.contains(nextStateKey)) {
        continue;
      }

      final nextState = _SokobanHintSearchNode(
        playerPosition: candidate.push.brickPosition,
        brickPositions: candidate.brickPositions,
        pushCount: state.pushCount + 1,
        priority: candidate.priority + state.pushCount + 1,
        sequence: sequence++,
        parent: state,
        lastPush: candidate.push,
      );

      if (isSolvedState(candidate.brickPositions, targetPositions)) {
        final solution = _solutionForNode(nextState);
        return SokobanHintSearchResult.found(
          solution.first,
          solution: solution,
        );
      }

      if (visitedStates.length >= maxVisitedStates) {
        reachedSearchLimit = true;
        continue;
      }

      visitedStates.add(nextStateKey);
      queue.add(nextState);
    }
  }

  if (reachedSearchLimit) {
    return const SokobanHintSearchResult.searchLimitReached();
  }

  return const SokobanHintSearchResult.noSolution();
}

class _SokobanPushCandidate {
  const _SokobanPushCandidate({
    required this.push,
    required this.brickPositions,
    required this.priority,
  });

  final SokobanPushHint push;
  final Set<BoardPosition> brickPositions;
  final int priority;
}

List<SokobanPushHint> _solutionForNode(_SokobanHintSearchNode node) {
  final reversedSolution = <SokobanPushHint>[];
  var currentNode = node;

  while (currentNode.lastPush != null) {
    reversedSolution.add(currentNode.lastPush!);
    currentNode = currentNode.parent!;
  }

  return reversedSolution.reversed.toList(growable: false);
}

int _solutionHeuristic(
  Set<BoardPosition> brickPositions,
  Set<BoardPosition> targetPositions, {
  SokobanPushHint? push,
}) {
  var priority = _minimumTargetDistanceSum(brickPositions, targetPositions) * 8;
  priority += brickPositions.where((brick) {
    return !targetPositions.contains(brick);
  }).length;

  if (push != null) {
    if (targetPositions.contains(push.nextBrickPosition)) {
      priority -= 5;
    }
    if (targetPositions.contains(push.brickPosition) &&
        !targetPositions.contains(push.nextBrickPosition)) {
      priority += 12;
    }
  }

  return priority;
}

int _minimumTargetDistanceSum(
  Set<BoardPosition> brickPositions,
  Set<BoardPosition> targetPositions,
) {
  final remainingTargets = targetPositions.toList();
  var totalDistance = 0;

  final sortedBricks = brickPositions.toList()
    ..sort((left, right) {
      final leftDistance = _nearestTargetDistance(left, remainingTargets);
      final rightDistance = _nearestTargetDistance(right, remainingTargets);
      final distanceCompare = leftDistance.compareTo(rightDistance);
      if (distanceCompare != 0) {
        return distanceCompare;
      }

      final rowCompare = left.row.compareTo(right.row);
      if (rowCompare != 0) {
        return rowCompare;
      }

      return left.column.compareTo(right.column);
    });

  for (final brickPosition in sortedBricks) {
    if (remainingTargets.isEmpty) {
      break;
    }

    var bestTargetIndex = 0;
    var bestDistance = _manhattanDistance(
      brickPosition,
      remainingTargets.first,
    );

    for (var index = 1; index < remainingTargets.length; index++) {
      final distance = _manhattanDistance(
        brickPosition,
        remainingTargets[index],
      );
      if (distance < bestDistance) {
        bestTargetIndex = index;
        bestDistance = distance;
      }
    }

    totalDistance += bestDistance;
    remainingTargets.removeAt(bestTargetIndex);
  }

  return totalDistance;
}

int _nearestTargetDistance(
  BoardPosition position,
  List<BoardPosition> targetPositions,
) {
  if (targetPositions.isEmpty) {
    return 0;
  }

  var bestDistance = _manhattanDistance(position, targetPositions.first);
  for (var index = 1; index < targetPositions.length; index++) {
    final distance = _manhattanDistance(position, targetPositions[index]);
    if (distance < bestDistance) {
      bestDistance = distance;
    }
  }

  return bestDistance;
}

int _manhattanDistance(BoardPosition left, BoardPosition right) {
  return (left.row - right.row).abs() + (left.column - right.column).abs();
}

class _PriorityQueue<T> {
  _PriorityQueue(this._compare);

  final int Function(T left, T right) _compare;
  final List<T> _items = <T>[];

  bool get isNotEmpty => _items.isNotEmpty;

  void add(T item) {
    _items.add(item);
    _siftUp(_items.length - 1);
  }

  T removeFirst() {
    final first = _items.first;
    final last = _items.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = last;
      _siftDown(0);
    }

    return first;
  }

  void _siftUp(int index) {
    while (index > 0) {
      final parentIndex = (index - 1) >> 1;
      if (_compare(_items[index], _items[parentIndex]) >= 0) {
        return;
      }

      _swap(index, parentIndex);
      index = parentIndex;
    }
  }

  void _siftDown(int index) {
    while (true) {
      final leftChildIndex = index * 2 + 1;
      final rightChildIndex = leftChildIndex + 1;
      var bestIndex = index;

      if (leftChildIndex < _items.length &&
          _compare(_items[leftChildIndex], _items[bestIndex]) < 0) {
        bestIndex = leftChildIndex;
      }

      if (rightChildIndex < _items.length &&
          _compare(_items[rightChildIndex], _items[bestIndex]) < 0) {
        bestIndex = rightChildIndex;
      }

      if (bestIndex == index) {
        return;
      }

      _swap(index, bestIndex);
      index = bestIndex;
    }
  }

  void _swap(int leftIndex, int rightIndex) {
    final left = _items[leftIndex];
    _items[leftIndex] = _items[rightIndex];
    _items[rightIndex] = left;
  }
}
