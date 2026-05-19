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
    this.playerDirection = const BoardPosition(row: 1, column: 0),
    this.hintedBrickPosition,
    this.hintDirection,
    this.hintPushTargetPosition,
  });

  static BoardViewportSize viewportSizeForLayout(
    List<String> layout, {
    Iterable<BoardPosition> visiblePositions = const <BoardPosition>[],
  }) {
    return BoardViewportSize.forLayout(
      layout,
      visiblePositions: visiblePositions,
    );
  }

  static BoardViewportRegion viewportRegionForLayout(
    List<String> layout, {
    Iterable<BoardPosition> visiblePositions = const <BoardPosition>[],
  }) {
    return BoardViewportRegion.forLayout(
      layout,
      visiblePositions: visiblePositions,
    );
  }

  final List<String> layout;
  final Set<BoardPosition> brickPositions;
  final Set<BoardPosition> targetPositions;
  final BoardPosition playerPosition;
  final BoardPosition playerDirection;
  final BoardPosition? hintedBrickPosition;
  final BoardPosition? hintDirection;
  final BoardPosition? hintPushTargetPosition;

  Iterable<BoardPosition> get _visiblePositions {
    return <BoardPosition>{
      playerPosition,
      ...brickPositions,
      ...targetPositions,
      ?hintedBrickPosition,
      ?hintPushTargetPosition,
    };
  }

  @override
  Widget build(BuildContext context) {
    final viewportRegion = viewportRegionForLayout(
      layout,
      visiblePositions: _visiblePositions,
    );
    final viewportSize = viewportRegion.size;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFE4DDCF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF454337), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
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
                          final row = viewportRegion.firstRow + viewportRow;
                          final column =
                              viewportRegion.firstColumn + viewportColumn;
                          final isLevelCell =
                              row >= 0 &&
                              row < layout.length &&
                              column >= 0 &&
                              column < layout[row].length;

                          if (!isLevelCell) {
                            return SokobanTile(
                              tile: BoardTile.empty,
                              isTarget: false,
                              hasPlayer: false,
                              visualRow: row,
                              visualColumn: column,
                            );
                          }

                          final position = BoardPosition(
                            row: row,
                            column: column,
                          );
                          final tile = brickPositions.contains(position)
                              ? BoardTile.brick
                              : tileAt(layout, row, column);
                          final isTarget = targetPositions.contains(position);
                          final isHintedBrick =
                              hintedBrickPosition == position &&
                              tile == BoardTile.brick;
                          final isHintPushTarget =
                              hintPushTargetPosition == position;
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
                            visualRow: row,
                            visualColumn: column,
                            wallEdges: _wallEdgesForCell(
                              layout: layout,
                              row: row,
                              column: column,
                            ),
                            playerDirection: playerDirection,
                            isHintedBrick: isHintedBrick,
                            isHintPushTarget: isHintPushTarget,
                            hintDirection: isHintedBrick ? hintDirection : null,
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

Set<SokobanTileEdge> _wallEdgesForCell({
  required List<String> layout,
  required int row,
  required int column,
}) {
  final edges = <SokobanTileEdge>{};

  if (_isWallAt(layout, row - 1, column)) {
    edges.add(SokobanTileEdge.top);
  }
  if (_isWallAt(layout, row, column + 1)) {
    edges.add(SokobanTileEdge.right);
  }
  if (_isWallAt(layout, row + 1, column)) {
    edges.add(SokobanTileEdge.bottom);
  }
  if (_isWallAt(layout, row, column - 1)) {
    edges.add(SokobanTileEdge.left);
  }

  return edges;
}

bool _isWallAt(List<String> layout, int row, int column) {
  if (row < 0 || row >= layout.length) {
    return false;
  }
  if (column < 0 || column >= layout[row].length) {
    return false;
  }

  return tileAt(layout, row, column) == BoardTile.wall;
}
