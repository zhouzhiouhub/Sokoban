import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/board_tile.dart';

class SokobanTile extends StatelessWidget {
  const SokobanTile({
    super.key,
    required this.tile,
    required this.isTarget,
    required this.hasPlayer,
  });

  final BoardTile tile;
  final bool isTarget;
  final bool hasPlayer;

  @override
  Widget build(BuildContext context) {
    if (tile == BoardTile.empty) {
      return Semantics(
        label: '空白区域',
        child: const DecoratedBox(
          decoration: BoxDecoration(color: Color(0xFFE3DBC9)),
        ),
      );
    }

    final semanticsLabel = switch ((tile, isTarget, hasPlayer)) {
      (BoardTile.empty, _, _) => '空白区域',
      (BoardTile.wall, _, _) => '墙体',
      (BoardTile.brick, true, _) => '目标点上的箱子',
      (BoardTile.brick, false, _) => '箱子',
      (BoardTile.floor, true, true) => '人物所在的目标点',
      (BoardTile.floor, true, false) => '目标点',
      (BoardTile.floor, false, true) => '人物所在位置',
      (BoardTile.floor, false, false) => '地面',
    };

    final backgroundColor = tile == BoardTile.wall
        ? const Color(0xFF3F493A)
        : const Color(0xFFD8CFB9);

    final borderColor = tile == BoardTile.wall
        ? const Color(0xFF222820)
        : const Color(0xFFC9BFA8);

    return Semantics(
      label: semanticsLabel,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border.all(color: borderColor, width: 0.7),
            ),
          ),
          if (isTarget && tile != BoardTile.wall) const _TargetMarker(),
          if (tile == BoardTile.wall)
            const _ScaledTileIcon(
              icon: Icons.square,
              color: Color(0xFF5F7257),
              maxSize: 14,
              sizeFactor: 0.55,
            ),
          if (tile == BoardTile.brick)
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFC98A55),
                border: Border.all(color: const Color(0xFF74441E), width: 1),
              ),
            ),
          if (hasPlayer) const Center(child: _PlayerAvatar()),
        ],
      ),
    );
  }
}

class _TargetMarker extends StatelessWidget {
  const _TargetMarker();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortestSide = math.min(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final markerSize = math.min(16.0, shortestSide * 0.46);

        return Center(
          child: Container(
            width: markerSize,
            height: markerSize,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4C4),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFB18B2C), width: 2),
            ),
          ),
        );
      },
    );
  }
}

class _ScaledTileIcon extends StatelessWidget {
  const _ScaledTileIcon({
    required this.icon,
    required this.color,
    required this.maxSize,
    required this.sizeFactor,
  });

  final IconData icon;
  final Color color;
  final double maxSize;
  final double sizeFactor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortestSide = math.min(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final iconSize = math.min(maxSize, shortestSide * sizeFactor);

        return Center(
          child: Icon(icon, color: color, size: iconSize),
        );
      },
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortestSide = math.min(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final avatarSize = math.min(22.0, shortestSide * 0.76);
        final iconSize = math.min(14.0, avatarSize * 0.64);

        return Center(
          child: Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              color: const Color(0xFF3C6E71),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.person, size: iconSize, color: Colors.white),
          ),
        );
      },
    );
  }
}
