import 'package:flutter/material.dart';
import 'dart:math' as math;

class PlaceholderBox extends StatelessWidget {
  final double fontSize;
  final Color color;
  final double? minWidth;
  final double? minHeight;
  final Widget? child;
  final VoidCallback? onTap;

  const PlaceholderBox({
    super.key,
    required this.fontSize,
    this.color = Colors.white,
    this.minWidth,
    this.minHeight,
    this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final boxWidth = minWidth ?? fontSize * 0.8;
    final boxHeight = minHeight ?? fontSize * 0.9;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: CornerBracketPainter(
          color: color,
          strokeWidth: math.max(1.5, fontSize * 0.06),
          cornerLength: fontSize * 0.2,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: boxWidth, minHeight: boxHeight),
          child: Center(
            child: child ?? SizedBox(width: boxWidth, height: boxHeight),
          ),
        ),
      ),
    );
  }
}

class CornerBracketPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double cornerLength;

  CornerBracketPainter({
    required this.color,
    required this.strokeWidth,
    required this.cornerLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    final double padding = strokeWidth;
    final double len = cornerLength;

    // Top-left corner
    canvas.drawLine(
      Offset(padding, padding + len),
      Offset(padding, padding),
      paint,
    );
    canvas.drawLine(
      Offset(padding, padding),
      Offset(padding + len, padding),
      paint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(size.width - padding - len, padding),
      Offset(size.width - padding, padding),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - padding, padding),
      Offset(size.width - padding, padding + len),
      paint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(padding, size.height - padding - len),
      Offset(padding, size.height - padding),
      paint,
    );
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(padding + len, size.height - padding),
      paint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(size.width - padding - len, size.height - padding),
      Offset(size.width - padding, size.height - padding),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - padding, size.height - padding - len),
      Offset(size.width - padding, size.height - padding),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CornerBracketPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.cornerLength != cornerLength;
  }
}
