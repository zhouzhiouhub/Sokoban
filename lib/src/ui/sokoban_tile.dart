import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/board_position.dart';
import '../models/board_tile.dart';

enum SokobanTileEdge { top, right, bottom, left }

class SokobanTile extends StatelessWidget {
  const SokobanTile({
    super.key,
    required this.tile,
    required this.isTarget,
    required this.hasPlayer,
    this.visualRow = 0,
    this.visualColumn = 0,
    this.wallEdges = const <SokobanTileEdge>{},
    this.playerDirection = const BoardPosition(row: 1, column: 0),
    this.isHintedBrick = false,
    this.isHintPushTarget = false,
    this.hintDirection,
  });

  final BoardTile tile;
  final bool isTarget;
  final bool hasPlayer;
  final int visualRow;
  final int visualColumn;
  final Set<SokobanTileEdge> wallEdges;
  final BoardPosition playerDirection;
  final bool isHintedBrick;
  final bool isHintPushTarget;
  final BoardPosition? hintDirection;

  int get _visualSeed {
    return (visualRow * 73856093) ^ (visualColumn * 19349663);
  }

  @override
  Widget build(BuildContext context) {
    if (tile == BoardTile.empty) {
      return Semantics(
        label: '空白区域',
        child: CustomPaint(
          painter: _TileSurfacePainter(
            surface: _TileSurface.empty,
            seed: _visualSeed,
          ),
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

    final surface = tile == BoardTile.wall
        ? _TileSurface.wall
        : _TileSurface.floor;

    return Semantics(
      label: semanticsLabel,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _TileSurfacePainter(
              surface: surface,
              seed: _visualSeed,
              wallEdges: tile == BoardTile.wall
                  ? const <SokobanTileEdge>{}
                  : wallEdges,
            ),
          ),
          if (isTarget && tile != BoardTile.wall && tile != BoardTile.brick)
            const _TargetMarker(),
          if (isHintPushTarget && tile != BoardTile.wall)
            const _HintPushTargetMarker(),
          if (tile == BoardTile.brick)
            _CrateVisual(seed: _visualSeed, isActivated: isTarget),
          if (isTarget && tile == BoardTile.brick) const _ActivatedGoalHalo(),
          if (isHintedBrick) const _HintedBrickOutline(),
          if (isHintedBrick && hintDirection != null)
            _HintDirectionArrow(direction: hintDirection!),
          if (hasPlayer)
            Center(child: _PlayerAvatar(direction: playerDirection)),
        ],
      ),
    );
  }
}

enum _TileSurface { empty, floor, wall }

class _TileSurfacePainter extends CustomPainter {
  const _TileSurfacePainter({
    required this.surface,
    required this.seed,
    this.wallEdges = const <SokobanTileEdge>{},
  });

  final _TileSurface surface;
  final int seed;
  final Set<SokobanTileEdge> wallEdges;

  @override
  void paint(Canvas canvas, Size size) {
    switch (surface) {
      case _TileSurface.empty:
        _paintEmpty(canvas, size);
        break;
      case _TileSurface.floor:
        _paintFloor(canvas, size);
        break;
      case _TileSurface.wall:
        _paintWall(canvas, size);
        break;
    }
  }

  void _paintEmpty(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = _shiftHsl(
      const Color(0xFFE4DDCF),
      lightness: (_noise(seed, 8) - 0.5) * 0.018,
      saturation: -0.02,
    );

    canvas.drawRect(rect, Paint()..color = base);
    _drawSparseGrain(
      canvas,
      size,
      seed: seed,
      color: const Color(0xFF9D927B).withValues(alpha: 0.04),
      count: 3,
    );
  }

  void _paintFloor(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = _floorTone(seed);
    final light = _shiftHsl(base, lightness: 0.028, saturation: -0.01);
    final dark = _shiftHsl(base, lightness: -0.026, saturation: 0.006);
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [light, base, dark],
        stops: const [0, 0.58, 1],
      ).createShader(rect);

    canvas.drawRect(rect, fill);
    _drawSoftGrid(canvas, size);
    _drawSparseGrain(
      canvas,
      size,
      seed: seed,
      color: const Color(0xFF7D735F).withValues(alpha: 0.065),
      count: 6,
    );
    _drawWallAo(canvas, size);
  }

  void _paintWall(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shortest = _shortest(size);
    final inset = math.max(0.35, shortest * 0.025);
    final radius = Radius.circular(math.max(1.5, shortest * 0.07));
    final block = RRect.fromRectAndRadius(rect.deflate(inset), radius);
    final base = _shiftHsl(
      const Color(0xFF53614D),
      lightness: (_noise(seed, 41) - 0.5) * 0.045,
      saturation: (_noise(seed, 42) - 0.5) * 0.03,
      hue: (_noise(seed, 43) - 0.5) * 5,
    );

    canvas.drawRRect(
      block.shift(Offset(shortest * 0.035, shortest * 0.045)),
      Paint()..color = const Color(0x2B000000),
    );

    canvas.drawRRect(
      block,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _shiftHsl(base, lightness: 0.09, saturation: -0.02),
            base,
            _shiftHsl(base, lightness: -0.12, saturation: 0.02),
          ],
          stops: const [0, 0.52, 1],
        ).createShader(block.outerRect),
    );

    final topCap = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        block.left + inset,
        block.top + inset,
        block.right - inset,
        block.top + block.height * 0.34,
      ),
      radius,
    );
    canvas.drawRRect(topCap, Paint()..color = const Color(0x16FFFFFF));

    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.75, shortest * 0.03)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(block.left + inset, block.top + inset),
      Offset(block.right - inset, block.top + inset),
      edgePaint..color = const Color(0x55DCE6D0),
    );
    canvas.drawLine(
      Offset(block.right - inset, block.top + inset * 1.5),
      Offset(block.right - inset, block.bottom - inset),
      edgePaint..color = const Color(0x55313A2F),
    );
    canvas.drawLine(
      Offset(block.left + inset * 1.5, block.bottom - inset),
      Offset(block.right - inset, block.bottom - inset),
      edgePaint..color = const Color(0x66313A2F),
    );

    _drawWallWeathering(canvas, size, block);
  }

  void _drawSoftGrid(Canvas canvas, Size size) {
    final shortest = _shortest(size);
    final gridWidth = math.max(0.35, shortest * 0.012);
    final darkLine = Paint()
      ..color = const Color(0x248B806A)
      ..strokeWidth = gridWidth;
    final lightLine = Paint()
      ..color = const Color(0x20FFFFFF)
      ..strokeWidth = gridWidth;

    if (_noise(seed, 11) > 0.17) {
      canvas.drawLine(Offset.zero, Offset(size.width, 0), darkLine);
    }
    if (_noise(seed, 12) > 0.28) {
      canvas.drawLine(Offset.zero, Offset(0, size.height), darkLine);
    }
    if (_noise(seed, 13) > 0.62) {
      canvas.drawLine(
        Offset(0, size.height - gridWidth),
        Offset(size.width, size.height - gridWidth),
        lightLine,
      );
    }
  }

  void _drawSparseGrain(
    Canvas canvas,
    Size size, {
    required int seed,
    required Color color,
    required int count,
  }) {
    final shortest = _shortest(size);
    final paint = Paint()
      ..color = color
      ..strokeWidth = math.max(0.35, shortest * 0.012)
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < count; i++) {
      final x = size.width * _noise(seed, 100 + i * 3);
      final y = size.height * _noise(seed, 101 + i * 3);
      final length = shortest * (0.06 + _noise(seed, 102 + i * 3) * 0.09);
      if (i.isEven) {
        canvas.drawLine(
          Offset(x - length * 0.5, y),
          Offset(x + length * 0.5, y + shortest * 0.015),
          paint,
        );
      } else {
        canvas.drawCircle(
          Offset(x, y),
          math.max(0.35, shortest * 0.015),
          paint,
        );
      }
    }
  }

  void _drawWallAo(Canvas canvas, Size size) {
    if (wallEdges.isEmpty) {
      return;
    }

    final shortest = _shortest(size);
    final aoWidth = math.max(2.0, shortest * 0.26);

    for (final edge in wallEdges) {
      final (rect, begin, end) = switch (edge) {
        SokobanTileEdge.top => (
          Rect.fromLTWH(0, 0, size.width, aoWidth),
          Alignment.topCenter,
          Alignment.bottomCenter,
        ),
        SokobanTileEdge.right => (
          Rect.fromLTWH(size.width - aoWidth, 0, aoWidth, size.height),
          Alignment.centerRight,
          Alignment.centerLeft,
        ),
        SokobanTileEdge.bottom => (
          Rect.fromLTWH(0, size.height - aoWidth, size.width, aoWidth),
          Alignment.bottomCenter,
          Alignment.topCenter,
        ),
        SokobanTileEdge.left => (
          Rect.fromLTWH(0, 0, aoWidth, size.height),
          Alignment.centerLeft,
          Alignment.centerRight,
        ),
      };

      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: begin,
            end: end,
            colors: const [Color(0x24000000), Color(0x00000000)],
          ).createShader(rect),
      );
    }
  }

  void _drawWallWeathering(Canvas canvas, Size size, RRect block) {
    final shortest = _shortest(size);
    final chipPaint = Paint()
      ..color = const Color(0x306F8058)
      ..style = PaintingStyle.fill;
    final crackPaint = Paint()
      ..color = const Color(0x55333B31)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.45, shortest * 0.016)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (_noise(seed, 55) > 0.24) {
      final patch = Rect.fromLTWH(
        block.left + block.width * _noise(seed, 56) * 0.65,
        block.top + block.height * (0.12 + _noise(seed, 57) * 0.46),
        block.width * (0.12 + _noise(seed, 58) * 0.11),
        block.height * (0.08 + _noise(seed, 59) * 0.09),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          patch,
          Radius.circular(math.max(1.0, shortest * 0.04)),
        ),
        chipPaint,
      );
    }

    if (_noise(seed, 65) > 0.52) {
      final start = Offset(
        block.left + block.width * (0.25 + _noise(seed, 66) * 0.5),
        block.top + block.height * (0.22 + _noise(seed, 67) * 0.2),
      );
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..relativeLineTo(shortest * 0.06, shortest * 0.08)
        ..relativeLineTo(-shortest * 0.04, shortest * 0.09)
        ..relativeLineTo(shortest * 0.08, shortest * 0.05);
      canvas.drawPath(path, crackPaint);
    }
  }

  @override
  bool shouldRepaint(_TileSurfacePainter oldDelegate) {
    return oldDelegate.surface != surface ||
        oldDelegate.seed != seed ||
        oldDelegate.wallEdges != wallEdges;
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
        final markerSize = math.min(24.0, shortestSide * 0.64);

        return Center(
          child: SizedBox.square(
            dimension: markerSize,
            child: const CustomPaint(painter: _TargetMarkerPainter()),
          ),
        );
      },
    );
  }
}

class _TargetMarkerPainter extends CustomPainter {
  const _TargetMarkerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = _shortest(size) / 2;
    final grooveRadius = radius * 0.88;
    final ringRadius = radius * 0.64;

    canvas.drawCircle(
      center.translate(radius * 0.04, radius * 0.07),
      grooveRadius,
      Paint()..color = const Color(0x2B4B3E2B),
    );
    canvas.drawCircle(
      center,
      grooveRadius,
      Paint()..color = const Color(0x55695A3A),
    );
    canvas.drawCircle(
      center,
      grooveRadius * 0.78,
      Paint()..color = const Color(0xFFD0C19F),
    );
    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, radius * 0.18)
        ..color = const Color(0xFF8B7646),
    );

    final runePaint = Paint()
      ..color = const Color(0xFFB1903E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, radius * 0.11)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center.translate(-radius * 0.23, 0),
      center.translate(radius * 0.23, 0),
      runePaint,
    );
    canvas.drawLine(
      center.translate(0, -radius * 0.23),
      center.translate(0, radius * 0.23),
      runePaint,
    );
  }

  @override
  bool shouldRepaint(_TargetMarkerPainter oldDelegate) => false;
}

class _ActivatedGoalHalo extends StatelessWidget {
  const _ActivatedGoalHalo();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.35, end: 1),
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        builder: (context, opacity, child) {
          return Opacity(opacity: opacity, child: child);
        },
        child: const CustomPaint(painter: _ActivatedGoalHaloPainter()),
      ),
    );
  }
}

class _ActivatedGoalHaloPainter extends CustomPainter {
  const _ActivatedGoalHaloPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = _shortest(size);
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.86,
      height: size.height * 0.86,
    );
    final radius = Radius.circular(math.max(2.0, shortest * 0.09));

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(shortest * 0.035), radius),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, shortest * 0.035)
        ..color = const Color(0x99D2A83E),
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      shortest * 0.34,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.7, shortest * 0.018)
        ..color = const Color(0x55FFF0A3),
    );
  }

  @override
  bool shouldRepaint(_ActivatedGoalHaloPainter oldDelegate) => false;
}

class _HintPushTargetMarker extends StatelessWidget {
  const _HintPushTargetMarker();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortestSide = math.min(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final markerSize = math.min(24.0, shortestSide * 0.72);

        return Center(
          child: SizedBox.square(
            dimension: markerSize,
            child: const CustomPaint(painter: _HintPushTargetPainter()),
          ),
        );
      },
    );
  }
}

class _HintPushTargetPainter extends CustomPainter {
  const _HintPushTargetPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = _shortest(size);
    final rect = Offset.zero & size;
    final radius = Radius.circular(math.max(2.0, shortest * 0.12));

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(shortest * 0.08), radius),
      Paint()..color = const Color(0x33F1D56D),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(shortest * 0.14), radius),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, shortest * 0.08)
        ..color = const Color(0xFFE3B742),
    );
  }

  @override
  bool shouldRepaint(_HintPushTargetPainter oldDelegate) => false;
}

class _CrateVisual extends StatelessWidget {
  const _CrateVisual({required this.seed, required this.isActivated});

  final int seed;
  final bool isActivated;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.94, end: 1),
      duration: const Duration(milliseconds: 95),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: CustomPaint(
        painter: _CratePainter(seed: seed, isActivated: isActivated),
      ),
    );
  }
}

class _CratePainter extends CustomPainter {
  const _CratePainter({required this.seed, required this.isActivated});

  final int seed;
  final bool isActivated;

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = _shortest(size);
    final rect = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.07,
      size.width * 0.84,
      size.height * 0.84,
    );
    final radius = Radius.circular(math.max(2.0, shortest * 0.075));
    final crate = RRect.fromRectAndRadius(rect, radius);

    if (isActivated) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(shortest * 0.055), radius),
        Paint()..color = const Color(0x2EFFD65D),
      );
    }

    canvas.drawRRect(
      crate.shift(Offset(shortest * 0.04, shortest * 0.055)),
      Paint()..color = const Color(0x33000000),
    );
    canvas.drawRRect(
      crate,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [
            Color(0xFFD09A62),
            Color(0xFFB87943),
            Color(0xFF7A4A2A),
          ],
          stops: [0, 0.58, 1],
        ).createShader(rect),
    );

    final plankLinePaint = Paint()
      ..color = const Color(0x804D2C19)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.7, shortest * 0.025);
    for (final fraction in const [0.34, 0.66]) {
      final y = rect.top + rect.height * fraction;
      canvas.drawLine(
        Offset(rect.left + shortest * 0.08, y),
        Offset(rect.right - shortest * 0.08, y),
        plankLinePaint,
      );
    }

    final bandPaint = Paint()..color = const Color(0x88633B22);
    final bandWidth = rect.width * 0.16;
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top, bandWidth, rect.height),
      bandPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(rect.right - bandWidth, rect.top, bandWidth, rect.height),
      bandPaint,
    );

    final bracePaint = Paint()
      ..color = const Color(0x8A5C351E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, shortest * 0.055)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(rect.left + rect.width * 0.23, rect.bottom - rect.height * 0.18),
      Offset(rect.right - rect.width * 0.23, rect.top + rect.height * 0.18),
      bracePaint,
    );

    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, shortest * 0.035)
      ..color = const Color(0xBB4A2816);
    canvas.drawRRect(crate, edgePaint);
    canvas.drawLine(
      Offset(rect.left + shortest * 0.08, rect.top + shortest * 0.06),
      Offset(rect.right - shortest * 0.08, rect.top + shortest * 0.06),
      Paint()
        ..color = const Color(0x8BE7B77A)
        ..strokeWidth = math.max(0.7, shortest * 0.018)
        ..strokeCap = StrokeCap.round,
    );

    _drawWoodGrain(canvas, rect, shortest);
    _drawCrateWear(canvas, rect, shortest);
  }

  void _drawWoodGrain(Canvas canvas, Rect rect, double shortest) {
    final grainPaint = Paint()
      ..color = const Color(0x3C3D2515)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.45, shortest * 0.013)
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 7; i++) {
      final x0 = rect.left + rect.width * (0.2 + _noise(seed, 150 + i) * 0.6);
      final y0 = rect.top + rect.height * (0.13 + _noise(seed, 170 + i) * 0.7);
      final lineLength = rect.width * (0.1 + _noise(seed, 190 + i) * 0.18);
      canvas.drawLine(
        Offset(x0, y0),
        Offset(x0 + lineLength, y0 + shortest * 0.01),
        grainPaint,
      );
    }
  }

  void _drawCrateWear(Canvas canvas, Rect rect, double shortest) {
    final wearPaint = Paint()
      ..color = const Color(0x72E4BE82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.7, shortest * 0.018)
      ..strokeCap = StrokeCap.round;

    final chipSize = shortest * 0.08;
    canvas.drawLine(
      Offset(rect.left + chipSize * 0.8, rect.top + chipSize * 0.7),
      Offset(rect.left + chipSize * 1.8, rect.top + chipSize * 0.45),
      wearPaint,
    );
    if (_noise(seed, 225) > 0.42) {
      canvas.drawLine(
        Offset(rect.right - chipSize * 1.8, rect.bottom - chipSize * 0.55),
        Offset(rect.right - chipSize * 0.8, rect.bottom - chipSize * 0.85),
        wearPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CratePainter oldDelegate) {
    return oldDelegate.seed != seed || oldDelegate.isActivated != isActivated;
  }
}

class _HintedBrickOutline extends StatelessWidget {
  const _HintedBrickOutline();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0xFFFFD872), width: 2.2),
        boxShadow: const [
          BoxShadow(color: Color(0x55FFB300), blurRadius: 9, spreadRadius: 0.5),
        ],
      ),
    );
  }
}

class _HintDirectionArrow extends StatelessWidget {
  const _HintDirectionArrow({required this.direction});

  final BoardPosition direction;

  IconData get _icon {
    if (direction.row < 0) {
      return Icons.arrow_upward;
    }
    if (direction.row > 0) {
      return Icons.arrow_downward;
    }
    if (direction.column < 0) {
      return Icons.arrow_back;
    }

    return Icons.arrow_forward;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortestSide = math.min(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final iconSize = math.min(22.0, shortestSide * 0.7);

        return Center(
          child: Icon(
            _icon,
            size: iconSize,
            color: Colors.white,
            shadows: const [Shadow(color: Color(0x99000000), blurRadius: 3)],
          ),
        );
      },
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({required this.direction});

  final BoardPosition direction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortestSide = math.min(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final avatarSize = math.min(26.0, shortestSide * 0.84);

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.92, end: 1),
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: SizedBox.square(
            dimension: avatarSize,
            child: CustomPaint(painter: _PlayerPainter(direction: direction)),
          ),
        );
      },
    );
  }
}

class _PlayerPainter extends CustomPainter {
  const _PlayerPainter({required this.direction});

  final BoardPosition direction;

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = _shortest(size);
    final center = Offset(size.width / 2, size.height / 2);
    final faceVector = _directionOffset(direction);
    final bodyRect = Rect.fromCenter(
      center: center.translate(0, shortest * 0.02),
      width: shortest * 0.64,
      height: shortest * 0.76,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, shortest * 0.29),
        width: shortest * 0.68,
        height: shortest * 0.2,
      ),
      Paint()..color = const Color(0x33000000),
    );
    canvas.drawOval(
      bodyRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [
            Color(0xFF4E7D77),
            Color(0xFF35655F),
            Color(0xFF244943),
          ],
        ).createShader(bodyRect),
    );
    canvas.drawOval(
      bodyRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, shortest * 0.035)
        ..color = const Color(0xCC18332F),
    );

    final hoodRect = Rect.fromCenter(
      center: center.translate(
        faceVector.dx * shortest * 0.1,
        faceVector.dy * shortest * 0.1 - shortest * 0.05,
      ),
      width: shortest * 0.46,
      height: shortest * 0.42,
    );
    canvas.drawOval(hoodRect, Paint()..color = const Color(0xCC244943));

    final faceCenter = center.translate(
      faceVector.dx * shortest * 0.16,
      faceVector.dy * shortest * 0.16 - shortest * 0.04,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: faceCenter,
        width: shortest * 0.24,
        height: shortest * 0.19,
      ),
      Paint()..color = const Color(0xFFE3C799),
    );
    canvas.drawCircle(
      center.translate(-shortest * 0.16, -shortest * 0.16),
      shortest * 0.035,
      Paint()..color = const Color(0x88B7D9D2),
    );

    final scarfPaint = Paint()
      ..color = const Color(0xFFD5A642)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, shortest * 0.07)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center.translate(-shortest * 0.17, shortest * 0.13),
      center.translate(shortest * 0.16, shortest * 0.08),
      scarfPaint,
    );
  }

  Offset _directionOffset(BoardPosition direction) {
    if (direction.row < 0) {
      return const Offset(0, -1);
    }
    if (direction.row > 0) {
      return const Offset(0, 1);
    }
    if (direction.column < 0) {
      return const Offset(-1, 0);
    }

    return const Offset(1, 0);
  }

  @override
  bool shouldRepaint(_PlayerPainter oldDelegate) {
    return oldDelegate.direction != direction;
  }
}

Color _floorTone(int seed) {
  final palette = [
    const Color(0xFFD3CAB5),
    const Color(0xFFD5C3A7),
    const Color(0xFFCAD1C2),
    const Color(0xFFD0C8B8),
  ];
  final base = palette[(_noise(seed, 1) * palette.length).floor()];

  return _shiftHsl(
    base,
    hue: (_noise(seed, 2) - 0.5) * 4.5,
    lightness: (_noise(seed, 3) - 0.5) * 0.06,
    saturation: (_noise(seed, 4) - 0.5) * 0.035,
  );
}

Color _shiftHsl(
  Color color, {
  double hue = 0,
  double saturation = 0,
  double lightness = 0,
}) {
  final hsl = HSLColor.fromColor(color);
  final nextHue = (hsl.hue + hue) % 360;
  return hsl
      .withHue(nextHue < 0 ? nextHue + 360 : nextHue)
      .withSaturation(_clampUnit(hsl.saturation + saturation))
      .withLightness(_clampUnit(hsl.lightness + lightness))
      .toColor();
}

double _clampUnit(double value) {
  return value.clamp(0.0, 1.0).toDouble();
}

double _noise(int seed, int salt) {
  final raw = math.sin((seed + salt * 1013) * 12.9898) * 43758.5453123;
  return raw - raw.floorToDouble();
}

double _shortest(Size size) {
  return math.min(size.width, size.height);
}
