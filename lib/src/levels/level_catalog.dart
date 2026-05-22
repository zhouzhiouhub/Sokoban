import 'package:flutter/services.dart';

import '../game/sokoban_rules.dart';
import '../models/sokoban_level.dart';
import 'sokoban_levels.dart';
import 'sokoban_standard_solutions.dart';

enum LevelSource { builtIn, custom }

class LevelCatalogItem {
  const LevelCatalogItem({
    required this.id,
    required this.source,
    required this.level,
    this.standardSolution = const <SokobanPushHint>[],
  });

  final String id;
  final LevelSource source;
  final SokobanLevel level;
  final List<SokobanPushHint> standardSolution;
}

Future<List<LevelCatalogItem>> loadBuiltInLevelCatalog({
  AssetBundle? bundle,
}) async {
  final levels = await loadSokobanLevels(bundle: bundle);
  final standardSolutions = await loadBuiltInSokobanStandardSolutions(
    bundle: bundle,
  );

  return buildBuiltInLevelCatalog(levels, standardSolutions: standardSolutions);
}

List<LevelCatalogItem> buildBuiltInLevelCatalog(
  List<SokobanLevel> levels, {
  Map<int, List<SokobanPushHint>> standardSolutions =
      const <int, List<SokobanPushHint>>{},
}) {
  final catalog = <LevelCatalogItem>[];
  for (var index = 0; index < levels.length; index++) {
    catalog.add(
      LevelCatalogItem(
        id: 'built_in_${index + 1}',
        source: LevelSource.builtIn,
        level: levels[index],
        standardSolution:
            standardSolutions[levels[index].number] ??
            const <SokobanPushHint>[],
      ),
    );
  }

  return List<LevelCatalogItem>.unmodifiable(catalog);
}
