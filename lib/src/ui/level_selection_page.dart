import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_branding.dart';
import '../levels/custom_level_import_source.dart';
import '../levels/custom_level_store.dart';
import '../levels/level_catalog.dart';
import 'sokoban_wall_page.dart';

class LevelSelectionPage extends StatefulWidget {
  const LevelSelectionPage({super.key, this.customLevelStore});

  final CustomLevelStore? customLevelStore;

  @override
  State<LevelSelectionPage> createState() => _LevelSelectionPageState();
}

class _LevelSelectionPageState extends State<LevelSelectionPage> {
  late final CustomLevelStore _customLevelStore =
      widget.customLevelStore ?? CustomLevelStore();
  final CustomLevelImportSourceReader _importSourceReader =
      const CustomLevelImportSourceReader();
  List<LevelCatalogItem> _customLevelCatalog = const [];
  bool _isLoadingCustomLevels = true;
  bool _isImporting = false;
  String? _customLevelLoadError;

  List<LevelCatalogItem> get _levelCatalog => [
    ...builtInLevelCatalog,
    ..._customLevelCatalog,
  ];

  @override
  void initState() {
    super.initState();
    _loadCustomLevels();
  }

  Future<void> _loadCustomLevels() async {
    setState(() {
      _isLoadingCustomLevels = true;
      _customLevelLoadError = null;
    });

    try {
      final customLevelCatalog = await _customLevelStore.loadCatalogItems();
      if (!mounted) {
        return;
      }

      setState(() {
        _customLevelCatalog = customLevelCatalog;
        _isLoadingCustomLevels = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingCustomLevels = false;
        _customLevelLoadError = '自定义关卡读取失败：$error';
      });
    }
  }

  Future<void> _showImportDialog() async {
    final input = await _requestImportInput(context);
    if (input == null) {
      return;
    }

    await _importLevel(input);
  }

  Future<void> _importLevel(String input) async {
    setState(() {
      _isImporting = true;
    });

    try {
      final source = await _importSourceReader.read(input);
      final catalogItem = await _customLevelStore.importLevelJson(source);
      if (!mounted) {
        return;
      }

      setState(() {
        _customLevelCatalog = [..._customLevelCatalog, catalogItem];
        _customLevelLoadError = null;
        _isImporting = false;
      });
      _showSnackBar('已导入：${catalogItem.level.title}');
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isImporting = false;
      });
      _showSnackBar('导入失败：$error');
    }
  }

  Future<String?> _requestImportInput(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (context) => const _ImportLevelDialog(),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EFE7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF526652),
        foregroundColor: Colors.white,
        title: const Text(appName),
        actions: [
          IconButton(
            tooltip: '导入关卡',
            onPressed: _isImporting ? null : _showImportDialog,
            icon: const Icon(Icons.file_upload_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 720 ? 32.0 : 16.0;
            final maxGridWidth = constraints.maxWidth >= 720 ? 680.0 : 460.0;
            final availableWidth = math.max(
              0.0,
              constraints.maxWidth - horizontalPadding * 2,
            );
            final gridWidth = math.min(maxGridWidth, availableWidth);
            final sideInset =
                horizontalPadding +
                math.max(0.0, availableWidth - gridWidth) / 2;
            final columnCount = math.max(
              1,
              ((gridWidth + 12) / (92 + 12)).floor(),
            );
            final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columnCount,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            );

            return CustomScrollView(
              cacheExtent: 1400,
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(sideInset, 20, sideInset, 0),
                  sliver: const SliverToBoxAdapter(
                    child: _SectionTitle(title: '内置关卡'),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(sideInset, 12, sideInset, 0),
                  sliver: _LevelTileSliverGrid(
                    items: builtInLevelCatalog,
                    firstCatalogIndex: 0,
                    customOffset: 0,
                    fullCatalog: _levelCatalog,
                    gridDelegate: gridDelegate,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: sideInset),
                  sliver: const SliverToBoxAdapter(
                    child: _SectionTitle(title: '自定义关卡'),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(sideInset, 12, sideInset, 24),
                  sliver: _CustomLevelSection(
                    isLoading: _isLoadingCustomLevels,
                    loadError: _customLevelLoadError,
                    items: _customLevelCatalog,
                    fullCatalog: _levelCatalog,
                    gridDelegate: gridDelegate,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ImportLevelDialog extends StatefulWidget {
  const _ImportLevelDialog();

  @override
  State<_ImportLevelDialog> createState() => _ImportLevelDialogState();
}

class _ImportLevelDialogState extends State<_ImportLevelDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('导入关卡'),
      content: SizedBox(
        width: 520,
        child: TextField(
          controller: _controller,
          minLines: 8,
          maxLines: 12,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'JSON 内容或文件路径',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          icon: const Icon(Icons.file_upload_outlined),
          label: const Text('导入'),
        ),
      ],
    );
  }
}

class _CustomLevelSection extends StatelessWidget {
  const _CustomLevelSection({
    required this.isLoading,
    required this.loadError,
    required this.items,
    required this.fullCatalog,
    required this.gridDelegate,
  });

  final bool isLoading;
  final String? loadError;
  final List<LevelCatalogItem> items;
  final List<LevelCatalogItem> fullCatalog;
  final SliverGridDelegate gridDelegate;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SliverToBoxAdapter(
        child: SizedBox(
          height: 72,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (loadError != null) {
      return SliverToBoxAdapter(
        child: _InlineMessage(
          icon: Icons.warning_amber_rounded,
          message: loadError!,
        ),
      );
    }

    if (items.isEmpty) {
      return const SliverToBoxAdapter(
        child: _InlineMessage(
          icon: Icons.inventory_2_outlined,
          message: '还没有自定义关卡',
        ),
      );
    }

    return _LevelTileSliverGrid(
      items: items,
      firstCatalogIndex: builtInLevelCatalog.length,
      customOffset: 0,
      fullCatalog: fullCatalog,
      gridDelegate: gridDelegate,
    );
  }
}

class _LevelTileSliverGrid extends StatelessWidget {
  const _LevelTileSliverGrid({
    required this.items,
    required this.firstCatalogIndex,
    required this.customOffset,
    required this.fullCatalog,
    required this.gridDelegate,
  });

  final List<LevelCatalogItem> items;
  final int firstCatalogIndex;
  final int customOffset;
  final List<LevelCatalogItem> fullCatalog;
  final SliverGridDelegate gridDelegate;

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: gridDelegate,
      delegate: SliverChildBuilderDelegate((context, index) {
        return _LevelTile(
          catalogItem: items[index],
          displayIndex: index + customOffset + 1,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SokobanWallPage(
                  initialLevelIndex: firstCatalogIndex + index,
                  levelCatalog: fullCatalog,
                ),
              ),
            );
          },
        );
      }, childCount: items.length),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.catalogItem,
    required this.displayIndex,
    required this.onTap,
  });

  final LevelCatalogItem catalogItem;
  final int displayIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCustom = catalogItem.source == LevelSource.custom;
    final level = catalogItem.level;
    final semanticLabel = isCustom
        ? '自定义关卡 $displayIndex'
        : '第 ${level.number} 关';
    final tooltip = isCustom
        ? '自定义 $displayIndex - ${level.title}'
        : '第 ${level.number} 关 - ${level.title}';
    final tileContent = isCustom
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '自定义',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF526652),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$displayIndex',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF2F3B2F),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          )
        : Text(
            '${level.number}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF2F3B2F),
              fontWeight: FontWeight.w800,
            ),
          );

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          width: 92,
          height: 92,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCustom
                        ? const Color(0xFF9FB37C)
                        : const Color(0xFFD9CFBB),
                  ),
                ),
                child: Center(child: tileContent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: const Color(0xFF2F3B2F),
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE9E1CF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC2B79D)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF526652)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF2F3B2F)),
            ),
          ),
        ],
      ),
    );
  }
}
