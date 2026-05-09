import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

enum BoardTile { wall, floor, brick }

class SokobanLevel {
  const SokobanLevel({
    required this.name,
    required this.layout,
    required this.initialPlayerPosition,
  });

  final String name;
  final List<String> layout;
  final BoardPosition initialPlayerPosition;
}

const List<SokobanLevel> sokobanLevels = [
  SokobanLevel(
    name: '第 1 关',
    layout: [
      '#######',
      '#     #',
      '# B T #',
      '#     #',
      '#######',
    ],
    initialPlayerPosition: BoardPosition(row: 2, column: 1),
  ),
  SokobanLevel(
    name: '第 2 关',
    layout: [
      '########',
      '#      #',
      '# B    #',
      '#     T#',
      '#      #',
      '#      #',
      '#  #   #',
      '########',
    ],
    initialPlayerPosition: BoardPosition(row: 5, column: 1),
  ),
  SokobanLevel(
    name: '第 3 关',
    layout: [
      '#########',
      '# #   T #',
      '#     # #',
      '# T#    #',
      '#    B  #',
      '# B #   #',
      '#   #   #',
      '# #   # #',
      '#########',
    ],
    initialPlayerPosition: BoardPosition(row: 4, column: 1),
  ),
  SokobanLevel(
    name: '挑战关',
    layout: [
      '##########',
      '#   B   T#',
      '#  # ##  #',
      '#  #  #  #',
      '#  # B####',
      '#  # T   #',
      '#  ### # #',
      '# T B  # #',
      '##########',
    ],
    initialPlayerPosition: BoardPosition(row: 1, column: 1),
  ),
];

class BoardPosition {
  const BoardPosition({required this.row, required this.column});

  final int row;
  final int column;

  BoardPosition move(int rowOffset, int columnOffset) {
    return BoardPosition(row: row + rowOffset, column: column + columnOffset);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is BoardPosition && other.row == row && other.column == column;
  }

  @override
  int get hashCode => Object.hash(row, column);
}

const List<BoardPosition> _cardinalDirections = [
  BoardPosition(row: -1, column: 0),
  BoardPosition(row: 1, column: 0),
  BoardPosition(row: 0, column: -1),
  BoardPosition(row: 0, column: 1),
];

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

class SokobanSearchState {
  SokobanSearchState({
    required this.playerPosition,
    required Set<BoardPosition> brickPositions,
  }) : brickPositions = Set<BoardPosition>.from(brickPositions);

  final BoardPosition playerPosition;
  final Set<BoardPosition> brickPositions;
}

class MoveIntent extends Intent {
  const MoveIntent(this.rowOffset, this.columnOffset);

  final int rowOffset;
  final int columnOffset;
}

class UndoIntent extends Intent {
  const UndoIntent();
}

BoardTile tileAt(List<String> layout, int row, int column) {
  return switch (layout[row][column]) {
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
      tileAt(layout, position.row, position.column) != BoardTile.wall;
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

  return sortedPositions.map((position) => '${position.row},${position.column}').join(';');
}

String searchStateKey(
  BoardPosition playerPosition,
  Set<BoardPosition> brickPositions,
) {
  return '${playerPosition.row},${playerPosition.column}|${positionsKey(brickPositions)}';
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

    for (final direction in _cardinalDirections) {
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
      if (!isFloorTile(layout, position) || targetPositions.contains(position)) {
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
  if (!isFloorTile(layout, startPosition) || brickPositions.contains(startPosition)) {
    return <BoardPosition>{};
  }

  final reachablePositions = <BoardPosition>{startPosition};
  final queue = ListQueue<BoardPosition>()..add(startPosition);

  while (queue.isNotEmpty) {
    final currentPosition = queue.removeFirst();

    for (final direction in _cardinalDirections) {
      final nextPosition = currentPosition.move(direction.row, direction.column);
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
      return tileAt(layout, position.row, position.column) == BoardTile.wall ||
          brickPositions.contains(position);
    });
    if (!isFrozenSquare) {
      continue;
    }

    final hasOffTargetBrick = square.any((position) {
      return brickPositions.contains(position) && !targetPositions.contains(position);
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
    if (!targetPositions.contains(brickPosition) && deadTiles.contains(brickPosition)) {
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
      for (final direction in _cardinalDirections) {
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '推箱子',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF526652)),
        useMaterial3: true,
      ),
      home: const SokobanWallPage(),
    );
  }
}

class SokobanWallPage extends StatefulWidget {
  const SokobanWallPage({super.key});

  @override
  State<SokobanWallPage> createState() => _SokobanWallPageState();
}

class _SokobanWallPageState extends State<SokobanWallPage> {
  int _currentLevelIndex = 0;
  late BoardPosition _playerPosition;
  late Set<BoardPosition> _brickPositions;
  late Set<BoardPosition> _targetPositions;
  late Set<BoardPosition> _deadTiles;
  final List<GameSnapshot> _moveHistory = <GameSnapshot>[];
  int _stepCount = 0;
  String? _levelValidationMessage;
  String? _deadlockMessage;

  SokobanLevel get _currentLevel => sokobanLevels[_currentLevelIndex];

  List<String> get _currentLayout => _currentLevel.layout;

  bool get _canUndo => _moveHistory.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadLevel(0);
  }

  int get _boxesOnTargetCount {
    return _brickPositions.where(_targetPositions.contains).length;
  }

  bool get _isLevelComplete {
    return _targetPositions.isNotEmpty &&
        _boxesOnTargetCount == _targetPositions.length;
  }

  GameSnapshot _createSnapshot() {
    return GameSnapshot(
      playerPosition: _playerPosition,
      brickPositions: _brickPositions,
      stepCount: _stepCount,
    );
  }

  String? _validateLoadedLevel() {
    final expectedColumnCount = _currentLayout.first.length;
    if (_currentLayout.any((row) => row.length != expectedColumnCount)) {
      return '关卡布局必须是规则矩形，每一行长度都要一致。';
    }

    if (_brickPositions.isEmpty || _targetPositions.isEmpty) {
      return '关卡至少需要一个箱子和一个目标点。';
    }

    if (_brickPositions.length != _targetPositions.length) {
      return '箱子数量必须与目标点数量一致。';
    }

    if (!isFloorTile(_currentLayout, _playerPosition)) {
      return '玩家初始位置必须位于可通行地块。';
    }

    if (_brickPositions.contains(_playerPosition)) {
      return '玩家初始位置不能和箱子重叠。';
    }

    for (final brickPosition in _brickPositions) {
      if (!_targetPositions.contains(brickPosition) && _deadTiles.contains(brickPosition)) {
        return '当前关卡开局就有箱子落在死格，初始状态无解。';
      }
    }

    if (!isSokobanStateSolvable(
      layout: _currentLayout,
      playerPosition: _playerPosition,
      brickPositions: _brickPositions,
      targetPositions: _targetPositions,
      deadTiles: _deadTiles,
    )) {
      return '当前关卡初始状态无解，请调整箱子或目标点。';
    }

    return null;
  }

  String? _detectDeadlock({
    required BoardPosition playerPosition,
    required Set<BoardPosition> brickPositions,
    BoardPosition? movedBrickPosition,
  }) {
    if (isSolvedState(brickPositions, _targetPositions)) {
      return null;
    }

    for (final brickPosition in brickPositions) {
      if (!_targetPositions.contains(brickPosition) && _deadTiles.contains(brickPosition)) {
        return '箱子被推入死格，当前状态已无解，建议撤销或重置。';
      }
    }

    if (movedBrickPosition != null &&
        formsFrozenSquareDeadlock(
          _currentLayout,
          brickPositions,
          _targetPositions,
          movedBrickPosition,
        )) {
      return '箱子形成 2x2 锁死块，当前状态已无解，建议撤销或重置。';
    }

    if (!isSokobanStateSolvable(
      layout: _currentLayout,
      playerPosition: playerPosition,
      brickPositions: brickPositions,
      targetPositions: _targetPositions,
      deadTiles: _deadTiles,
    )) {
      return '当前箱子组合已互锁，继续推进不会过关，建议撤销或重置。';
    }

    return null;
  }

  void _loadLevel(int levelIndex) {
    final level = sokobanLevels[levelIndex];
    _currentLevelIndex = levelIndex;
    _playerPosition = level.initialPlayerPosition;
    _brickPositions = positionsForSymbol(level.layout, 'B');
    _targetPositions = positionsForSymbol(level.layout, 'T');
    _deadTiles = computeDeadTiles(level.layout, _targetPositions);
    _moveHistory.clear();
    _stepCount = 0;
    _levelValidationMessage = _validateLoadedLevel();
    _deadlockMessage = _levelValidationMessage == null
        ? _detectDeadlock(
            playerPosition: _playerPosition,
            brickPositions: _brickPositions,
          )
        : null;
  }

  void _resetCurrentLevel() {
    setState(() {
      _loadLevel(_currentLevelIndex);
    });
  }

  void _changeLevel(int levelIndex) {
    if (levelIndex < 0 ||
        levelIndex >= sokobanLevels.length ||
        levelIndex == _currentLevelIndex) {
      return;
    }

    setState(() {
      _loadLevel(levelIndex);
    });
  }

  void _undoMove() {
    if (!_canUndo) {
      return;
    }

    setState(() {
      final snapshot = _moveHistory.removeLast();
      _playerPosition = snapshot.playerPosition;
      _brickPositions = Set<BoardPosition>.from(snapshot.brickPositions);
      _stepCount = snapshot.stepCount;
      _deadlockMessage = _levelValidationMessage == null
          ? _detectDeadlock(
              playerPosition: _playerPosition,
              brickPositions: _brickPositions,
            )
          : null;
    });
  }

  void _movePlayer(int rowOffset, int columnOffset) {
    if (_levelValidationMessage != null) {
      return;
    }

    final snapshot = _createSnapshot();
    final nextPosition = _playerPosition.move(rowOffset, columnOffset);
    if (_isBrickAt(nextPosition)) {
      final nextBrickPosition = nextPosition.move(rowOffset, columnOffset);
      if (!_isWalkableFloor(nextBrickPosition)) {
        return;
      }

      final nextBrickPositions = Set<BoardPosition>.from(_brickPositions)
        ..remove(nextPosition)
        ..add(nextBrickPosition);
      final nextDeadlockMessage = _detectDeadlock(
        playerPosition: nextPosition,
        brickPositions: nextBrickPositions,
        movedBrickPosition: nextBrickPosition,
      );

      setState(() {
        _moveHistory.add(snapshot);
        _brickPositions = nextBrickPositions;
        _playerPosition = nextPosition;
        _stepCount += 1;
        _deadlockMessage = nextDeadlockMessage;
      });
      return;
    }

    if (!_isWalkableFloor(nextPosition)) {
      return;
    }

    setState(() {
      _moveHistory.add(snapshot);
      _playerPosition = nextPosition;
      _stepCount += 1;
    });
  }

  bool _isWalkableFloor(BoardPosition position) {
    if (!_isInsideBoard(position)) {
      return false;
    }

    final nextTile = tileAt(_currentLayout, position.row, position.column);
    return nextTile != BoardTile.wall && !_isBrickAt(position);
  }

  bool _isInsideBoard(BoardPosition position) {
    if (position.row < 0 || position.row >= _currentLayout.length) {
      return false;
    }

    return position.column >= 0 &&
        position.column < _currentLayout[position.row].length;
  }

  bool _isBrickAt(BoardPosition position) {
    return _brickPositions.contains(position);
  }

  @override
  Widget build(BuildContext context) {
    final boxesOnTargetCount = _boxesOnTargetCount;
    final isLevelComplete = _isLevelComplete;
    final hasBlockingIssue = _levelValidationMessage != null || _deadlockMessage != null;
    final statusMessage = isLevelComplete
      ? '全部箱子已到目标点，过关！'
      : _levelValidationMessage ??
        _deadlockMessage ??
        '把所有箱子推到圆形目标点即可过关。';
    final statusColor = isLevelComplete
      ? const Color(0xFFDDEFD8)
      : hasBlockingIssue
        ? const Color(0xFFF6D7D1)
        : const Color(0xFFE9E1CF);
    final statusBorderColor = isLevelComplete
      ? const Color(0xFF5B8A55)
      : hasBlockingIssue
        ? const Color(0xFFB05D51)
        : const Color(0xFFC2B79D);

    Widget buildStatCard({required String label, required String value}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD9CFBB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFF756B58),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2EFE7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF526652),
        foregroundColor: Colors.white,
        title: Text(
          isLevelComplete
              ? '推箱子 - ${_currentLevel.name} 已过关'
              : '推箱子 - ${_currentLevel.name}',
        ),
        actions: [
          IconButton(
            tooltip: '撤销一步',
            onPressed: _canUndo ? _undoMove : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: '重置本关',
            onPressed: _resetCurrentLevel,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.arrowUp): MoveIntent(-1, 0),
            SingleActivator(LogicalKeyboardKey.arrowDown): MoveIntent(1, 0),
            SingleActivator(LogicalKeyboardKey.arrowLeft): MoveIntent(0, -1),
            SingleActivator(LogicalKeyboardKey.arrowRight): MoveIntent(0, 1),
            SingleActivator(LogicalKeyboardKey.keyW): MoveIntent(-1, 0),
            SingleActivator(LogicalKeyboardKey.keyS): MoveIntent(1, 0),
            SingleActivator(LogicalKeyboardKey.keyA): MoveIntent(0, -1),
            SingleActivator(LogicalKeyboardKey.keyD): MoveIntent(0, 1),
            SingleActivator(LogicalKeyboardKey.keyZ): UndoIntent(),
            SingleActivator(LogicalKeyboardKey.keyZ, control: true): UndoIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              MoveIntent: CallbackAction<MoveIntent>(
                onInvoke: (intent) {
                  _movePlayer(intent.rowOffset, intent.columnOffset);
                  return null;
                },
              ),
              UndoIntent: CallbackAction<UndoIntent>(
                onInvoke: (intent) {
                  _undoMove();
                  return null;
                },
              ),
            },
            child: Focus(
              autofocus: true,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final boardRatio =
                              _currentLayout.first.length / _currentLayout.length;
                          final boardWidth = math.min(
                            constraints.maxWidth,
                            constraints.maxHeight * boardRatio,
                          );

                          return Center(
                            child: SizedBox(
                              width: boardWidth,
                              child: AspectRatio(
                                aspectRatio: boardRatio,
                                child: SokobanBoard(
                                  layout: _currentLayout,
                                  brickPositions: _brickPositions,
                                  targetPositions: _targetPositions,
                                  playerPosition: _playerPosition,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _currentLevelIndex,
                            decoration: const InputDecoration(
                              labelText: '切换关卡',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                            ),
                            items: [
                              for (var index = 0; index < sokobanLevels.length; index++)
                                DropdownMenuItem<int>(
                                  value: index,
                                  child: Text(sokobanLevels[index].name),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                _changeLevel(value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _resetCurrentLevel,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(108, 56),
                          ),
                          icon: const Icon(Icons.refresh),
                          label: const Text('重置'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _canUndo ? _undoMove : null,
                            icon: const Icon(Icons.undo),
                            label: const Text('撤销一步'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: buildStatCard(
                            label: '关卡',
                            value: '${_currentLevelIndex + 1}/${sokobanLevels.length}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: buildStatCard(label: '步数', value: '$_stepCount'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: buildStatCard(
                            label: '进度',
                            value: '$boxesOnTargetCount/${_targetPositions.length}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: statusBorderColor,
                        ),
                      ),
                      child: Text(
                        statusMessage,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    if (isLevelComplete) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _currentLevelIndex < sokobanLevels.length - 1
                            ? () => _changeLevel(_currentLevelIndex + 1)
                            : _resetCurrentLevel,
                        icon: Icon(
                          _currentLevelIndex < sokobanLevels.length - 1
                              ? Icons.skip_next
                              : Icons.replay,
                        ),
                        label: Text(
                          _currentLevelIndex < sokobanLevels.length - 1
                              ? '进入下一关'
                              : '重玩本关',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    MovementControls(
                      onUp: () => _movePlayer(-1, 0),
                      onDown: () => _movePlayer(1, 0),
                      onLeft: () => _movePlayer(0, -1),
                      onRight: () => _movePlayer(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SokobanBoard extends StatelessWidget {
  const SokobanBoard({
    super.key,
    required this.layout,
    required this.brickPositions,
    required this.targetPositions,
    required this.playerPosition,
  });

  final List<String> layout;
  final Set<BoardPosition> brickPositions;
  final Set<BoardPosition> targetPositions;
  final BoardPosition playerPosition;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE3DBC9),
        border: Border.all(color: const Color(0xFF2E352D), width: 4),
      ),
      child: Column(
        children: [
          for (var row = 0; row < layout.length; row++)
            Expanded(
              child: Row(
                children: [
                  for (var column = 0; column < layout[row].length; column++)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final position = BoardPosition(row: row, column: column);
                          final tile = brickPositions.contains(position)
                              ? BoardTile.brick
                              : tileAt(layout, row, column);
                          final isTarget = targetPositions.contains(position);
                          final hasPlayer =
                              playerPosition.row == row &&
                              playerPosition.column == column;

                          return SokobanTile(
                            key: ValueKey('${tile.name}-$row-$column-$hasPlayer'),
                            tile: tile,
                            isTarget: isTarget,
                            hasPlayer: hasPlayer,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class SokobanTile extends StatelessWidget {
  const SokobanTile({
    super.key,
    required this.tile,
    required this.isTarget,
    required this.hasPlayer,
  });

  final BoardTile tile;
  final bool isTarget;
  final bool hasPlayer;

  @override
  Widget build(BuildContext context) {
    final semanticsLabel = switch ((tile, isTarget, hasPlayer)) {
      (BoardTile.wall, _, _) => '墙体',
      (BoardTile.brick, true, _) => '目标点上的箱子',
      (BoardTile.brick, false, _) => '箱子',
      (BoardTile.floor, true, true) => '人物所在的目标点',
      (BoardTile.floor, true, false) => '目标点',
      (BoardTile.floor, false, true) => '人物所在位置',
      (BoardTile.floor, false, false) => '地面',
    };

    final backgroundColor = tile == BoardTile.wall
        ? const Color(0xFF3F493A)
        : const Color(0xFFD8CFB9);

    final borderColor = tile == BoardTile.wall
        ? const Color(0xFF222820)
        : const Color(0xFFC9BFA8);

    return Semantics(
      label: semanticsLabel,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border.all(color: borderColor, width: 0.7),
            ),
          ),
          if (isTarget && tile != BoardTile.wall)
            Center(
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4C4),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFB18B2C), width: 2),
                ),
              ),
            ),
          if (tile == BoardTile.wall)
            const Center(
              child: Icon(Icons.square, color: Color(0xFF5F7257), size: 14),
            ),
          if (tile == BoardTile.brick)
            Padding(
              padding: const EdgeInsets.all(5),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFC98A55),
                  border: Border.all(color: const Color(0xFF74441E), width: 1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          if (hasPlayer)
            const Center(
              child: _PlayerAvatar(),
            ),
        ],
      ),
    );
  }
}

class MovementControls extends StatelessWidget {
  const MovementControls({
    super.key,
    required this.onUp,
    required this.onDown,
    required this.onLeft,
    required this.onRight,
  });

  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) {
    Widget buildButton({
      required VoidCallback onPressed,
      required IconData icon,
      required String tooltip,
    }) {
      return SizedBox(
        width: 56,
        height: 56,
        child: FilledButton.tonal(
          onPressed: onPressed,
          child: Tooltip(message: tooltip, child: Icon(icon)),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildButton(
          onPressed: onUp,
          icon: Icons.keyboard_arrow_up,
          tooltip: '向上移动',
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildButton(
              onPressed: onLeft,
              icon: Icons.keyboard_arrow_left,
              tooltip: '向左移动',
            ),
            const SizedBox(width: 8),
            const SizedBox(
              width: 56,
              height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFDDD3BE),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person, color: Color(0xFF526652)),
              ),
            ),
            const SizedBox(width: 8),
            buildButton(
              onPressed: onRight,
              icon: Icons.keyboard_arrow_right,
              tooltip: '向右移动',
            ),
          ],
        ),
        const SizedBox(height: 8),
        buildButton(
          onPressed: onDown,
          icon: Icons.keyboard_arrow_down,
          tooltip: '向下移动',
        ),
      ],
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: const Color(0xFF3C6E71),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(Icons.person, size: 14, color: Colors.white),
    );
  }
}
