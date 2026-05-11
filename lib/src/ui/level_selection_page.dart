import 'package:flutter/material.dart';

import '../levels/sokoban_levels.dart';
import 'sokoban_wall_page.dart';

class LevelSelectionPage extends StatelessWidget {
  const LevelSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EFE7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF526652),
        foregroundColor: Colors.white,
        title: const Text('选择关卡'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 720 ? 32.0 : 16.0;
            final maxGridWidth = constraints.maxWidth >= 720 ? 680.0 : 460.0;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxGridWidth),
                child: GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    20,
                    horizontalPadding,
                    24,
                  ),
                  itemCount: sokobanLevels.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 104,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final level = sokobanLevels[index];

                    return _LevelTile(
                      number: level.number,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                SokobanWallPage(initialLevelIndex: index),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({required this.number, required this.onTap});

  final int number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '第 $number 关',
      child: Tooltip(
        message: '第 $number 关',
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD9CFBB)),
              ),
              child: Center(
                child: Text(
                  '$number',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF2F3B2F),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
