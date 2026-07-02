import 'package:flutter/material.dart';

import '../constants/color.dart';

enum StepperAdjustKind { increment, decrement }

/// Compact plus / minus glyphs for quantity and price steppers.
///
/// Uses filled rounded bars (pill caps) instead of Material [Icons.add] /
/// [Icons.remove] for clearer contrast on circular stepper buttons.
class StepperAdjustIcon extends StatelessWidget {
  const StepperAdjustIcon({
    super.key,
    required this.kind,
    required this.size,
    this.color,
  });

  final StepperAdjustKind kind;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? switch (kind) {
      StepperAdjustKind.decrement => AppColors.primary,
      StepperAdjustKind.increment => AppColors.primary,
    };

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StepperAdjustPainter(kind: kind, color: iconColor),
      ),
    );
  }
}

class _StepperAdjustPainter extends CustomPainter {
  _StepperAdjustPainter({required this.kind, required this.color});

  final StepperAdjustKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final barThickness = size.width * 0.18;
    final barLength = size.width * 0.58;
    final radius = Radius.circular(barThickness / 2);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: barLength,
          height: barThickness,
        ),
        radius,
      ),
      paint,
    );

    if (kind == StepperAdjustKind.increment) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center,
            width: barThickness,
            height: barLength,
          ),
          radius,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StepperAdjustPainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.color != color;
  }
}