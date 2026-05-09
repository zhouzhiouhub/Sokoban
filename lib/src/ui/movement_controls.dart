import 'package:flutter/material.dart';

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
          icon: Icons.keyboard_arrow_up,
          tooltip: '向上移动',
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildButton(
              onPressed: onLeft,
              icon: Icons.keyboard_arrow_left,
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
                child: Icon(Icons.person, color: Color(0xFF526652)),
              ),
            ),
            const SizedBox(width: 8),
            buildButton(
              onPressed: onRight,
              icon: Icons.keyboard_arrow_right,
              tooltip: '向右移动',
            ),
          ],
        ),
        const SizedBox(height: 8),
        buildButton(
          onPressed: onDown,
          icon: Icons.keyboard_arrow_down,
          tooltip: '向下移动',
        ),
      ],
    );
  }
}
