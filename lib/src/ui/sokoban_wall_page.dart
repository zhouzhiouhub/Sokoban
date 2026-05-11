import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/sokoban_rules.dart';
import '../input/game_intents.dart';
import '../levels/sokoban_levels.dart';
import '../models/board_position.dart';
import '../models/board_tile.dart';
import '../models/game_snapshot.dart';
import '../models/sokoban_level.dart';
import 'movement_controls.dart';
import 'sokoban_board.dart';

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
      if (!_targetPositions.contains(brickPosition) &&
          _deadTiles.contains(brickPosition)) {
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
      if (!_targetPositions.contains(brickPosition) &&
          _deadTiles.contains(brickPosition)) {
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
    final hasBlockingIssue =
        _levelValidationMessage != null || _deadlockMessage != null;
    final statusMessage = isLevelComplete
        ? '全部箱子已到目标点，过关！'
        : _levelValidationMessage ??
              _deadlockMessage ??
              _currentLevel.description;
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

    return Scaffold(
      backgroundColor: const Color(0xFFF2EFE7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF526652),
        foregroundColor: Colors.white,
        title: Text(
          isLevelComplete
              ? '推箱子 - ${_currentLevel.displayName} 已过关'
              : '推箱子 - ${_currentLevel.displayName}',
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
            SingleActivator(LogicalKeyboardKey.keyZ, control: true):
                UndoIntent(),
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
                              _currentLayout.first.length /
                              _currentLayout.length;
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
                    _LevelControls(
                      currentLevelIndex: _currentLevelIndex,
                      canUndo: _canUndo,
                      onChangeLevel: _changeLevel,
                      onReset: _resetCurrentLevel,
                      onUndo: _undoMove,
                    ),
                    const SizedBox(height: 12),
                    _StatsRow(
                      currentLevelIndex: _currentLevelIndex,
                      stepCount: _stepCount,
                      boxesOnTargetCount: boxesOnTargetCount,
                      targetCount: _targetPositions.length,
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
                        border: Border.all(color: statusBorderColor),
                      ),
                      child: Text(
                        statusMessage,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
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

class _LevelControls extends StatelessWidget {
  const _LevelControls({
    required this.currentLevelIndex,
    required this.canUndo,
    required this.onChangeLevel,
    required this.onReset,
    required this.onUndo,
  });

  final int currentLevelIndex;
  final bool canUndo;
  final ValueChanged<int> onChangeLevel;
  final VoidCallback onReset;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: currentLevelIndex,
                isExpanded: true,
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
                      child: Text(
                        sokobanLevels[index].displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onChangeLevel(value);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: onReset,
              style: FilledButton.styleFrom(minimumSize: const Size(108, 56)),
              icon: const Icon(Icons.refresh),
              label: const Text('重置'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: canUndo ? onUndo : null,
            icon: const Icon(Icons.undo),
            label: const Text('撤销一步'),
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.currentLevelIndex,
    required this.stepCount,
    required this.boxesOnTargetCount,
    required this.targetCount,
  });

  final int currentLevelIndex;
  final int stepCount;
  final int boxesOnTargetCount;
  final int targetCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: '关卡',
            value: '${currentLevelIndex + 1}/${sokobanLevels.length}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(label: '步数', value: '$stepCount'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: '进度',
            value: '$boxesOnTargetCount/$targetCount',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: const Color(0xFF756B58)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
