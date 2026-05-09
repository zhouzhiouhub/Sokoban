import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  test('wall layout is a fixed rectangular grid', () {
    expect(wallLayout.length, 9);
    expect(wallLayout.every((row) => row.length == 10), isTrue);
  });

  testWidgets('renders the initial Sokoban wall layout', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('推箱子 - 墙体'), findsOneWidget);
    expect(find.byType(SokobanBoard), findsOneWidget);
    expect(_tilesWithPrefix('wall-'), findsNWidgets(wallTileCount));
    expect(_tilesWithPrefix('floor-'), findsNWidgets(floorTileCount));
  });
}

Finder _tilesWithPrefix(String prefix) {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith(prefix);
  });
}
