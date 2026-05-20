import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class MovementControls extends StatelessWidget {
  const MovementControls({
    super.key,
    required this.onUp,
    required this.onDown,
    required this.onLeft,
    required this.onRight,
  });

  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) {
    Widget buildButton({
      required VoidCallback onPressed,
      required IconData icon,
      required String tooltip,
    }) {
      return SizedBox(
        width: 56,
        height: 56,
        child: FilledButton.tonal(
          onPressed: onPressed,
          child: Tooltip(message: tooltip, child: Icon(icon)),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildButton(
          onPressed: onUp,
          icon: LucideIcons.chevronUp,
          tooltip: '向上移动',
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildButton(
              onPressed: onLeft,
              icon: LucideIcons.chevronLeft,
              tooltip: '向左移动',
            ),
            const SizedBox(width: 8),
            const SizedBox(
              width: 56,
              height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFDDD3BE),
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.user, color: Color(0xFF526652)),
              ),
            ),
            const SizedBox(width: 8),
            buildButton(
              onPressed: onRight,
              icon: LucideIcons.chevronRight,
              tooltip: '向右移动',
            ),
          ],
        ),
        const SizedBox(height: 8),
        buildButton(
          onPressed: onDown,
          icon: LucideIcons.chevronDown,
          tooltip: '向下移动',
        ),
      ],
    );
  }
}
