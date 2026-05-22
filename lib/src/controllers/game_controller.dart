import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/sokoban_rules.dart';
import '../levels/level_catalog.dart';
import '../models/board_position.dart';
import '../models/board_tile.dart';
import '../models/board_viewport_size.dart';
import '../models/game_snapshot.dart';
import '../models/sokoban_level.dart';
import 'level_catalog_controller.dart';

const Object _unchanged = Object();

final activeLevelCatalogProvider = Provider<List<LevelCatalogItem>>((ref) {
  final builtInCatalogAsync = ref.watch(builtInLevelCatalogProvider);
  final builtInCatalog = builtInCatalogAsync.hasValue
      ? builtInCatalogAsync.requireValue
      : const <LevelCatalogItem>[];
  final catalogState = ref.watch(levelCatalogControllerProvider);
  final customCatalog = catalogState.hasValue
      ? catalogState.requireValue.customLevelCatalog
      : const <LevelCatalogItem>[];

  return [...builtInCatalog, ...customCatalog];
});

final gameInitialLevelIndexProvider = Provider<int>((ref) => 0);

final gameControllerProvider =
    NotifierProvider.autoDispose<GameController, SokobanGameState>(
      GameController.new,
      dependencies: [activeLevelCatalogProvider, gameInitialLevelIndexProvider],
    );

enum GameMessageKind { status, deadlock, hint, completion }

class GameActionMessage {
  const GameActionMessage({
    required this.kind,
    required this.title,
    required this.message,
  });

  const GameActionMessage.status({
    required String title,
    required String message,
  }) : this(kind: GameMessageKind.status, title: title, message: message);

  const GameActionMessage.deadlock(String message)
    : this(kind: GameMessageKind.deadlock, title: '死局', message: message);

  const GameActionMessage.hint(String message)
    : this(kind: GameMessageKind.hint, title: '提示', message: message);

  const GameActionMessage.completion()
    : this(
        kind: GameMessageKind.completion,
        title: '过关',
        message: '全部箱子已到目标点，过关！',
      );

  final GameMessageKind kind;
  final String title;
  final String message;
}

class SokobanGameState {
  SokobanGameState({
    required List<LevelCatalogItem> levelCatalog,
    required this.currentLevelIndex,
    required this.playerPosition,
    required this.playerDirection,
    required Set<BoardPosition> brickPositions,
    required Set<BoardPosition> targetPositions,
    required Set<BoardPosition> deadTiles,
    required List<GameSnapshot> moveHistory,
    required this.stepCount,
    this.levelValidationMessage,
    this.deadlockMessage,
    this.hintedBrickPosition,
    this.hintDirection,
    this.hintPushTargetPosition,
  }) : levelCatalog = List<LevelCatalogItem>.unmodifiable(levelCatalog),
       brickPositions = Set<BoardPosition>.unmodifiable(brickPositions),
       targetPositions = Set<BoardPosition>.unmodifiable(targetPositions),
       deadTiles = Set<BoardPosition>.unmodifiable(deadTiles),
       moveHistory = List<GameSnapshot>.unmodifiable(moveHistory);

  factory SokobanGameState.load({
    required List<LevelCatalogItem> levelCatalog,
    required int levelIndex,
  }) {
    assert(levelCatalog.isNotEmpty);

    final currentLevelIndex = _normalisedLevelIndex(
      levelIndex,
      levelCatalog.length,
    );
    final level = levelCatalog[currentLevelIndex].level;
    final brickPositions = positionsForSymbol(level.layout, 'B');
    final targetPositions = positionsForSymbol(level.layout, 'T');
    final deadTiles = computeDeadTiles(level.layout, targetPositions);
    final loadedState = SokobanGameState(
      levelCatalog: levelCatalog,
      currentLevelIndex: currentLevelIndex,
      playerPosition: level.initialPlayerPosition,
      playerDirection: const BoardPosition(row: 1, column: 0),
      brickPositions: brickPositions,
      targetPositions: targetPositions,
      deadTiles: deadTiles,
      moveHistory: const [],
      stepCount: 0,
    );
    final validationMessage = _validateLoadedLevel(loadedState);
    final deadlockMessage = validationMessage == null
        ? _detectDeadlock(loadedState, brickPositions: brickPositions)
        : null;

    return loadedState.copyWith(
      levelValidationMessage: validationMessage,
      deadlockMessage: deadlockMessage,
    );
  }

  final List<LevelCatalogItem> levelCatalog;
  final int currentLevelIndex;
  final BoardPosition playerPosition;
  final BoardPosition playerDirection;
  final Set<BoardPosition> brickPositions;
  final Set<BoardPosition> targetPositions;
  final Set<BoardPosition> deadTiles;
  final List<GameSnapshot> moveHistory;
  final int stepCount;
  final String? levelValidationMessage;
  final String? deadlockMessage;
  final BoardPosition? hintedBrickPosition;
  final BoardPosition? hintDirection;
  final BoardPosition? hintPushTargetPosition;

  SokobanLevel get currentLevel => levelCatalog[currentLevelIndex].level;

  LevelCatalogItem get currentCatalogItem => levelCatalog[currentLevelIndex];

  List<String> get currentLayout => currentLevel.layout;

  bool get canUndo => moveHistory.isNotEmpty;

  int get boxesOnTargetCount {
    return brickPositions.where(targetPositions.contains).length;
  }

  bool get isLevelComplete {
    return targetPositions.isNotEmpty &&
        boxesOnTargetCount == targetPositions.length;
  }

  Iterable<BoardPosition> get visibleBoardPositions {
    return <BoardPosition>{
      playerPosition,
      ...brickPositions,
      ...targetPositions,
      ?hintedBrickPosition,
      ?hintPushTargetPosition,
    };
  }

  double get boardAspectRatio {
    return BoardViewportSize.forLayout(
      currentLayout,
      visiblePositions: visibleBoardPositions,
    ).aspectRatio;
  }

  GameSnapshot createSnapshot() {
    return GameSnapshot(
      playerPosition: playerPosition,
      brickPositions: brickPositions,
      stepCount: stepCount,
    );
  }

  SokobanGameState copyWith({
    List<LevelCatalogItem>? levelCatalog,
    int? currentLevelIndex,
    BoardPosition? playerPosition,
    BoardPosition? playerDirection,
    Set<BoardPosition>? brickPositions,
    Set<BoardPosition>? targetPositions,
    Set<BoardPosition>? deadTiles,
    List<GameSnapshot>? moveHistory,
    int? stepCount,
    Object? levelValidationMessage = _unchanged,
    Object? deadlockMessage = _unchanged,
    Object? hintedBrickPosition = _unchanged,
    Object? hintDirection = _unchanged,
    Object? hintPushTargetPosition = _unchanged,
  }) {
    return SokobanGameState(
      levelCatalog: levelCatalog ?? this.levelCatalog,
      currentLevelIndex: currentLevelIndex ?? this.currentLevelIndex,
      playerPosition: playerPosition ?? this.playerPosition,
      playerDirection: playerDirection ?? this.playerDirection,
      brickPositions: brickPositions ?? this.brickPositions,
      targetPositions: targetPositions ?? this.targetPositions,
      deadTiles: deadTiles ?? this.deadTiles,
      moveHistory: moveHistory ?? this.moveHistory,
      stepCount: stepCount ?? this.stepCount,
      levelValidationMessage: identical(levelValidationMessage, _unchanged)
          ? this.levelValidationMessage
          : levelValidationMessage as String?,
      deadlockMessage: identical(deadlockMessage, _unchanged)
          ? this.deadlockMessage
          : deadlockMessage as String?,
      hintedBrickPosition: identical(hintedBrickPosition, _unchanged)
          ? this.hintedBrickPosition
          : hintedBrickPosition as BoardPosition?,
      hintDirection: identical(hintDirection, _unchanged)
          ? this.hintDirection
          : hintDirection as BoardPosition?,
      hintPushTargetPosition: identical(hintPushTargetPosition, _unchanged)
          ? this.hintPushTargetPosition
          : hintPushTargetPosition as BoardPosition?,
    );
  }

  SokobanGameState clearActiveHint() {
    return copyWith(
      hintedBrickPosition: null,
      hintDirection: null,
      hintPushTargetPosition: null,
    );
  }
}

class GameController extends Notifier<SokobanGameState> {
  static const int _hintSolverMaxVisitedStates = 8000;

  final Map<String, SokobanHintPathIndex> _standardHintPathIndexes =
      <String, SokobanHintPathIndex>{};
  SokobanHintPathIndex? _runtimeHintPathIndex;
  String? _runtimeHintPathLevelId;

  @override
  SokobanGameState build() {
    _clearRuntimeHintPathCache();
    final levelCatalog = ref.watch(activeLevelCatalogProvider);
    final initialLevelIndex = ref.watch(gameInitialLevelIndexProvider);

    return SokobanGameState.load(
      levelCatalog: levelCatalog,
      levelIndex: initialLevelIndex,
    );
  }

  GameActionMessage? loadedLevelStatusMessage() {
    return _loadedLevelStatusMessage(state);
  }

  GameActionMessage? resetCurrentLevel() {
    _clearRuntimeHintPathCache();
    state = SokobanGameState.load(
      levelCatalog: state.levelCatalog,
      levelIndex: state.currentLevelIndex,
    );
    return loadedLevelStatusMessage();
  }

  GameActionMessage? changeLevel(int levelIndex) {
    if (levelIndex < 0 ||
        levelIndex >= state.levelCatalog.length ||
        levelIndex == state.currentLevelIndex) {
      return null;
    }

    _clearRuntimeHintPathCache();
    state = SokobanGameState.load(
      levelCatalog: state.levelCatalog,
      levelIndex: levelIndex,
    );
    return loadedLevelStatusMessage();
  }

  void undoMove() {
    if (!state.canUndo) {
      return;
    }

    final nextHistory = List<GameSnapshot>.from(state.moveHistory);
    final snapshot = nextHistory.removeLast();
    final nextBrickPositions = Set<BoardPosition>.from(snapshot.brickPositions);
    final nextDeadlockMessage = state.levelValidationMessage == null
        ? _detectDeadlock(state, brickPositions: nextBrickPositions)
        : null;

    state = state.copyWith(
      playerPosition: snapshot.playerPosition,
      brickPositions: nextBrickPositions,
      moveHistory: nextHistory,
      stepCount: snapshot.stepCount,
      deadlockMessage: nextDeadlockMessage,
      hintedBrickPosition: null,
      hintDirection: null,
      hintPushTargetPosition: null,
    );
  }

  GameActionMessage? movePlayer(int rowOffset, int columnOffset) {
    final currentState = state;
    if (currentState.levelValidationMessage != null) {
      return null;
    }

    final moveDirection = BoardPosition(row: rowOffset, column: columnOffset);
    final snapshot = currentState.createSnapshot();
    final nextPosition = currentState.playerPosition.move(
      rowOffset,
      columnOffset,
    );

    if (_isBrickAt(currentState, nextPosition)) {
      final nextBrickPosition = nextPosition.move(rowOffset, columnOffset);
      if (!_isWalkableFloor(currentState, nextBrickPosition)) {
        state = currentState.copyWith(playerDirection: moveDirection);
        return null;
      }

      final nextBrickPositions =
          Set<BoardPosition>.from(currentState.brickPositions)
            ..remove(nextPosition)
            ..add(nextBrickPosition);
      final nextDeadlockMessage = _detectDeadlock(
        currentState,
        brickPositions: nextBrickPositions,
        movedBrickPosition: nextBrickPosition,
      );

      state = currentState.copyWith(
        brickPositions: nextBrickPositions,
        playerPosition: nextPosition,
        playerDirection: moveDirection,
        moveHistory: [...currentState.moveHistory, snapshot],
        stepCount: currentState.stepCount + 1,
        deadlockMessage: nextDeadlockMessage,
        hintedBrickPosition: null,
        hintDirection: null,
        hintPushTargetPosition: null,
      );

      if (state.isLevelComplete) {
        return const GameActionMessage.completion();
      }
      if (nextDeadlockMessage != null) {
        return GameActionMessage.deadlock(nextDeadlockMessage);
      }
      return null;
    }

    if (!_isWalkableFloor(currentState, nextPosition)) {
      state = currentState.copyWith(playerDirection: moveDirection);
      return null;
    }

    state = currentState.copyWith(
      playerPosition: nextPosition,
      playerDirection: moveDirection,
      moveHistory: [...currentState.moveHistory, snapshot],
      stepCount: currentState.stepCount + 1,
      hintedBrickPosition: null,
      hintDirection: null,
      hintPushTargetPosition: null,
    );
    return null;
  }

  GameActionMessage showHint() {
    final currentState = state;

    if (currentState.levelValidationMessage != null) {
      state = currentState.clearActiveHint();
      return GameActionMessage.status(
        title: '关卡无效',
        message: currentState.levelValidationMessage!,
      );
    }

    if (currentState.isLevelComplete) {
      state = currentState.clearActiveHint();
      return const GameActionMessage.completion();
    }

    if (currentState.deadlockMessage != null) {
      state = currentState.clearActiveHint();
      return GameActionMessage.deadlock(currentState.deadlockMessage!);
    }

    final standardPathIndex = _standardHintPathIndexForState(currentState);
    if (standardPathIndex != null) {
      final standardHint = standardPathIndex.hintForState(
        layout: currentState.currentLayout,
        playerPosition: currentState.playerPosition,
        brickPositions: currentState.brickPositions,
      );
      if (standardHint != null) {
        return _showPushHint(currentState, standardHint);
      }

      return _showStandardPathRecoveryHint(currentState, standardPathIndex);
    }

    final cachedHint = _runtimeHintForState(currentState);
    if (cachedHint != null) {
      return _showPushHint(currentState, cachedHint);
    }

    final searchResult = findNextSokobanPushHint(
      layout: currentState.currentLayout,
      playerPosition: currentState.playerPosition,
      brickPositions: currentState.brickPositions,
      targetPositions: currentState.targetPositions,
      deadTiles: currentState.deadTiles,
      maxVisitedStates: _hintSolverMaxVisitedStates,
    );

    switch (searchResult.status) {
      case SokobanHintSearchStatus.alreadySolved:
        _clearRuntimeHintPathCache();
        state = currentState.clearActiveHint();
        return const GameActionMessage.completion();
      case SokobanHintSearchStatus.found:
        _cacheRuntimeHintPath(currentState, searchResult.solution);
        return _showPushHint(currentState, searchResult.hint!);
      case SokobanHintSearchStatus.noSolution:
        state = currentState.clearActiveHint();
        return const GameActionMessage.hint('当前局面已确认无可通关路径，建议撤销几步或重置本关。');
      case SokobanHintSearchStatus.searchLimitReached:
        state = currentState.clearActiveHint();
        return const GameActionMessage.hint('这个局面较复杂，暂时无法确认下一步');
    }
  }

  SokobanHintPathIndex? _standardHintPathIndexForState(
    SokobanGameState currentState,
  ) {
    if (currentState.currentCatalogItem.source != LevelSource.builtIn) {
      return null;
    }

    final solution = currentState.currentCatalogItem.standardSolution;
    if (solution.isEmpty) {
      return null;
    }

    final index = _standardHintPathIndexes.putIfAbsent(
      currentState.currentCatalogItem.id,
      () => SokobanHintPathIndex.fromSolution(
        layout: currentState.currentLayout,
        initialPlayerPosition: currentState.currentLevel.initialPlayerPosition,
        initialBrickPositions: positionsForSymbol(
          currentState.currentLayout,
          'B',
        ),
        solution: solution,
      ),
    );
    if (index.isEmpty) {
      return null;
    }

    return index;
  }

  SokobanPushHint? _runtimeHintForState(SokobanGameState currentState) {
    final pathIndex = _runtimeHintPathIndex;
    if (pathIndex == null ||
        _runtimeHintPathLevelId != currentState.currentCatalogItem.id) {
      return null;
    }

    return pathIndex.hintForState(
      layout: currentState.currentLayout,
      playerPosition: currentState.playerPosition,
      brickPositions: currentState.brickPositions,
    );
  }

  void _cacheRuntimeHintPath(
    SokobanGameState currentState,
    List<SokobanPushHint> solution,
  ) {
    if (solution.isEmpty) {
      _clearRuntimeHintPathCache();
      return;
    }

    final pathIndex = SokobanHintPathIndex.fromSolution(
      layout: currentState.currentLayout,
      initialPlayerPosition: currentState.playerPosition,
      initialBrickPositions: currentState.brickPositions,
      solution: solution,
    );
    if (pathIndex.isEmpty) {
      _clearRuntimeHintPathCache();
      return;
    }

    _runtimeHintPathLevelId = currentState.currentCatalogItem.id;
    _runtimeHintPathIndex = pathIndex;
  }

  void _clearRuntimeHintPathCache() {
    _runtimeHintPathLevelId = null;
    _runtimeHintPathIndex = null;
  }

  GameActionMessage _showPushHint(
    SokobanGameState currentState,
    SokobanPushHint hint,
  ) {
    final hintMessage = _formatPushHint(hint);

    state = currentState.copyWith(
      hintedBrickPosition: hint.brickPosition,
      hintDirection: hint.direction,
      hintPushTargetPosition: hint.nextBrickPosition,
    );

    return GameActionMessage.hint(hintMessage);
  }

  GameActionMessage _showStandardPathRecoveryHint(
    SokobanGameState currentState,
    SokobanHintPathIndex standardPathIndex,
  ) {
    final recovery = _standardPathRecovery(currentState, standardPathIndex);

    state = currentState.clearActiveHint();
    if (recovery == null) {
      return const GameActionMessage.hint(
        '当前走法已经偏离标准答案，且没有找到可撤销的正确节点。建议重置本关后再按提示路线继续。',
      );
    }

    return GameActionMessage.hint(
      '当前走法已经偏离标准答案。请先撤销 ${recovery.undoCount} 步，回到第 ${recovery.stepCount} 步，再点击提示继续。',
    );
  }

  _StandardPathRecovery? _standardPathRecovery(
    SokobanGameState currentState,
    SokobanHintPathIndex standardPathIndex,
  ) {
    for (var index = currentState.moveHistory.length - 1; index >= 0; index--) {
      final snapshot = currentState.moveHistory[index];
      final hint = standardPathIndex.hintForState(
        layout: currentState.currentLayout,
        playerPosition: snapshot.playerPosition,
        brickPositions: snapshot.brickPositions,
      );
      if (hint != null) {
        return _StandardPathRecovery(
          undoCount: currentState.moveHistory.length - index,
          stepCount: snapshot.stepCount,
        );
      }
    }

    return null;
  }
}

class _StandardPathRecovery {
  const _StandardPathRecovery({
    required this.undoCount,
    required this.stepCount,
  });

  final int undoCount;
  final int stepCount;
}

int _normalisedLevelIndex(int levelIndex, int levelCount) {
  if (levelIndex < 0) {
    return 0;
  }

  if (levelIndex >= levelCount) {
    return levelCount - 1;
  }

  return levelIndex;
}

GameActionMessage? _loadedLevelStatusMessage(SokobanGameState state) {
  final issueMessage = state.levelValidationMessage ?? state.deadlockMessage;
  if (issueMessage != null) {
    final title = state.levelValidationMessage != null ? '关卡无效' : '死局';
    return GameActionMessage.status(title: title, message: issueMessage);
  }

  if (state.isLevelComplete) {
    return const GameActionMessage.completion();
  }

  return null;
}

String? _validateLoadedLevel(SokobanGameState state) {
  final layout = state.currentLayout;
  if (layout.isEmpty || layout.first.isEmpty) {
    return '关卡布局不能为空。';
  }

  final expectedColumnCount = layout.first.length;
  if (layout.any((row) => row.length != expectedColumnCount)) {
    return '关卡布局必须是规则矩形，每一行长度都要一致。';
  }

  if (state.brickPositions.isEmpty || state.targetPositions.isEmpty) {
    return '关卡至少需要一个箱子和一个目标点。';
  }

  if (state.brickPositions.length != state.targetPositions.length) {
    return '箱子数量必须与目标点数量一致。';
  }

  if (!isFloorTile(layout, state.playerPosition)) {
    return '玩家初始位置必须位于可通行地块。';
  }

  if (state.brickPositions.contains(state.playerPosition)) {
    return '玩家初始位置不能和箱子重叠。';
  }

  for (final brickPosition in state.brickPositions) {
    if (!state.targetPositions.contains(brickPosition) &&
        state.deadTiles.contains(brickPosition)) {
      return '当前关卡开局就有箱子落在死格，初始状态无解。';
    }
  }

  return null;
}

String? _detectDeadlock(
  SokobanGameState state, {
  required Set<BoardPosition> brickPositions,
  BoardPosition? movedBrickPosition,
}) {
  if (isSolvedState(brickPositions, state.targetPositions)) {
    return null;
  }

  for (final brickPosition in brickPositions) {
    if (!state.targetPositions.contains(brickPosition) &&
        (state.deadTiles.contains(brickPosition) ||
            isNonTargetCornerDeadlock(
              state.currentLayout,
              state.targetPositions,
              brickPosition,
            ))) {
      return '箱子被推入死格，当前状态已无解，建议撤销或重置。';
    }
  }

  final deadlockAnchors = movedBrickPosition == null
      ? brickPositions
      : <BoardPosition>{movedBrickPosition};
  for (final anchorPosition in deadlockAnchors) {
    if (formsFrozenSquareDeadlock(
      state.currentLayout,
      brickPositions,
      state.targetPositions,
      anchorPosition,
    )) {
      return '箱子形成 2x2 锁死块，当前状态已无解，建议撤销或重置。';
    }

    if (formsFreezeDeadlock(
      layout: state.currentLayout,
      brickPositions: brickPositions,
      targetPositions: state.targetPositions,
      deadTiles: state.deadTiles,
      anchorPosition: anchorPosition,
    )) {
      return '箱子被墙体或其他箱子冻结，当前状态已无解，建议撤销或重置。';
    }
  }

  return null;
}

bool _isWalkableFloor(SokobanGameState state, BoardPosition position) {
  if (!_isInsideBoard(state, position)) {
    return false;
  }

  final nextTile = tileAt(state.currentLayout, position.row, position.column);
  return nextTile == BoardTile.floor && !_isBrickAt(state, position);
}

bool _isInsideBoard(SokobanGameState state, BoardPosition position) {
  if (position.row < 0 || position.row >= state.currentLayout.length) {
    return false;
  }

  return position.column >= 0 &&
      position.column < state.currentLayout[position.row].length;
}

bool _isBrickAt(SokobanGameState state, BoardPosition position) {
  return state.brickPositions.contains(position);
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
