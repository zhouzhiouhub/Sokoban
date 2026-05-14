import 'dart:convert';
import 'dart:io';

import 'custom_level_limits.dart';
import 'sokoban_level_import.dart';

class CustomLevelImportSourceReader {
  const CustomLevelImportSourceReader();

  Future<String> read(String input) async {
    final trimmedInput = input.trim();
    if (trimmedInput.isEmpty) {
      throw const SokobanLevelImportException('导入内容不能为空。');
    }

    if (_looksLikeJson(trimmedInput)) {
      return trimmedInput;
    }

    final file = File(_unquoteFilePath(trimmedInput));
    if (!await file.exists()) {
      throw const SokobanLevelImportException('未找到 JSON 文件，请检查路径。');
    }

    final byteCount = await file.length();
    if (byteCount > customLevelImportMaxBytes) {
      throw const SokobanLevelImportException('JSON 文件不能超过 64 KB。');
    }

    return file.readAsString(encoding: utf8);
  }

  bool _looksLikeJson(String input) {
    return input.startsWith('{') || input.startsWith('[');
  }

  String _unquoteFilePath(String path) {
    if (path.length >= 2 &&
        ((path.startsWith('"') && path.endsWith('"')) ||
            (path.startsWith("'") && path.endsWith("'")))) {
      return path.substring(1, path.length - 1);
    }

    return path;
  }
}
