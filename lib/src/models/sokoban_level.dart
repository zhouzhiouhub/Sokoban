import 'board_position.dart';

class SokobanLevel {
  const SokobanLevel({
    required this.number,
    required this.title,
    required this.description,
    required this.layout,
    required this.initialPlayerPosition,
  });

  final int number;
  final String title;
  final String description;
  final List<String> layout;
  final BoardPosition initialPlayerPosition;

  String get displayName => 'Level $number — $title';
}
