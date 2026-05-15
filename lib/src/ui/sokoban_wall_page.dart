import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/sokoban_rules.dart';
import '../input/game_intents.dart';
import '../levels/level_catalog.dart';
import '../models/board_position.dart';
import '../models/board_tile.dart';
import '../models/game_snapshot.dart';
import '../models/sokoban_level.dart';
import 'movement_controls.dart';
import 'sokoban_board.dart';

class SokobanWallPage extends StatefulWidget {
  const SokobanWallPage({
    super.key,
    this.initialLevelIndex = 0,
    this.levelCatalog,
  }) : assert(levelCatalog == null || levelCatalog.length > 0);

  final int initialLevelIndex;
  final List<LevelCatalogItem>? levelCatalog;

  @override
  State<SokobanWallPage> createState() => _SokobanWallPageState();
}

class _SokobanWallPageState extends State<SokobanWallPage> {
  static const double _boardHeaderHeight = 48;
  static const double _boardHeaderGap = 8;
  static const double _boardHeaderMinWidth = 220;
  static const int _hintSolverMaxVisitedStates = 8000;

  int _currentLevelIndex = 0;
  late final List<LevelCatalogItem> _levelCatalog;
  late BoardPosition _playerPosition;
  late Set<BoardPosition> _brickPositions;
  late Set<BoardPosition> _targetPositions;
  late Set<BoardPosition> _deadTiles;
  final List<GameSnapshot> _moveHistory = <GameSnapshot>[];
  int _stepCount = 0;
  String? _levelValidationMessage;
  String? _deadlockMessage;
  String? _hintMessage;
  BoardPosition? _hintedBrickPosition;
  BoardPosition? _hintDirection;
  BoardPosition? _hintPushTargetPosition;

  SokobanLevel get _currentLevel => _levelCatalog[_currentLevelIndex].level;

  List<String> get _currentLayout => _currentLevel.layout;

  bool get _canUndo => _moveHistory.isNotEmpty;

  double get _boardAspectRatio {
    return SokobanBoard.viewportSizeForLayout(_currentLayout).aspectRatio;
  }

  @override
  void initState() {
    super.initState();
    _levelCatalog = List<LevelCatalogItem>.unmodifiable(
      widget.levelCatalog ?? builtInLevelCatalog,
    );
    _loadLevel(_normalisedLevelIndex(widget.initialLevelIndex));
  }

  int _normalisedLevelIndex(int levelIndex) {
    if (levelIndex < 0) {
      return 0;
    }

    if (levelIndex >= _levelCatalog.length) {
      return _levelCatalog.length - 1;
    }

    return levelIndex;
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
    if (_currentLayout.isEmpty || _currentLayout.first.isEmpty) {
      return '关卡布局不能为空。';
    }

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

    return null;
  }

  String? _detectDeadlock({
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

    return null;
  }

  void _loadLevel(int levelIndex) {
    final level = _levelCatalog[levelIndex].level;
    _currentLevelIndex = levelIndex;
    _playerPosition = level.initialPlayerPosition;
    _brickPositions = positionsForSymbol(level.layout, 'B');
    _targetPositions = positionsForSymbol(level.layout, 'T');
    _deadTiles = computeDeadTiles(level.layout, _targetPositions);
    _moveHistory.clear();
    _stepCount = 0;
    _clearActiveHint();
    _levelValidationMessage = _validateLoadedLevel();
    _deadlockMessage = _levelValidationMessage == null
        ? _detectDeadlock(brickPositions: _brickPositions)
        : null;
  }

  void _clearActiveHint() {
    _hintMessage = null;
    _hintedBrickPosition = null;
    _hintDirection = null;
    _hintPushTargetPosition = null;
  }

  void _resetCurrentLevel() {
    setState(() {
      _loadLevel(_currentLevelIndex);
    });
  }

  void _changeLevel(int levelIndex) {
    if (levelIndex < 0 ||
        levelIndex >= _levelCatalog.length ||
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
      _clearActiveHint();
      _deadlockMessage = _levelValidationMessage == null
          ? _detectDeadlock(brickPositions: _brickPositions)
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
        brickPositions: nextBrickPositions,
        movedBrickPosition: nextBrickPosition,
      );

      setState(() {
        _clearActiveHint();
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
      _clearActiveHint();
      _moveHistory.add(snapshot);
      _playerPosition = nextPosition;
      _stepCount += 1;
    });
  }

  void _showHint() {
    if (_levelValidationMessage != null) {
      setState(() {
        _clearActiveHint();
        _hintMessage = _levelValidationMessage;
      });
      return;
    }

    if (_isLevelComplete) {
      setState(() {
        _clearActiveHint();
        _hintMessage = '本关已经完成，可以进入下一关。';
      });
      return;
    }

    if (_deadlockMessage != null) {
      setState(() {
        _clearActiveHint();
        _hintMessage = _deadlockMessage;
      });
      return;
    }

    final searchResult = findNextSokobanPushHint(
      layout: _currentLayout,
      playerPosition: _playerPosition,
      brickPositions: _brickPositions,
      targetPositions: _targetPositions,
      deadTiles: _deadTiles,
      maxVisitedStates: _hintSolverMaxVisitedStates,
    );

    setState(() {
      _clearActiveHint();
      switch (searchResult.status) {
        case SokobanHintSearchStatus.alreadySolved:
          _hintMessage = '本关已经完成，可以进入下一关。';
          break;
        case SokobanHintSearchStatus.found:
          final hint = searchResult.hint!;
          _hintMessage = _formatPushHint(hint);
          _hintedBrickPosition = hint.brickPosition;
          _hintDirection = hint.direction;
          _hintPushTargetPosition = hint.nextBrickPosition;
          break;
        case SokobanHintSearchStatus.noSolution:
          _hintMessage = '当前局面找不到可通关路径，建议撤销几步或重置本关。';
          break;
        case SokobanHintSearchStatus.searchLimitReached:
          _hintMessage = '当前局面较复杂，暂时无法快速算出下一步。建议先撤销到更早状态，或重置后重新规划。';
          break;
      }
    });
  }

  String _formatPushHint(SokobanPushHint hint) {
    final pushSide = _pushSideText(hint.direction);
    final direction = _directionText(hint.direction);
    final playerPushPosition = _formatBoardPosition(hint.playerPushPosition);
    final brickPosition = _formatBoardPosition(hint.brickPosition);

    return '下一步：站到 $playerPushPosition，也就是箱子$pushSide，把 $brickPosition 的箱子向$direction推一格。';
  }

  String _formatBoardPosition(BoardPosition position) {
    return '第 ${position.row + 1} 行第 ${position.column + 1} 列';
  }

  String _directionText(BoardPosition direction) {
    if (direction.row < 0) {
      return '上';
    }
    if (direction.row > 0) {
      return '下';
    }
    if (direction.column < 0) {
      return '左';
    }

    return '右';
  }

  String _pushSideText(BoardPosition direction) {
    if (direction.row < 0) {
      return '下方';
    }
    if (direction.row > 0) {
      return '上方';
    }
    if (direction.column < 0) {
      return '右侧';
    }

    return '左侧';
  }

  bool _isWalkableFloor(BoardPosition position) {
    if (!_isInsideBoard(position)) {
      return false;
    }

    final nextTile = tileAt(_currentLayout, position.row, position.column);
    return nextTile == BoardTile.floor && !_isBrickAt(position);
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
    final isLevelComplete = _isLevelComplete;
    final hasBlockingIssue =
        _levelValidationMessage != null || _deadlockMessage != null;
    final hasActiveHint = _hintMessage != null;
    final String? statusMessage = isLevelComplete
        ? '全部箱子已到目标点，过关！'
        : _levelValidationMessage ?? _deadlockMessage ?? _hintMessage;
    final statusColor = isLevelComplete
        ? const Color(0xFFDDEFD8)
        : hasBlockingIssue
        ? const Color(0xFFF6D7D1)
        : hasActiveHint
        ? const Color(0xFFFFF4C4)
        : const Color(0xFFE9E1CF);
    final statusBorderColor = isLevelComplete
        ? const Color(0xFF5B8A55)
        : hasBlockingIssue
        ? const Color(0xFFB05D51)
        : hasActiveHint
        ? const Color(0xFFD39C13)
        : const Color(0xFFC2B79D);
    final screenSize = MediaQuery.sizeOf(context);
    final isCompactScreen = screenSize.shortestSide < 420;
    final pagePadding = isCompactScreen ? 10.0 : 16.0;
    final sectionGap = isCompactScreen ? 10.0 : 12.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF2EFE7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF526652),
        foregroundColor: Colors.white,
        title: Text(
          isLevelComplete
              ? '推箱子 - ${_currentLevel.title} 已过关'
              : '推箱子 - ${_currentLevel.title}',
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
                padding: EdgeInsets.all(pagePadding),
                child: Column(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final double availableBoardHeight = math.max(
                            0.0,
                            constraints.maxHeight -
                                _boardHeaderHeight -
                                _boardHeaderGap,
                          );
                          final boardAspectRatio = _boardAspectRatio;
                          final double boardWidth = math.min(
                            constraints.maxWidth,
                            availableBoardHeight * boardAspectRatio,
                          );
                          final double boardHeight =
                              boardWidth / boardAspectRatio;
                          final double boardHeaderWidth = math.min(
                            constraints.maxWidth,
                            math.max(boardWidth, _boardHeaderMinWidth),
                          );

                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: boardHeaderWidth,
                                  child: _BoardHeader(
                                    levelNumber: _currentLevel.number,
                                    stepCount: _stepCount,
                                  ),
                                ),
                                const SizedBox(height: _boardHeaderGap),
                                SizedBox(
                                  width: boardWidth,
                                  height: boardHeight,
                                  child: SokobanBoard(
                                    layout: _currentLayout,
                                    brickPositions: _brickPositions,
                                    targetPositions: _targetPositions,
                                    playerPosition: _playerPosition,
                                    hintedBrickPosition: _hintedBrickPosition,
                                    hintDirection: _hintDirection,
                                    hintPushTargetPosition:
                                        _hintPushTargetPosition,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: isCompactScreen ? 12 : 16),
                    _HintControl(onHint: _showHint),
                    if (statusMessage != null) ...[
                      SizedBox(height: sectionGap),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: isCompactScreen ? 10 : 12,
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
                    ],
                    if (isLevelComplete) ...[
                      SizedBox(height: sectionGap),
                      FilledButton.icon(
                        onPressed: _currentLevelIndex < _levelCatalog.length - 1
                            ? () => _changeLevel(_currentLevelIndex + 1)
                            : _resetCurrentLevel,
                        icon: Icon(
                          _currentLevelIndex < _levelCatalog.length - 1
                              ? Icons.skip_next
                              : Icons.replay,
                        ),
                        label: Text(
                          _currentLevelIndex < _levelCatalog.length - 1
                              ? '进入下一关'
                              : '重玩本关',
                        ),
                      ),
                    ],
                    SizedBox(height: sectionGap),
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

class _BoardHeader extends StatelessWidget {
  const _BoardHeader({required this.levelNumber, required this.stepCount});

  final int levelNumber;
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD9CFBB)),
      ),
      child: Row(
        children: [
          Flexible(
            child: Text(
              '第 $levelNumber 关',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              '步数 $stepCount',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: textStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _HintControl extends StatelessWidget {
  const _HintControl({required this.onHint});

  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    return Align(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 160, maxWidth: 240),
        child: FilledButton.icon(
          onPressed: onHint,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            backgroundColor: const Color(0xFFD39C13),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.lightbulb_outline),
          label: const Text('提示'),
        ),
      ),
    );
  }
}
