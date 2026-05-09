import 'dart:math' as math;

import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

const List<String> wallLayout = [
  '##########',
  '#        #',
  '#  ####  #',
  '#  #  #  #',
  '#  #  ####',
  '#  #     #',
  '#  ### # #',
  '#      # #',
  '##########',
];

const int wallTileCount = 50;
const int floorTileCount = 40;

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

class SokobanWallPage extends StatelessWidget {
  const SokobanWallPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EFE7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF526652),
        foregroundColor: Colors.white,
        title: const Text('推箱子 - 墙体'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final boardRatio = wallLayout.first.length / wallLayout.length;
              final boardWidth = math.min(
                constraints.maxWidth,
                constraints.maxHeight * boardRatio,
              );

              return Center(
                child: SizedBox(
                  width: boardWidth,
                  child: AspectRatio(
                    aspectRatio: boardRatio,
                    child: const SokobanBoard(layout: wallLayout),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class SokobanBoard extends StatelessWidget {
  const SokobanBoard({super.key, required this.layout});

  final List<String> layout;

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
                      child: SokobanTile(
                        key: ValueKey(
                          '${_isWall(row, column) ? 'wall' : 'floor'}-$row-$column',
                        ),
                        isWall: _isWall(row, column),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool _isWall(int row, int column) {
    return layout[row][column] == '#';
  }
}

class SokobanTile extends StatelessWidget {
  const SokobanTile({super.key, required this.isWall});

  final bool isWall;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isWall ? '墙体' : '地面',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isWall ? const Color(0xFF3F493A) : const Color(0xFFD8CFB9),
          border: Border.all(
            color: isWall ? const Color(0xFF222820) : const Color(0xFFC9BFA8),
            width: 0.7,
          ),
        ),
        child: isWall
            ? const ColoredBox(
                color: Colors.transparent,
                child: Center(
                  child: Icon(Icons.square, color: Color(0xFF5F7257), size: 14),
                ),
              )
            : const SizedBox.expand(),
      ),
    );
  }
}
