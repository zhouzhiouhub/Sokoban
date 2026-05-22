import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/router.dart';
import '../app_branding.dart';
import '../controllers/level_catalog_controller.dart';
import '../levels/level_catalog.dart';

class LevelSelectionPage extends ConsumerWidget {
  const LevelSelectionPage({super.key});

  Future<void> _showImportDialog(BuildContext context, WidgetRef ref) async {
    final input = await showDialog<String>(
      context: context,
      builder: (context) => const _ImportLevelDialog(),
    );
    if (input == null) {
      return;
    }

    try {
      final catalogItem = await ref
          .read(levelCatalogControllerProvider.notifier)
          .importLevel(input);
      if (!context.mounted) {
        return;
      }

      _showSnackBar(context, '已导入：${catalogItem.level.title}');
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      _showSnackBar(context, '导入失败：$error');
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final builtInCatalogAsync = ref.watch(builtInLevelCatalogProvider);
    final builtInLevelCatalog = builtInCatalogAsync.hasValue
        ? builtInCatalogAsync.requireValue
        : const <LevelCatalogItem>[];
    final isLoadingBuiltInLevels =
        builtInCatalogAsync.isLoading && !builtInCatalogAsync.hasValue;
    final builtInLevelLoadError = builtInCatalogAsync.hasError
        ? '生成关卡读取失败：${builtInCatalogAsync.error}'
        : null;
    final catalogAsync = ref.watch(levelCatalogControllerProvider);
    final catalogState = catalogAsync.hasValue
        ? catalogAsync.requireValue
        : null;
    final customLevelCatalog =
        catalogState?.customLevelCatalog ?? const <LevelCatalogItem>[];
    final isLoadingCustomLevels =
        catalogAsync.isLoading && !catalogAsync.hasValue;
    final customLevelLoadError = catalogAsync.hasError
        ? '自定义关卡读取失败：${catalogAsync.error}'
        : null;
    final isImporting = catalogState?.isImporting ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text(appName),
        actions: [
          IconButton(
            tooltip: '导入关卡',
            onPressed: isImporting
                ? null
                : () => _showImportDialog(context, ref),
            icon: const Icon(LucideIcons.upload),
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
                  sliver: _BuiltInLevelSection(
                    isLoading: isLoadingBuiltInLevels,
                    loadError: builtInLevelLoadError,
                    items: builtInLevelCatalog,
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
                    isLoading: isLoadingCustomLevels,
                    loadError: customLevelLoadError,
                    items: customLevelCatalog,
                    firstCatalogIndex: builtInLevelCatalog.length,
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
          icon: const Icon(LucideIcons.upload),
          label: const Text('导入'),
        ),
      ],
    );
  }
}

class _BuiltInLevelSection extends StatelessWidget {
  const _BuiltInLevelSection({
    required this.isLoading,
    required this.loadError,
    required this.items,
    required this.gridDelegate,
  });

  final bool isLoading;
  final String? loadError;
  final List<LevelCatalogItem> items;
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
          icon: LucideIcons.triangleAlert,
          message: loadError!,
        ),
      );
    }

    if (items.isEmpty) {
      return const SliverToBoxAdapter(
        child: _InlineMessage(
          icon: LucideIcons.packageOpen,
          message: '未找到生成关卡',
        ),
      );
    }

    return _LevelTileSliverGrid(
      items: items,
      firstCatalogIndex: 0,
      customOffset: 0,
      gridDelegate: gridDelegate,
    );
  }
}

class _CustomLevelSection extends StatelessWidget {
  const _CustomLevelSection({
    required this.isLoading,
    required this.loadError,
    required this.items,
    required this.firstCatalogIndex,
    required this.gridDelegate,
  });

  final bool isLoading;
  final String? loadError;
  final List<LevelCatalogItem> items;
  final int firstCatalogIndex;
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
          icon: LucideIcons.triangleAlert,
          message: loadError!,
        ),
      );
    }

    if (items.isEmpty) {
      return const SliverToBoxAdapter(
        child: _InlineMessage(
          icon: LucideIcons.packageOpen,
          message: '还没有自定义关卡',
        ),
      );
    }

    return _LevelTileSliverGrid(
      items: items,
      firstCatalogIndex: firstCatalogIndex,
      customOffset: 0,
      gridDelegate: gridDelegate,
    );
  }
}

class _LevelTileSliverGrid extends StatelessWidget {
  const _LevelTileSliverGrid({
    required this.items,
    required this.firstCatalogIndex,
    required this.customOffset,
    required this.gridDelegate,
  });

  final List<LevelCatalogItem> items;
  final int firstCatalogIndex;
  final int customOffset;
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
                context.pushNamed(
                  AppRoute.level.name,
                  pathParameters: {'index': '${firstCatalogIndex + index}'},
                );
              },
            )
            .animate(delay: (index % 10 * 16).ms)
            .fadeIn(duration: 180.ms, curve: Curves.easeOutCubic)
            .scale(
              begin: const Offset(0.96, 0.96),
              duration: 180.ms,
              curve: Curves.easeOutCubic,
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
