import 'dart:math' as math;

class BoardViewportSize {
  const BoardViewportSize({required this.rows, required this.columns})
    : assert(rows > 0),
      assert(columns > 0);

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
      rows: math.max(1, layoutRows),
      columns: math.max(1, layoutColumns),
    );
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
