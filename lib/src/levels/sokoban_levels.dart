import 'package:flutter/services.dart';

import '../models/sokoban_level.dart';
import 'sokoban_level_import.dart';

const String generatedLevelAssetDirectory = 'tools/generated_levels/';
const SokobanLevelValidationOptions _generatedLevelValidationOptions =
    SokobanLevelValidationOptions(validateInitialDeadTiles: false);

Future<List<SokobanLevel>> loadSokobanLevels({AssetBundle? bundle}) async {
  final effectiveBundle = bundle ?? rootBundle;
  final manifest = await AssetManifest.loadFromAssetBundle(effectiveBundle);
  final assetPaths =
      manifest.listAssets().where(_isGeneratedLevelAsset).toList()..sort();

  if (assetPaths.isEmpty) {
    throw const SokobanLevelImportException(
      '未找到生成关卡资源：tools/generated_levels/。',
    );
  }

  final loadedLevels = await Future.wait(
    assetPaths.map((assetPath) async {
      final source = await effectiveBundle.loadString(assetPath);
      return _LoadedSokobanLevel(
        assetPath: assetPath,
        level: _parseGeneratedLevelAsset(assetPath, source),
      );
    }),
  );

  final levels = _deduplicateExactLevels(loadedLevels)
    ..sort(_compareLoadedLevels);
  return List<SokobanLevel>.unmodifiable(
    levels.map((loadedLevel) => loadedLevel.level),
  );
}

bool _isGeneratedLevelAsset(String assetPath) {
  return assetPath.startsWith(generatedLevelAssetDirectory) &&
      (assetPath.endsWith('.json') || assetPath.endsWith('.dart.txt'));
}

SokobanLevel _parseGeneratedLevelAsset(String assetPath, String source) {
  try {
    if (assetPath.endsWith('.json')) {
      return parseImportedSokobanLevelJson(
        source,
        options: _generatedLevelValidationOptions,
      );
    }
    return parseGeneratedSokobanLevelDartSnippet(
      source,
      options: _generatedLevelValidationOptions,
    );
  } on SokobanLevelImportException catch (error) {
    throw SokobanLevelImportException(
      '生成关卡文件 `$assetPath` 无法解析：${error.message}',
    );
  }
}

List<_LoadedSokobanLevel> _deduplicateExactLevels(
  List<_LoadedSokobanLevel> loadedLevels,
) {
  final levelsByKey = <String, _LoadedSokobanLevel>{};
  for (final loadedLevel in loadedLevels) {
    final key = _levelIdentityKey(loadedLevel.level);
    final previousLevel = levelsByKey[key];
    if (previousLevel == null ||
        _assetPriority(loadedLevel.assetPath) >
            _assetPriority(previousLevel.assetPath)) {
      levelsByKey[key] = loadedLevel;
    }
  }

  return levelsByKey.values.toList();
}

String _levelIdentityKey(SokobanLevel level) {
  return [
    level.number,
    level.title,
    level.description,
    level.initialPlayerPosition.row,
    level.initialPlayerPosition.column,
    ...level.layout,
  ].join('\u001f');
}

int _assetPriority(String assetPath) {
  return assetPath.endsWith('.json') ? 1 : 0;
}

int _compareLoadedLevels(_LoadedSokobanLevel a, _LoadedSokobanLevel b) {
  final numberOrder = a.level.number.compareTo(b.level.number);
  if (numberOrder != 0) {
    return numberOrder;
  }

  return a.assetPath.compareTo(b.assetPath);
}

class _LoadedSokobanLevel {
  const _LoadedSokobanLevel({required this.assetPath, required this.level});

  final String assetPath;
  final SokobanLevel level;
}
