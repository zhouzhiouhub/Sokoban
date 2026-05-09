import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

const List<String> boardLayout = [
  '##########',
  '#   B    #',
  '#  ####  #',
  '#  #  #  #',
  '#  # B####',
  '#  #     #',
  '#  ### # #',
  '#   B  # #',
  '##########',
];

const BoardPosition initialPlayerPosition = BoardPosition(row: 1, column: 1);

enum BoardTile { wall, floor, brick }

class BoardPosition {
  const BoardPosition({required this.row, required this.column});

  final int row;
  final int column;

  BoardPosition move(int rowOffset, int columnOffset) {
    return BoardPosition(row: row + rowOffset, column: column + columnOffset);
  }
}

class MoveIntent extends Intent {
  const MoveIntent(this.rowOffset, this.columnOffset);

  final int rowOffset;
  final int columnOffset;
}

BoardTile tileAt(List<String> layout, int row, int column) {
  return switch (layout[row][column]) {
    '#' => BoardTile.wall,
    'B' => BoardTile.brick,
    _ => BoardTile.floor,
  };
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
  BoardPosition _playerPosition = initialPlayerPosition;

  void _movePlayer(int rowOffset, int columnOffset) {
    final nextPosition = _playerPosition.move(rowOffset, columnOffset);
    if (!_isWalkable(nextPosition)) {
      return;
    }

    setState(() {
      _playerPosition = nextPosition;
    });
  }

  bool _isWalkable(BoardPosition position) {
    if (position.row < 0 || position.row >= boardLayout.length) {
      return false;
    }

    if (position.column < 0 || position.column >= boardLayout[position.row].length) {
      return false;
    }

    final nextTile = tileAt(boardLayout, position.row, position.column);
    return nextTile != BoardTile.wall && nextTile != BoardTile.brick;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EFE7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF526652),
        foregroundColor: Colors.white,
        title: const Text('推箱子 - 可移动角色'),
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
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              MoveIntent: CallbackAction<MoveIntent>(
                onInvoke: (intent) {
                  _movePlayer(intent.rowOffset, intent.columnOffset);
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
                              boardLayout.first.length / boardLayout.length;
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
                                  layout: boardLayout,
                                  playerPosition: _playerPosition,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '小人只能移动到墙体内部的无砖地面，可用方向键或按钮控制。',
                      textAlign: TextAlign.center,
                    ),
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
    required this.playerPosition,
  });

  final List<String> layout;
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
                          final tile = tileAt(layout, row, column);
                          final hasPlayer =
                              playerPosition.row == row &&
                              playerPosition.column == column;

                          return SokobanTile(
                            key: ValueKey('${tile.name}-$row-$column-$hasPlayer'),
                            tile: tile,
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
    required this.hasPlayer,
  });

  final BoardTile tile;
  final bool hasPlayer;

  @override
  Widget build(BuildContext context) {
    final semanticsLabel = switch (tile) {
      BoardTile.wall => '墙体',
      BoardTile.brick => '砖块',
      BoardTile.floor => hasPlayer ? '人物所在位置' : '地面',
    };

    final backgroundColor = switch (tile) {
      BoardTile.wall => const Color(0xFF3F493A),
      BoardTile.brick => const Color(0xFFA86A3D),
      BoardTile.floor => const Color(0xFFD8CFB9),
    };

    final borderColor = switch (tile) {
      BoardTile.wall => const Color(0xFF222820),
      BoardTile.brick => const Color(0xFF7A4B27),
      BoardTile.floor => const Color(0xFFC9BFA8),
    };

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
            child: switch (tile) {
              BoardTile.wall => const Center(
                child: Icon(Icons.square, color: Color(0xFF5F7257), size: 14),
              ),
              BoardTile.brick => Padding(
                padding: const EdgeInsets.all(5),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFC98A55),
                    border: Border.all(color: const Color(0xFF74441E), width: 1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              BoardTile.floor => const SizedBox.expand(),
            },
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
