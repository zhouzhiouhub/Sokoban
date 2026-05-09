class BoardPosition {
  const BoardPosition({required this.row, required this.column});

  final int row;
  final int column;

  BoardPosition move(int rowOffset, int columnOffset) {
    return BoardPosition(row: row + rowOffset, column: column + columnOffset);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is BoardPosition && other.row == row && other.column == column;
  }

  @override
  int get hashCode => Object.hash(row, column);
}
