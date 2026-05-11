import 'package:flutter/material.dart';

class DashedUnderline extends StatelessWidget {
  final double dashWidth;
  final double dashSpace;
  final Color color;

  const DashedUnderline({
    super.key,
    this.dashWidth = 5,
    this.dashSpace = 3,
    this.color = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          painter: _DashedLinePainter(
            dashWidth: dashWidth,
            dashSpace: dashSpace,
            color: color,
          ),
          child: SizedBox(
            height: 1,
            width: constraints.maxWidth.isFinite ? constraints.maxWidth : 100,
          ),
        );
      },
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final double dashWidth;
  final double dashSpace;
  final Color color;

  _DashedLinePainter({
    required this.dashWidth,
    required this.dashSpace,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 1;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
