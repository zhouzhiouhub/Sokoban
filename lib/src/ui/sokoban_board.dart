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

  static const int fixedRowCount = 10;
  static const int fixedColumnCount = 15;

  final List<String> layout;
  final Set<BoardPosition> brickPositions;
  final Set<BoardPosition> targetPositions;
  final BoardPosition playerPosition;

  @override
  Widget build(BuildContext context) {
    final rowOffset = ((fixedRowCount - layout.length) / 2).floor();
    final columnOffset = ((fixedColumnCount - layout.first.length) / 2).floor();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE3DBC9),
        border: Border.all(color: const Color(0xFF2E352D), width: 4),
      ),
      child: Column(
        children: [
          for (var viewportRow = 0; viewportRow < fixedRowCount; viewportRow++)
            Expanded(
              child: Row(
                children: [
                  for (
                    var viewportColumn = 0;
                    viewportColumn < fixedColumnCount;
                    viewportColumn++
                  )
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final row = viewportRow - rowOffset;
                          final column = viewportColumn - columnOffset;
                          final isLevelCell =
                              row >= 0 &&
                              row < layout.length &&
                              column >= 0 &&
                              column < layout[row].length;

                          if (!isLevelCell) {
                            return const _EmptyBoardCell();
                          }

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

class _EmptyBoardCell extends StatelessWidget {
  const _EmptyBoardCell();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: Color(0xFFE3DBC9),
        border: Border.fromBorderSide(
          BorderSide(color: Color(0xFFD3C9B6), width: 0.7),
        ),
      ),
    );
  }
}
