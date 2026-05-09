import '../models/sokoban_level.dart';
import 'advanced_levels.dart';
import 'intermediate_levels.dart';
import 'introductory_levels.dart';

final List<SokobanLevel> sokobanLevels = [
  ...introductoryLevels,
  ...intermediateLevels,
  ...advancedLevels,
];
