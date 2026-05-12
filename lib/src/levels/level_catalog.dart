import '../models/sokoban_level.dart';
import 'sokoban_levels.dart';

enum LevelSource { builtIn, custom }

class LevelCatalogItem {
  const LevelCatalogItem({
    required this.id,
    required this.source,
    required this.level,
  });

  final String id;
  final LevelSource source;
  final SokobanLevel level;
}

final List<LevelCatalogItem> builtInLevelCatalog = [
  for (final level in sokobanLevels)
    LevelCatalogItem(
      id: 'built_in_${level.number}',
      source: LevelSource.builtIn,
      level: level,
    ),
];
