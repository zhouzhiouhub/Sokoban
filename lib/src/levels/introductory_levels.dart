import '../models/board_position.dart';
import '../models/sokoban_level.dart';
import 'level_copy.dart';

final List<SokobanLevel> introductoryLevels = [
  SokobanLevel(
    number: 1,
    title: levelCopy[0].title,
    description: levelCopy[0].description,
    layout: [
      '______###______',
      '______###______',
      '______#T#______',
      '______#B#______',
      '__##### #####__',
      '__# T B B T #__',
      '__#####B#####__',
      '______#T#______',
      '______###______',
      '_______________',
    ],
    initialPlayerPosition: BoardPosition(row: 5, column: 7),
  ),
];
