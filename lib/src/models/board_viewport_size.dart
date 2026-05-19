import 'dart:math' as math;

import 'board_position.dart';

class BoardViewportSize {
  const BoardViewportSize({required this.rows, required this.columns})
    : assert(rows > 0),
      assert(columns > 0);

  final int rows;
  final int columns;

  double get aspectRatio => columns / rows;

  factory BoardViewportSize.forLayout(
    List<String> layout, {
    Iterable<BoardPosition> visiblePositions = const <BoardPosition>[],
  }) {
    return BoardViewportRegion.forLayout(
      layout,
      visiblePositions: visiblePositions,
    ).size;
  }

  static bool supportsLayout(List<String> layout) {
    final layoutRows = layout.length;
    final layoutColumns = layout.fold<int>(
      0,
      (currentMax, row) => math.max(currentMax, row.length),
    );

    return layoutRows > 0 && layoutColumns > 0;
  }
}

class BoardViewportRegion {
  const BoardViewportRegion({
    required this.firstRow,
    required this.firstColumn,
    required this.rows,
    required this.columns,
  }) : assert(firstRow >= 0),
       assert(firstColumn >= 0),
       assert(rows > 0),
       assert(columns > 0);

  final int firstRow;
  final int firstColumn;
  final int rows;
  final int columns;

  int get lastRow => firstRow + rows - 1;

  int get lastColumn => firstColumn + columns - 1;

  BoardViewportSize get size {
    return BoardViewportSize(rows: rows, columns: columns);
  }

  factory BoardViewportRegion.forLayout(
    List<String> layout, {
    Iterable<BoardPosition> visiblePositions = const <BoardPosition>[],
  }) {
    final fallbackRows = math.max(1, layout.length);
    final fallbackColumns = math.max(
      1,
      layout.fold<int>(
        0,
        (currentMax, row) => math.max(currentMax, row.length),
      ),
    );

    int? firstRow;
    int? firstColumn;
    var lastRow = 0;
    var lastColumn = 0;

    void includeCell(int row, int column) {
      if (firstRow == null || row < firstRow!) {
        firstRow = row;
      }
      if (firstColumn == null || column < firstColumn!) {
        firstColumn = column;
      }
      if (row > lastRow) {
        lastRow = row;
      }
      if (column > lastColumn) {
        lastColumn = column;
      }
    }

    for (var row = 0; row < layout.length; row++) {
      final line = layout[row];
      for (var column = 0; column < line.length; column++) {
        if (_isVisibleLayoutAnchor(line[column])) {
          includeCell(row, column);
        }
      }
    }

    for (final position in visiblePositions) {
      if (_isInsideLayout(layout, position)) {
        includeCell(position.row, position.column);
      }
    }

    if (firstRow == null || firstColumn == null) {
      return BoardViewportRegion(
        firstRow: 0,
        firstColumn: 0,
        rows: fallbackRows,
        columns: fallbackColumns,
      );
    }

    return BoardViewportRegion(
      firstRow: firstRow!,
      firstColumn: firstColumn!,
      rows: lastRow - firstRow! + 1,
      columns: lastColumn - firstColumn! + 1,
    );
  }
}

bool _isVisibleLayoutAnchor(String cell) {
  return cell != ' ' && cell != '_';
}

bool _isInsideLayout(List<String> layout, BoardPosition position) {
  if (position.row < 0 || position.row >= layout.length) {
    return false;
  }

  return position.column >= 0 && position.column < layout[position.row].length;
}
