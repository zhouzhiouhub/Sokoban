import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_branding.dart';
import '../controllers/game_controller.dart';
import '../input/game_intents.dart';
import '../levels/level_catalog.dart';
import 'movement_controls.dart';
import 'sokoban_board.dart';

class SokobanWallPage extends StatelessWidget {
  const SokobanWallPage({
    super.key,
    this.initialLevelIndex = 0,
    this.levelCatalog,
  }) : assert(levelCatalog == null || levelCatalog.length > 0);

  final int initialLevelIndex;
  final List<LevelCatalogItem>? levelCatalog;

  @override
  Widget build(BuildContext context) {
    final overrides = [
      gameInitialLevelIndexProvider.overrideWithValue(initialLevelIndex),
      if (levelCatalog != null)
        activeLevelCatalogProvider.overrideWithValue(
          List<LevelCatalogItem>.unmodifiable(levelCatalog!),
        ),
    ];

    return ProviderScope(overrides: overrides, child: const _SokobanWallView());
  }
}

class _SokobanWallView extends ConsumerStatefulWidget {
  const _SokobanWallView();

  @override
  ConsumerState<_SokobanWallView> createState() => _SokobanWallViewState();
}

class _SokobanWallViewState extends ConsumerState<_SokobanWallView> {
  static const double _boardHeaderHeight = 48;
  static const double _boardHeaderGap = 8;
  static const double _boardHeaderMinWidth = 220;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _showGameMessage(
        ref.read(gameControllerProvider.notifier).loadedLevelStatusMessage(),
      );
    });
  }

  void _showGameMessage(GameActionMessage? message) {
    if (message == null) {
      return;
    }

    if (message.kind == GameMessageKind.completion) {
      _showCompletionDialog();
      return;
    }

    _showStatusDialog(title: message.title, message: message.message);
  }

  Future<void> _showStatusDialog({
    required String title,
    required String message,
    List<Widget> Function(BuildContext dialogContext)? actionsBuilder,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions:
              actionsBuilder?.call(dialogContext) ??
              [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('知道了'),
                ),
              ],
        );
      },
    );
  }

  void _showCompletionDialog() {
    final gameState = ref.read(gameControllerProvider);
    final hasNextLevel =
        gameState.currentLevelIndex < gameState.levelCatalog.length - 1;

    List<Widget> buildActions(BuildContext dialogContext) {
      return [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('留在本关'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            final controller = ref.read(gameControllerProvider.notifier);
            final message = hasNextLevel
                ? controller.changeLevel(gameState.currentLevelIndex + 1)
                : controller.resetCurrentLevel();
            _showGameMessage(message);
          },
          child: Text(hasNextLevel ? '下一关' : '重玩本关'),
        ),
      ];
    }

    _showStatusDialog(
      title: '过关',
      message: '全部箱子已到目标点，过关！',
      actionsBuilder: buildActions,
    );
  }

  void _movePlayer(int rowOffset, int columnOffset) {
    final message = ref
        .read(gameControllerProvider.notifier)
        .movePlayer(rowOffset, columnOffset);
    _showGameMessage(message);
  }

  void _undoMove() {
    ref.read(gameControllerProvider.notifier).undoMove();
  }

  void _resetCurrentLevel() {
    final message = ref
        .read(gameControllerProvider.notifier)
        .resetCurrentLevel();
    _showGameMessage(message);
  }

  void _showHint() {
    final message = ref.read(gameControllerProvider.notifier).showHint();
    _showGameMessage(message);
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameControllerProvider);
    final isLevelComplete = gameState.isLevelComplete;
    final screenSize = MediaQuery.sizeOf(context);
    final isCompactScreen = screenSize.shortestSide < 420;
    final pagePadding = isCompactScreen ? 10.0 : 16.0;
    final sectionGap = isCompactScreen ? 10.0 : 12.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          appLevelTitle(
            gameState.currentLevel.title,
            isComplete: isLevelComplete,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '撤销一步',
            onPressed: gameState.canUndo ? _undoMove : null,
            icon: const Icon(LucideIcons.undo2),
          ),
          IconButton(
            tooltip: '重置本关',
            onPressed: _resetCurrentLevel,
            icon: const Icon(LucideIcons.refreshCw),
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
                          final boardAspectRatio = gameState.boardAspectRatio;
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
                                    levelNumber: gameState.currentLevel.number,
                                    stepCount: gameState.stepCount,
                                  ),
                                ),
                                const SizedBox(height: _boardHeaderGap),
                                SizedBox(
                                  width: boardWidth,
                                  height: boardHeight,
                                  child: SokobanBoard(
                                    layout: gameState.currentLayout,
                                    brickPositions: gameState.brickPositions,
                                    targetPositions: gameState.targetPositions,
                                    playerPosition: gameState.playerPosition,
                                    playerDirection: gameState.playerDirection,
                                    hintedBrickPosition:
                                        gameState.hintedBrickPosition,
                                    hintDirection: gameState.hintDirection,
                                    hintPushTargetPosition:
                                        gameState.hintPushTargetPosition,
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
          icon: const Icon(LucideIcons.lightbulb),
          label: const Text('提示'),
        ),
      ),
    );
  }
}
