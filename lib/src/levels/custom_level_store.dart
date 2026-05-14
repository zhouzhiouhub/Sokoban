import 'dart:convert';
import 'dart:io';

import '../models/sokoban_level.dart';
import 'custom_level_limits.dart';
import 'level_catalog.dart';
import 'sokoban_level_import.dart';

const int maxCustomLevelImportBytes = customLevelImportMaxBytes;

class CustomLevelStoreException implements Exception {
  const CustomLevelStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CustomLevelStore {
  CustomLevelStore({File? storageFile, DateTime Function()? clock})
    : _storageFile = storageFile ?? _defaultStorageFile(),
      _clock = clock ?? DateTime.now;

  final File _storageFile;
  final DateTime Function() _clock;

  Future<List<LevelCatalogItem>> loadCatalogItems() async {
    final records = await _readRecordsAsync();
    return [for (final record in records) record.toCatalogItem()];
  }

  Future<LevelCatalogItem> importLevelJson(String source) async {
    final trimmedSource = source.trim();
    if (trimmedSource.isEmpty) {
      throw const SokobanLevelImportException('导入内容不能为空。');
    }
    if (utf8.encode(trimmedSource).length > maxCustomLevelImportBytes) {
      throw const SokobanLevelImportException('JSON 内容不能超过 64 KB。');
    }

    final level = await parseImportedSokobanLevelJsonAsync(trimmedSource);
    final recordPayloads = await _readRecordPayloadsAsync();
    final importedAt = _clock();
    final record = _CustomLevelRecord(
      id: _createCustomLevelId(importedAt, recordPayloads),
      importedAt: importedAt,
      level: level,
    );

    final nextRecordPayloads = [...recordPayloads, record.toJson()];
    await _writeRecordPayloadsAsync(nextRecordPayloads);
    return record.toCatalogItem();
  }

  Future<List<_CustomLevelRecord>> _readRecordsAsync() async {
    final source = await _readStorageSource();
    if (source == null) {
      return const [];
    }

    await Future<void>.delayed(Duration.zero);
    return _recordsFromStorageSource(source);
  }

  Future<List<Map<String, Object?>>> _readRecordPayloadsAsync() async {
    final source = await _readStorageSource();
    if (source == null) {
      return const [];
    }

    await Future<void>.delayed(Duration.zero);
    return _recordPayloadsFromStorageSource(source);
  }

  Future<String?> _readStorageSource() async {
    if (!await _storageFile.exists()) {
      return null;
    }

    final source = await _storageFile.readAsString();
    if (source.trim().isEmpty) {
      return null;
    }

    return source;
  }

  Future<void> _writeRecordPayloadsAsync(
    List<Map<String, Object?>> recordPayloads,
  ) async {
    await _storageFile.parent.create(recursive: true);
    await Future<void>.delayed(Duration.zero);
    final source = _encodeRecordPayloads(recordPayloads);
    await _storageFile.writeAsString(source);
  }
}

class _CustomLevelRecord {
  const _CustomLevelRecord({
    required this.id,
    required this.importedAt,
    required this.level,
  });

  final String id;
  final DateTime importedAt;
  final SokobanLevel level;

  LevelCatalogItem toCatalogItem() {
    return LevelCatalogItem(id: id, source: LevelSource.custom, level: level);
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'schemaVersion': 1,
      'importedAt': importedAt.toIso8601String(),
      'level': _sokobanLevelToJson(level),
    };
  }
}

Map<String, Object?> _sokobanLevelToJson(SokobanLevel level) {
  return {
    'number': level.number,
    'title': level.title,
    'description': level.description,
    'layout': level.layout,
    'initialPlayerPosition': {
      'row': level.initialPlayerPosition.row,
      'column': level.initialPlayerPosition.column,
    },
  };
}

String _createCustomLevelId(
  DateTime importedAt,
  List<Map<String, Object?>> existingRecordPayloads,
) {
  final base =
      'custom_'
      '${_pad(importedAt.year, 4)}'
      '${_pad(importedAt.month, 2)}'
      '${_pad(importedAt.day, 2)}_'
      '${_pad(importedAt.hour, 2)}'
      '${_pad(importedAt.minute, 2)}'
      '${_pad(importedAt.second, 2)}_'
      '${_pad(importedAt.millisecond, 3)}';
  final existingIds = {
    for (final recordPayload in existingRecordPayloads)
      _requiredString(recordPayload, 'id'),
  };
  var sequence = existingRecordPayloads.length + 1;

  while (true) {
    final id = '${base}_${_pad(sequence, 3)}';
    if (!existingIds.contains(id)) {
      return id;
    }
    sequence += 1;
  }
}

String _pad(int value, int width) => value.toString().padLeft(width, '0');

List<_CustomLevelRecord> _recordsFromStorageSource(String source) {
  final recordPayloads = _recordPayloadsFromStorageSource(source);
  final records = <_CustomLevelRecord>[];

  for (var index = 0; index < recordPayloads.length; index++) {
    final recordPayload = recordPayloads[index];
    final levelPayload = recordPayload['level'];
    if (levelPayload is! Map<String, Object?>) {
      throw CustomLevelStoreException('第 ${index + 1} 个自定义关卡缺少 level。');
    }

    try {
      records.add(
        _CustomLevelRecord(
          id: _requiredString(recordPayload, 'id'),
          importedAt: _requiredDateTime(recordPayload, 'importedAt'),
          level: parseImportedSokobanLevelJson(jsonEncode(levelPayload)),
        ),
      );
    } on SokobanLevelImportException catch (error) {
      throw CustomLevelStoreException(
        '第 ${index + 1} 个自定义关卡无效：${error.message}',
      );
    }
  }

  return records;
}

List<Map<String, Object?>> _recordPayloadsFromStorageSource(String source) {
  final Object? payload;
  try {
    payload = jsonDecode(source);
  } on FormatException {
    throw const CustomLevelStoreException('自定义关卡库文件无法解析。');
  }

  if (payload is! Map<String, Object?>) {
    throw const CustomLevelStoreException('自定义关卡库根节点必须是对象。');
  }

  final levelsPayload = payload['levels'];
  if (levelsPayload is! List<Object?>) {
    throw const CustomLevelStoreException('自定义关卡库缺少 levels 列表。');
  }

  final recordPayloads = <Map<String, Object?>>[];
  for (var index = 0; index < levelsPayload.length; index++) {
    final recordPayload = levelsPayload[index];
    if (recordPayload is! Map<String, Object?>) {
      throw CustomLevelStoreException('第 ${index + 1} 个自定义关卡记录格式无效。');
    }

    _requiredString(recordPayload, 'id');
    recordPayloads.add(Map<String, Object?>.from(recordPayload));
  }

  return recordPayloads;
}

String _encodeRecordPayloads(List<Map<String, Object?>> recordPayloads) {
  const encoder = JsonEncoder.withIndent('  ');
  final payload = <String, Object?>{
    'schemaVersion': 1,
    'levels': recordPayloads,
  };

  return '${encoder.convert(payload)}\n';
}

String _requiredString(Map<String, Object?> payload, String key) {
  final value = payload[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }

  throw CustomLevelStoreException('自定义关卡记录缺少 $key。');
}

DateTime _requiredDateTime(Map<String, Object?> payload, String key) {
  final value = _requiredString(payload, key);
  final dateTime = DateTime.tryParse(value);
  if (dateTime != null) {
    return dateTime;
  }

  throw CustomLevelStoreException('自定义关卡记录的 $key 不是有效时间。');
}

File _defaultStorageFile() {
  return File(
    '${_defaultApplicationDataDirectory().path}'
    '${Platform.pathSeparator}custom_levels.json',
  );
}

Directory _defaultApplicationDataDirectory() {
  if (Platform.isWindows) {
    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.isNotEmpty) {
      return Directory(
        '$appData${Platform.pathSeparator}Sokoban'
        '${Platform.pathSeparator}custom_levels',
      );
    }
  }

  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return Directory(
        '$home${Platform.pathSeparator}Library'
        '${Platform.pathSeparator}Application Support'
        '${Platform.pathSeparator}Sokoban',
      );
    }
  }

  if (Platform.isLinux) {
    final xdgDataHome = Platform.environment['XDG_DATA_HOME'];
    if (xdgDataHome != null && xdgDataHome.isNotEmpty) {
      return Directory('$xdgDataHome${Platform.pathSeparator}Sokoban');
    }

    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return Directory(
        '$home${Platform.pathSeparator}.local'
        '${Platform.pathSeparator}share'
        '${Platform.pathSeparator}Sokoban',
      );
    }
  }

  return Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}Sokoban',
  );
}
