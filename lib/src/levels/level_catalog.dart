import 'package:flutter/services.dart';

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

Future<List<LevelCatalogItem>> loadBuiltInLevelCatalog({
  AssetBundle? bundle,
}) async {
  return buildBuiltInLevelCatalog(await loadSokobanLevels(bundle: bundle));
}

List<LevelCatalogItem> buildBuiltInLevelCatalog(List<SokobanLevel> levels) {
  final catalog = <LevelCatalogItem>[];
  for (var index = 0; index < levels.length; index++) {
    catalog.add(
      LevelCatalogItem(
        id: 'built_in_${index + 1}',
        source: LevelSource.builtIn,
        level: levels[index],
      ),
    );
  }

  return List<LevelCatalogItem>.unmodifiable(catalog);
}
