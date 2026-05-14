import 'board_position.dart';

class SokobanLevel {
  const SokobanLevel({
    required this.number,
    required this.title,
    required this.description,
    required this.layout,
    required this.initialPlayerPosition,
    this.hintTexts = const [],
  });

  final int number;
  final String title;
  final String description;
  final List<String> layout;
  final BoardPosition initialPlayerPosition;
  final List<String> hintTexts;

  String get displayName => 'Level $number — $title';
}
