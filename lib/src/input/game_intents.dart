import 'package:flutter/widgets.dart';

class MoveIntent extends Intent {
  const MoveIntent(this.rowOffset, this.columnOffset);

  final int rowOffset;
  final int columnOffset;
}

class UndoIntent extends Intent {
  const UndoIntent();
}
