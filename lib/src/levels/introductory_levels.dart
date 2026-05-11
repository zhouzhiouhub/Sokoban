import '../models/board_position.dart';
import '../models/sokoban_level.dart';
import 'level_copy.dart';

final List<SokobanLevel> introductoryLevels = [
  SokobanLevel(
    number: 1,
    title: levelCopy[0].title,
    description: levelCopy[0].description,
    layout: [
      '###############',
      '#             #',
      '#      T      #',
      '#      B      #',
      '#             #',
      '#   T B B T   #',
      '#      B      #',
      '#      T      #',
      '#             #',
      '###############',
    ],
    initialPlayerPosition: BoardPosition(row: 5, column: 7),
  ),
];
