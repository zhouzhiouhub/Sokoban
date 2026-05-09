import 'package:flutter/material.dart';

import '../game/sokoban_rules.dart';
import '../models/board_position.dart';
import '../models/board_tile.dart';
import 'sokoban_tile.dart';

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
                          final position = BoardPosition(
                            row: row,
                            column: column,
                          );
                          final tile = brickPositions.contains(position)
                              ? BoardTile.brick
                              : tileAt(layout, row, column);
                          final isTarget = targetPositions.contains(position);
                          final hasPlayer =
                              playerPosition.row == row &&
                              playerPosition.column == column;

                          return SokobanTile(
                            key: ValueKey(
                              '${tile.name}-$row-$column-$hasPlayer',
                            ),
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
