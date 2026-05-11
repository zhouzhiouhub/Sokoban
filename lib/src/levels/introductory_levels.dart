import '../models/board_position.dart';
import '../models/sokoban_level.dart';
import 'level_copy.dart';

final List<SokobanLevel> introductoryLevels = [
  SokobanLevel(
    number: 1,
    title: levelCopy[0].title,
    description: levelCopy[0].description,
    layout: [
      '_______________',
      '_______________',
      '_____###_______',
      '_____#T#_______',
      '____##B####____',
      '____#TB BT#____',
      '____###B###____',
      '______#T#______',
      '______###______',
      '_______________',
    ],
    initialPlayerPosition: BoardPosition(row: 5, column: 7),
  ),
];
