import 'dart:math' as math;

class BoardViewportSize {
  const BoardViewportSize({required this.rows, required this.columns})
    : assert(rows > 0),
      assert(columns > 0);

  static const int minRows = 10;
  static const int minColumns = 10;
  static const int maxRows = 20;
  static const int maxColumns = 20;

  final int rows;
  final int columns;

  double get aspectRatio => columns / rows;

  factory BoardViewportSize.forLayout(List<String> layout) {
    final layoutRows = layout.length;
    final layoutColumns = layout.fold<int>(
      0,
      (currentMax, row) => math.max(currentMax, row.length),
    );

    return BoardViewportSize(
      rows: _boundedDimension(layoutRows, minRows, maxRows),
      columns: _boundedDimension(layoutColumns, minColumns, maxColumns),
    );
  }

  static bool supportsLayout(List<String> layout) {
    final layoutRows = layout.length;
    final layoutColumns = layout.fold<int>(
      0,
      (currentMax, row) => math.max(currentMax, row.length),
    );

    return layoutRows <= maxRows && layoutColumns <= maxColumns;
  }
}

int _boundedDimension(int value, int minValue, int maxValue) {
  return math.min(maxValue, math.max(minValue, value));
}
