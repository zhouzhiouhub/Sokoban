import 'dart:convert';

import '../game/sokoban_rules.dart';
import '../models/board_position.dart';
import '../models/sokoban_level.dart';

const Set<String> _allowedLayoutSymbols = {'_', ' ', '#', 'B', 'T', '*'};

class SokobanLevelValidationOptions {
  const SokobanLevelValidationOptions({
    this.maxRows = 10,
    this.maxColumns = 15,
    this.requireSolvable = false,
    this.maxBoxesForSolvability = 8,
  });

  final int maxRows;
  final int maxColumns;
  final bool requireSolvable;
  final int maxBoxesForSolvability;
}

class SokobanLevelImportException implements Exception {
  const SokobanLevelImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

SokobanLevel parseImportedSokobanLevelJson(
  String source, {
  SokobanLevelValidationOptions options = const SokobanLevelValidationOptions(),
}) {
  final Object? payload;
  try {
    payload = jsonDecode(source);
  } on FormatException {
    throw const SokobanLevelImportException('JSON 无法解析。');
  }

  if (payload is! Map<String, Object?>) {
    throw const SokobanLevelImportException('关卡 JSON 根节点必须是对象。');
  }

  final level = _levelFromPayload(payload);
  final errors = validateImportedSokobanLevel(level, options: options);
  if (errors.isNotEmpty) {
    throw SokobanLevelImportException(errors.first);
  }

  return level;
}

List<String> validateImportedSokobanLevel(
  SokobanLevel level, {
  SokobanLevelValidationOptions options = const SokobanLevelValidationOptions(),
}) {
  final errors = <String>[];
  final layout = level.layout;

  if (layout.isEmpty) {
    errors.add('layout 不能为空。');
    return errors;
  }

  if (layout.length > options.maxRows) {
    errors.add('当前关卡行数为 ${layout.length}，最多支持 ${options.maxRows} 行。');
  }

  final expectedColumnCount = layout.first.length;
  if (expectedColumnCount == 0) {
    errors.add('layout 的行不能为空字符串。');
  }

  if (expectedColumnCount > options.maxColumns) {
    errors.add('当前关卡列数为 $expectedColumnCount，最多支持 ${options.maxColumns} 列。');
  }

  for (var row = 0; row < layout.length; row++) {
    final line = layout[row];
    if (line.length != expectedColumnCount) {
      errors.add('第 ${row + 1} 行长度与第 1 行不一致。');
      continue;
    }

    for (var column = 0; column < line.length; column++) {
      final symbol = line[column];
      if (!_allowedLayoutSymbols.contains(symbol)) {
        errors.add('第 ${row + 1} 行第 ${column + 1} 列存在非法字符 `$symbol`。');
      }
    }
  }

  final playerPosition = level.initialPlayerPosition;
  if (!isInsideLayout(layout, playerPosition)) {
    errors.add('玩家初始位置越界。');
  } else if (!isFloorTile(layout, playerPosition)) {
    errors.add('玩家初始位置必须位于可通行地块。');
  }

  final bricks = positionsForSymbol(layout, 'B');
  final targets = positionsForSymbol(layout, 'T');
  if (bricks.contains(playerPosition)) {
    errors.add('玩家初始位置不能和箱子重叠。');
  }

  if (bricks.isEmpty) {
    errors.add('关卡至少需要一个箱子。');
  }

  if (targets.isEmpty) {
    errors.add('关卡至少需要一个目标点。');
  }

  if (bricks.length != targets.length) {
    errors.add(
      '箱子数量必须与目标点数量一致。当前箱子 ${bricks.length} 个，目标点 ${targets.length} 个。',
    );
  }

  if (errors.isNotEmpty) {
    return errors;
  }

  final deadTiles = computeDeadTiles(layout, targets);
  for (final brickPosition in bricks) {
    if (!targets.contains(brickPosition) && deadTiles.contains(brickPosition)) {
      errors.add('当前关卡开局就有箱子落在死格，初始状态无解。');
      return errors;
    }
  }

  if (options.requireSolvable) {
    if (bricks.length > options.maxBoxesForSolvability) {
      errors.add(
        '当前关卡箱子数量为 ${bricks.length}，超过可解性检测上限 '
        '${options.maxBoxesForSolvability}。',
      );
    } else if (!isSokobanStateSolvable(
      layout: layout,
      playerPosition: playerPosition,
      brickPositions: bricks,
      targetPositions: targets,
      deadTiles: deadTiles,
    )) {
      errors.add('当前关卡没有找到可行解。');
    }
  }

  return errors;
}

SokobanLevel _levelFromPayload(Map<String, Object?> payload) {
  final number = _requiredInt(payload, 'number');
  final title = _requiredString(payload, 'title');
  final description = _requiredString(payload, 'description');
  final layout = _requiredStringList(payload, 'layout');
  final playerPayload = _requiredMap(payload, 'initialPlayerPosition');

  return SokobanLevel(
    number: number,
    title: title.trim().isEmpty ? '自定义关卡' : title.trim(),
    description: description.trim(),
    layout: layout,
    initialPlayerPosition: BoardPosition(
      row: _requiredInt(playerPayload, 'row'),
      column: _requiredInt(playerPayload, 'column'),
    ),
  );
}

int _requiredInt(Map<String, Object?> payload, String key) {
  final value = payload[key];
  if (value is int) {
    return value;
  }

  throw SokobanLevelImportException('缺少必需字段 `$key`，或字段类型不是 int。');
}

String _requiredString(Map<String, Object?> payload, String key) {
  final value = payload[key];
  if (value is String) {
    return value;
  }

  throw SokobanLevelImportException('缺少必需字段 `$key`，或字段类型不是 string。');
}

List<String> _requiredStringList(Map<String, Object?> payload, String key) {
  final value = payload[key];
  if (value is! List<Object?>) {
    throw SokobanLevelImportException('缺少必需字段 `$key`，或字段类型不是 string[]。');
  }

  final rows = <String>[];
  for (var index = 0; index < value.length; index++) {
    final row = value[index];
    if (row is! String) {
      throw SokobanLevelImportException('layout 第 ${index + 1} 行不是字符串。');
    }
    rows.add(row);
  }

  return rows;
}

Map<String, Object?> _requiredMap(Map<String, Object?> payload, String key) {
  final value = payload[key];
  if (value is Map<String, Object?>) {
    return value;
  }

  throw SokobanLevelImportException('缺少必需字段 `$key`，或字段类型不是 object。');
}
