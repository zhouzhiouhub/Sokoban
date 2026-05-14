import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/sokoban_rules.dart';
import '../models/board_position.dart';
import '../models/board_tile.dart';
import '../models/board_viewport_size.dart';
import 'sokoban_tile.dart';

class SokobanBoard extends StatelessWidget {
  const SokobanBoard({
    super.key,
    required this.layout,
    required this.brickPositions,
    required this.targetPositions,
    required this.playerPosition,
  });

  static const int minRowCount = BoardViewportSize.minRows;
  static const int minColumnCount = BoardViewportSize.minColumns;
  static const int maxRowCount = BoardViewportSize.maxRows;
  static const int maxColumnCount = BoardViewportSize.maxColumns;

  static BoardViewportSize viewportSizeForLayout(List<String> layout) {
    return BoardViewportSize.forLayout(layout);
  }

  final List<String> layout;
  final Set<BoardPosition> brickPositions;
  final Set<BoardPosition> targetPositions;
  final BoardPosition playerPosition;

  @override
  Widget build(BuildContext context) {
    final viewportSize = viewportSizeForLayout(layout);
    final rowOffset = ((viewportSize.rows - layout.length) / 2).floor();
    final layoutColumnCount = layout.fold<int>(
      0,
      (currentMax, row) => math.max(currentMax, row.length),
    );
    final columnOffset = ((viewportSize.columns - layoutColumnCount) / 2)
        .floor();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE3DBC9),
        border: Border.all(color: const Color(0xFF2E352D), width: 4),
      ),
      child: Column(
        children: [
          for (
            var viewportRow = 0;
            viewportRow < viewportSize.rows;
            viewportRow++
          )
            Expanded(
              child: Row(
                children: [
                  for (
                    var viewportColumn = 0;
                    viewportColumn < viewportSize.columns;
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
                            final isViewportBoundary =
                                viewportRow == 0 ||
                                viewportColumn == 0 ||
                                viewportRow == viewportSize.rows - 1 ||
                                viewportColumn == viewportSize.columns - 1;

                            return isViewportBoundary
                                ? const _ViewportWallCell()
                                : const _ViewportFloorCell();
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

class _ViewportFloorCell extends StatelessWidget {
  const _ViewportFloorCell();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: Color(0xFFD8CFB9),
        border: Border.fromBorderSide(
          BorderSide(color: Color(0xFFC9BFA8), width: 0.7),
        ),
      ),
    );
  }
}

class _ViewportWallCell extends StatelessWidget {
  const _ViewportWallCell();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '墙体',
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFF3F493A),
              border: Border.fromBorderSide(
                BorderSide(color: Color(0xFF222820), width: 0.7),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final iconSize =
                  math.min(constraints.maxWidth, constraints.maxHeight) * 0.55;

              return Center(
                child: Icon(
                  Icons.square,
                  color: const Color(0xFF5F7257),
                  size: math.min(14.0, iconSize),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
