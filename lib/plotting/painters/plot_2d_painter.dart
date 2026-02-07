import 'dart:math';
import '../../utils/app_colors.dart';
import 'package:flutter/material.dart';
import '../models/enums.dart';
import '../parsers/math_parser.dart';
import '../parsers/vector_field_parser.dart';
import '../utils/colormap.dart';
import '../utils/plot_theme.dart';

class Plot2DPainter extends CustomPainter {
  final String function;
  final double xMin, xMax, yMin, yMax;
  final PlotMode plotMode;
  final FieldType fieldType;
  final VectorFieldParser? vectorParser;
  final bool showContour;
  final SurfaceMode surfaceMode;
  final AppColors colors;

  Plot2DPainter({
    required this.function,
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    required this.plotMode,
    required this.fieldType,
    this.vectorParser,
    required this.showContour,
    required this.surfaceMode,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double toScreenX(double x) => (x - xMin) / (xMax - xMin) * size.width;
    double toScreenY(double y) =>
        size.height - (y - yMin) / (yMax - yMin) * size.height;
    final bool showSurface = surfaceMode != SurfaceMode.none;

    _drawGrid(canvas, size, toScreenX, toScreenY);
    _drawAxes(canvas, size, toScreenX, toScreenY);

    // Draw surface (heatmap) if enabled
    if (showSurface) {
      if (fieldType == FieldType.vector && vectorParser != null) {
        if (surfaceMode == SurfaceMode.magnitude) {
          _drawVectorMagnitudeSurface(canvas, size, toScreenX, toScreenY);
        } else {
          _drawVectorComponentSurface(
            canvas,
            size,
            toScreenX,
            toScreenY,
            surfaceMode,
          );
        }
      } else if (fieldType == FieldType.scalar) {
        _drawScalarSurface(canvas, size, toScreenX, toScreenY);
      }
    }

    if (plotMode == PlotMode.field) {
      if (fieldType == FieldType.vector && vectorParser != null) {
        _drawVectorMagnitudeField(canvas, size, toScreenX, toScreenY);
      } else {
        _drawScalarField(canvas, size, toScreenX, toScreenY);
      }
    } else {
      if (fieldType == FieldType.vector && vectorParser != null) {
        _drawVectorField(canvas, size, toScreenX, toScreenY);
      } else {
        _drawFunction(canvas, size, toScreenX, toScreenY);
      }
    }

    // Draw contour lines if enabled
    if (showContour) {
      if (fieldType == FieldType.scalar) {
        _drawContourLines(canvas, size, toScreenX, toScreenY);
      } else if (fieldType == FieldType.vector &&
          showSurface &&
          vectorParser != null) {
        if (surfaceMode == SurfaceMode.magnitude) {
          _drawVectorMagnitudeContours(canvas, size, toScreenX, toScreenY);
        } else {
          _drawVectorComponentContours(
            canvas,
            size,
            toScreenX,
            toScreenY,
            surfaceMode,
          );
        }
      }
    }

    _drawLabels(canvas, size, toScreenX, toScreenY);
  }

  void _drawScalarSurface(
    Canvas canvas,
    Size size,
    double Function(double) toScreenX,
    double Function(double) toScreenY,
  ) {
    final parser = MathParser(function);

    // Check if function uses y (is 2D)
    if (!parser.usesY) return;

    const gridCount = 40;
    final cellWidth = size.width / gridCount;
    final cellHeight = size.height / gridCount;

    // First pass: find min/max values
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;

    for (int i = 0; i <= gridCount; i++) {
      for (int j = 0; j <= gridCount; j++) {
        final x = xMin + (xMax - xMin) * i / gridCount;
        final y = yMin + (yMax - yMin) * j / gridCount;
        try {
          final val = parser.evaluate(x, y);
          if (val.isFinite) {
            minVal = min(minVal, val);
            maxVal = max(maxVal, val);
          }
          // ignore: empty_catches
        } catch (e) {}
      }
    }

    if (minVal == maxVal) maxVal = minVal + 1;
    if (!minVal.isFinite || !maxVal.isFinite) return;

    // Second pass: draw heatmap
    for (int i = 0; i < gridCount; i++) {
      for (int j = 0; j < gridCount; j++) {
        final x = xMin + (xMax - xMin) * (i + 0.5) / gridCount;
        final y = yMin + (yMax - yMin) * (j + 0.5) / gridCount;

        try {
          final val = parser.evaluate(x, y);
          if (!val.isFinite) continue;

          final normalized = (val - minVal) / (maxVal - minVal);
          final color = jetColormap(normalized);

          final rect = Rect.fromLTWH(
            i * cellWidth,
            size.height - (j + 1) * cellHeight,
            cellWidth + 1,
            cellHeight + 1,
          );

          canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.6));
          // ignore: empty_catches
        } catch (e) {}
      }
    }

    _drawColorbar(canvas, size, minVal, maxVal);
  }

  void _drawVectorMagnitudeSurface(
    Canvas canvas,
    Size size,
    double Function(double) toScreenX,
    double Function(double) toScreenY,
  ) {
    if (vectorParser == null) return;

    const gridCount = 40;
    final cellWidth = size.width / gridCount;
    final cellHeight = size.height / gridCount;

    // First pass: find max magnitude
      double maxMag = 0;
      for (int i = 0; i <= gridCount; i++) {
        for (int j = 0; j <= gridCount; j++) {
          final x = xMin + (xMax - xMin) * i / gridCount;
          final y = yMin + (yMax - yMin) * j / gridCount;
          double mag = vectorParser!.magnitude(x, y);
          if (surfaceMode == SurfaceMode.x) {
            mag = vectorParser!.componentValue(SurfaceMode.x, x, y).abs();
          } else if (surfaceMode == SurfaceMode.y) {
            mag = vectorParser!.componentValue(SurfaceMode.y, x, y).abs();
          } else if (surfaceMode == SurfaceMode.z) {
            mag = vectorParser!.componentValue(SurfaceMode.z, x, y).abs();
          }
          if (mag.isFinite) maxMag = max(maxMag, mag);
        }
      }

    if (maxMag == 0) maxMag = 1;

    // Second pass: draw heatmap
    for (int i = 0; i < gridCount; i++) {
      for (int j = 0; j < gridCount; j++) {
        final x = xMin + (xMax - xMin) * (i + 0.5) / gridCount;
        final y = yMin + (yMax - yMin) * (j + 0.5) / gridCount;

        final mag = vectorParser!.magnitude(x, y);
        if (!mag.isFinite) continue;

        final normalized = mag / maxMag;
        final color = jetColormap(normalized);

        final rect = Rect.fromLTWH(
          i * cellWidth,
          size.height - (j + 1) * cellHeight,
          cellWidth + 1,
          cellHeight + 1,
        );

        canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.6));
      }
    }

    _drawColorbar(canvas, size, 0, maxMag);
  }

  void _drawVectorComponentSurface(
    Canvas canvas,
    Size size,
    double Function(double) toScreenX,
    double Function(double) toScreenY,
    SurfaceMode mode,
  ) {
    if (vectorParser == null) return;

    const gridCount = 40;
    final cellWidth = size.width / gridCount;
    final cellHeight = size.height / gridCount;

    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;

    for (int i = 0; i <= gridCount; i++) {
      for (int j = 0; j <= gridCount; j++) {
        final x = xMin + (xMax - xMin) * i / gridCount;
        final y = yMin + (yMax - yMin) * j / gridCount;
        final val = vectorParser!.componentValue(mode, x, y);
        if (!val.isFinite) continue;
        minVal = min(minVal, val);
        maxVal = max(maxVal, val);
      }
    }

    if (minVal == maxVal) maxVal = minVal + 1;
    if (!minVal.isFinite || !maxVal.isFinite) return;

    for (int i = 0; i < gridCount; i++) {
      for (int j = 0; j < gridCount; j++) {
        final x = xMin + (xMax - xMin) * (i + 0.5) / gridCount;
        final y = yMin + (yMax - yMin) * (j + 0.5) / gridCount;

        final val = vectorParser!.componentValue(mode, x, y);
        if (!val.isFinite) continue;

        final normalized = (val - minVal) / (maxVal - minVal);
        final color = jetColormap(normalized.clamp(0.0, 1.0));

        final rect = Rect.fromLTWH(
          i * cellWidth,
          size.height - (j + 1) * cellHeight,
          cellWidth + 1,
          cellHeight + 1,
        );

        canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.6));
      }
    }

    _drawColorbar(canvas, size, minVal, maxVal);
  }

  void _drawVectorMagnitudeContours(
    Canvas canvas,
    Size size,
    double Function(double) toScreenX,
    double Function(double) toScreenY,
  ) {
    if (vectorParser == null) return;

    const gridSize = 60;
    const numContours = 15;

    // Build grid of magnitude values
    List<List<double>> grid = [];
    double maxMag = 0;

    for (int i = 0; i <= gridSize; i++) {
      List<double> row = [];
      for (int j = 0; j <= gridSize; j++) {
        final x = xMin + (xMax - xMin) * i / gridSize;
        final y = yMin + (yMax - yMin) * j / gridSize;
        final mag = vectorParser!.magnitude(x, y);
        if (mag.isFinite) {
          row.add(mag);
          maxMag = max(maxMag, mag);
        } else {
          row.add(0);
        }
      }
      grid.add(row);
    }

    if (maxMag == 0) return;

    // Draw contour lines using marching squares
    for (int level = 0; level < numContours; level++) {
      final threshold = maxMag * (level + 1) / (numContours + 1);
      final normalizedLevel = threshold / maxMag;
      final color = jetColormap(normalizedLevel);

      final paint =
          Paint()
            ..color = color
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke;

      _drawContourLevelGeneric(
        canvas,
        size,
        grid,
        threshold,
        paint,
        toScreenX,
        toScreenY,
        0,
        maxMag,
      );
    }
  }

  void _drawVectorComponentContours(
    Canvas canvas,
    Size size,
    double Function(double) toScreenX,
    double Function(double) toScreenY,
    SurfaceMode mode,
  ) {
    if (vectorParser == null) return;

    const gridSize = 60;
    const numContours = 15;

    List<List<double>> grid = [];
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;

    for (int i = 0; i <= gridSize; i++) {
      List<double> row = [];
      for (int j = 0; j <= gridSize; j++) {
        final x = xMin + (xMax - xMin) * i / gridSize;
        final y = yMin + (yMax - yMin) * j / gridSize;
        final val = vectorParser!.componentValue(mode, x, y);
        if (val.isFinite) {
          row.add(val);
          minVal = min(minVal, val);
          maxVal = max(maxVal, val);
        } else {
          row.add(0);
        }
      }
      grid.add(row);
    }

    if (minVal == maxVal) return;

    for (int level = 0; level < numContours; level++) {
      final threshold =
          minVal + (maxVal - minVal) * (level + 1) / (numContours + 1);
      final normalizedLevel = (threshold - minVal) / (maxVal - minVal);
      final color = jetColormap(normalizedLevel);

      final paint =
          Paint()
            ..color = color
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke;

      _drawContourLevelGeneric(
        canvas,
        size,
        grid,
        threshold,
        paint,
        toScreenX,
        toScreenY,
        minVal,
        maxVal,
      );
    }
  }

  void _drawContourLevelGeneric(
    Canvas canvas,
    Size size,
    List<List<double>> grid,
    double threshold,
    Paint paint,
    double Function(double) toScreenX,
    double Function(double) toScreenY,
    double minVal,
    double maxVal,
  ) {
    final gridSize = grid.length - 1;

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final v0 = grid[i][j];
        final v1 = grid[i + 1][j];
        final v2 = grid[i + 1][j + 1];
        final v3 = grid[i][j + 1];

        // Marching squares case
        int caseIndex = 0;
        if (v0 >= threshold) caseIndex |= 1;
        if (v1 >= threshold) caseIndex |= 2;
        if (v2 >= threshold) caseIndex |= 4;
        if (v3 >= threshold) caseIndex |= 8;

        if (caseIndex == 0 || caseIndex == 15) continue;

        final x0 = xMin + (xMax - xMin) * i / gridSize;
        final x1 = xMin + (xMax - xMin) * (i + 1) / gridSize;
        final y0 = yMin + (yMax - yMin) * j / gridSize;
        final y1 = yMin + (yMax - yMin) * (j + 1) / gridSize;

        // Interpolate edge crossings
        List<Offset> points = [];

        // Bottom edge (v0 - v1)
        if ((v0 >= threshold) != (v1 >= threshold)) {
          final t = (threshold - v0) / (v1 - v0);
          points.add(Offset(toScreenX(x0 + t * (x1 - x0)), toScreenY(y0)));
        }
        // Right edge (v1 - v2)
        if ((v1 >= threshold) != (v2 >= threshold)) {
          final t = (threshold - v1) / (v2 - v1);
          points.add(Offset(toScreenX(x1), toScreenY(y0 + t * (y1 - y0))));
        }
        // Top edge (v2 - v3)
        if ((v2 >= threshold) != (v3 >= threshold)) {
          final t = (threshold - v3) / (v2 - v3);
          points.add(Offset(toScreenX(x0 + t * (x1 - x0)), toScreenY(y1)));
        }
        // Left edge (v3 - v0)
        if ((v3 >= threshold) != (v0 >= threshold)) {
          final t = (threshold - v0) / (v3 - v0);
          points.add(Offset(toScreenX(x0), toScreenY(y0 + t * (y1 - y0))));
        }

        // Draw lines between pairs of points
        if (points.length >= 2) {
          canvas.drawLine(points[0], points[1], paint);
        }
        if (points.length >= 4) {
          canvas.drawLine(points[2], points[3], paint);
        }
      }
    }
  }

  void _drawGrid(
    Canvas canvas,
    Size size,
    double Function(double) toScreenX,
    double Function(double) toScreenY,
  ) {
    final theme = PlotThemeData.fromColors(colors);
    final gridPaint =
        Paint()
          ..color = theme.grid
          ..strokeWidth = 1.2;
    final subGridPaint =
        Paint()
          ..color = theme.subGrid
          ..strokeWidth = 0.8;
    final rangeX = (xMax - xMin).abs();
    final rangeY = (yMax - yMin).abs();
    final spacingX = _calculateGridSpacing(rangeX, 8);
    final spacingY = _calculateGridSpacing(rangeY, 8);
    final subSpacingX = spacingX / 5;
    final subSpacingY = spacingY / 5;
    final subXPixel = subSpacingX * size.width / rangeX;
    final subYPixel = subSpacingY * size.height / rangeY;

    for (
      double x = (xMin / spacingX).floor() * spacingX;
      x <= xMax;
      x += subSpacingX
    ) {
      if (subXPixel >= 12) {
        canvas.drawLine(
          Offset(toScreenX(x), 0),
          Offset(toScreenX(x), size.height),
          subGridPaint,
        );
      }
    }
    for (
      double y = (yMin / spacingY).floor() * spacingY;
      y <= yMax;
      y += subSpacingY
    ) {
      if (subYPixel >= 12) {
        canvas.drawLine(
          Offset(0, toScreenY(y)),
          Offset(size.width, toScreenY(y)),
          subGridPaint,
        );
      }
    }
    for (
      double x = (xMin / spacingX).floor() * spacingX;
      x <= xMax;
      x += spacingX
    ) {
      canvas.drawLine(
        Offset(toScreenX(x), 0),
        Offset(toScreenX(x), size.height),
        gridPaint,
      );
    }
    for (
      double y = (yMin / spacingY).floor() * spacingY;
      y <= yMax;
      y += spacingY
    ) {
      canvas.drawLine(
        Offset(0, toScreenY(y)),
        Offset(size.width, toScreenY(y)),
        gridPaint,
      );
    }
  }

  void _drawAxes(
    Canvas canvas,
    Size size,
    double Function(double) toScreenX,
    double Function(double) toScreenY,
  ) {
    final theme = PlotThemeData.fromColors(colors);
    final axisPaint =
        Paint()
          ..color = theme.axis
          ..strokeWidth = 2;
    final axisGlowPaint =
        Paint()
          ..color = theme.axis.withValues(alpha: 0.35)
          ..strokeWidth = 6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final tickPaint =
        Paint()
          ..color = theme.tick
          ..strokeWidth = 1;

    if (yMin <= 0 && yMax >= 0) {
      final y0 = toScreenY(0);
      canvas.drawLine(Offset(0, y0), Offset(size.width, y0), axisGlowPaint);
      canvas.drawLine(Offset(0, y0), Offset(size.width, y0), axisPaint);
    }
    if (xMin <= 0 && xMax >= 0) {
      final x0 = toScreenX(0);
      canvas.drawLine(Offset(x0, 0), Offset(x0, size.height), axisGlowPaint);
      canvas.drawLine(Offset(x0, 0), Offset(x0, size.height), axisPaint);
    }

    final rangeX = (xMax - xMin).abs();
    final rangeY = (yMax - yMin).abs();
    final spacingX = _calculateGridSpacing(rangeX, 8);
    final spacingY = _calculateGridSpacing(rangeY, 8);
    for (
      double x = (xMin / spacingX).ceil() * spacingX;
      x <= xMax;
      x += spacingX
    ) {
      if (x.abs() > 0.001 && yMin <= 0 && yMax >= 0) {
        final y0 = toScreenY(0).clamp(10.0, size.height - 10);
        canvas.drawLine(
          Offset(toScreenX(x), y0 - 5),
          Offset(toScreenX(x), y0 + 5),
          tickPaint,
        );
      }
    }
    for (
      double y = (yMin / spacingY).ceil() * spacingY;
      y <= yMax;
      y += spacingY
    ) {
      if (y.abs() > 0.001 && xMin <= 0 && xMax >= 0) {
        final x0 = toScreenX(0).clamp(10.0, size.width - 10);
        canvas.drawLine(
          Offset(x0 - 5, toScreenY(y)),
          Offset(x0 + 5, toScreenY(y)),
          tickPaint,
        );
      }
    }
  }

  void _drawFunction(
    Canvas canvas,
    Size size,
    double Function(double) toScreenX,
    double Function(double) toScreenY,
  ) {
    final paint =
        Paint()
          ..color = colors.accent
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    final parser = MathParser(function);
    final path = Path();
    const steps = 1000;
    bool started = false;
    double? lastY;

    for (int i = 0; i <= steps; i++) {
      final x = xMin + i * (xMax - xMin) / steps;
      double y;
      try {
        y = parser.evaluate(x, 0);
      } catch (e) {
        started = false;
        lastY = null;
        continue;
      }

      if (y.isFinite && y.abs() < 1e6) {
        if (lastY != null && (y - lastY).abs() > (yMax - yMin) * 0.5) {
          started = false;
        }
        if (!started) {
          path.moveTo(toScreenX(x), toScreenY(y));
          started = true;
        } else {
          path.lineTo(toScreenX(x), toScreenY(y));
        }
        lastY = y;
      } else {
        started = false;
        lastY = null;
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawScalarField(
    Canvas canvas,
    Size size,
    double Function(double) toScreenX,
    double Function(double) toScreenY,
  ) {
    final parser = MathParser(function);
    const gridCount = 25;
    final circleRadius = min(size.width, size.height) / gridCount / 3;

    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;

    for (int i = 0; i <= gridCount; i++) {
      for (int j = 0; j <= gridCount; j++) {
        final x = xMin + (xMax - xMin) * i / gridCount;
        final y = yMin + (yMax - yMin) * j / gridCount;
        try {
          final val = parser.evaluate(x, y);
          if (val.isFinite) {
            minVal = min(minVal, val);
            maxVal = max(maxVal, val);
          }
          // ignore: empty_catches
        } catch (e) {}
      }
    }

    if (minVal == maxVal) maxVal = minVal + 1;

    for (int i = 0; i <= gridCount; i++) {
      for (int j = 0; j <= gridCount; j++) {
        final x = xMin + (xMax - xMin) * i / gridCount;
        final y = yMin + (yMax - yMin) * j / gridCount;

        try {
          final val = parser.evaluate(x, y);
          if (!val.isFinite) continue;

          final normalized = (val - minVal) / (maxVal - minVal);
          final color = jetColormap(normalized);

          canvas.drawCircle(
            Offset(toScreenX(x), toScreenY(y)),
            circleRadius,
            Paint()..color = color.withValues(alpha: 0.8),
          );
          // ignore: empty_catches
        } catch (e) {}
      }
    }

    if (surfaceMode == SurfaceMode.none) {
      _drawColorbar(canvas, size, minVal, maxVal);
    }
  }

  void _drawContourLines(
    Canvas canvas,
    Size size,
    double Function(double) toScreenX,
    double Function(double) toScreenY,
  ) {
    final parser = MathParser(function);
    const gridSize = 100;
    const numContours = 15;

    // Build grid of values
    List<List<double>> grid = [];
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;

    for (int i = 0; i <= gridSize; i++) {
      List<double> row = [];
      for (int j = 0; j <= gridSize; j++) {
        final x = xMin + (xMax - xMin) * i / gridSize;
        final y = yMin + (yMax - yMin) * j / gridSize;
        double val;
        try {
          val = parser.evaluate(x, y);
          if (!val.isFinite) val = 0;
        } catch (e) {
          val = 0;
        }
        row.add(val);
        if (val.isFinite && val != 0) {
          minVal = min(minVal, val);
          maxVal = max(maxVal, val);
        }
      }
      grid.add(row);
    }

    if (minVal == maxVal) return;

    // Draw contour lines using marching squares
    for (int level = 0; level < numContours; level++) {
      final threshold =
          minVal + (maxVal - minVal) * (level + 1) / (numContours + 1);
      final normalizedLevel = (threshold - minVal) / (maxVal - minVal);
      final color = jetColormap(normalizedLevel);

      final paint =
          Paint()
            ..color = color
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke;

      _drawContourLevel(
        canvas,
        size,
        grid,
        threshold,
        paint,
        toScreenX,
        toScreenY,
      );
    }
  }

  void _drawContourLevel(
    Canvas canvas,
    Size size,
    List<List<double>> grid,
    double threshold,
    Paint paint,
    double Function(double) toScreenX,
    double Function(double) toScreenY,
  ) {
    final gridSize = grid.length - 1;

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final v0 = grid[i][j];
        final v1 = grid[i + 1][j];
        final v2 = grid[i + 1][j + 1];
        final v3 = grid[i][j + 1];

        // Marching squares case
        int caseIndex = 0;
        if (v0 >= threshold) caseIndex |= 1;
        if (v1 >= threshold) caseIndex |= 2;
        if (v2 >= threshold) caseIndex |= 4;
        if (v3 >= threshold) caseIndex |= 8;

        if (caseIndex == 0 || caseIndex == 15) continue;

        final x0 = xMin + (xMax - xMin) * i / gridSize;
        final x1 = xMin + (xMax - xMin) * (i + 1) / gridSize;
        final y0 = yMin + (yMax - yMin) * j / gridSize;
        final y1 = yMin + (yMax - yMin) * (j + 1) / gridSize;

        // Interpolate edge crossings
        List<Offset> points = [];

        // Bottom edge (v0 - v1)
        if ((v0 >= threshold) != (v1 >= threshold)) {
          final t = (threshold - v0) / (v1 - v0);
          points.add(Offset(toScreenX(x0 + t * (x1 - x0)), toScreenY(y0)));
        }
        // Right edge (v1 - v2)
        if ((v1 >= threshold) != (v2 >= threshold)) {
          final t = (threshold - v1) / (v2 - v1);
          points.add(Offset(toScreenX(x1), toScreenY(y0 + t * (y1 - y0))));
        }
        // Top edge (v2 - v3)
        if ((v2 >= threshold) != (v3 >= threshold)) {
          final t = (threshold - v3) / (v2 - v3);
          points.add(Offset(toScreenX(x0 + t * (x1 - x0)), toScreenY(y1)));
        }
        // Left edge (v3 - v0)
        if ((v3 >= threshold) != (v0 >= threshold)) {
          final t = (threshold - v0) / (v3 - v0);
          points.add(Offset(toScreenX(x0), toScreenY(y0 + t * (y1 - y0))));
        }

        // Draw lines between pairs of points
        if (points.length >= 2) {
          canvas.drawLine(points[0], points[1], paint);
        }
        if (points.length >= 4) {
          canvas.drawLine(points[2], points[3], paint);
        }
      }
    }
  }

  void _drawVectorField(
    Canvas canvas,
    Size size,
    double Function(double) toScreenX,
    double Function(double) toScreenY,
  ) {
    if (vectorParser == null) return;

    const gridCount = 20;
    final arrowLength = min(size.width, size.height) / gridCount / 1.0;

    double maxMag = 0;
    for (int i = 0; i <= gridCount; i++) {
      for (int j = 0; j <= gridCount; j++) {
        final x = xMin + (xMax - xMin) * i / gridCount;
        final y = yMin + (yMax - yMin) * j / gridCount;
        final mag = vectorParser!.magnitude(x, y);
        if (mag.isFinite) maxMag = max(maxMag, mag);
      }
    }

    if (maxMag == 0) maxMag = 1;

    for (int i = 0; i <= gridCount; i++) {
      for (int j = 0; j <= gridCount; j++) {
        final x = xMin + (xMax - xMin) * i / gridCount;
        final y = yMin + (yMax - yMin) * j / gridCount;

          final (fx, fy, fz) = vectorParser!.evaluate(x, y);
          double vx = fx;
          double vy = fy;
          double mag = vectorParser!.magnitude(x, y);

          if (surfaceMode == SurfaceMode.x) {
            vx = fx;
            vy = 0;
            mag = fx.abs();
          } else if (surfaceMode == SurfaceMode.y) {
            vx = 0;
            vy = fy;
            mag = fy.abs();
          } else if (surfaceMode == SurfaceMode.z) {
            vx = 0;
            vy = 0;
            mag = fz.abs();
          }

          if (!mag.isFinite || mag < 1e-10) continue;

          final normalized = mag / maxMag;
          final color = jetColormap(normalized);

          final scale = mag == 0 ? 0 : 1 / mag;
          final nx = vx * scale;
          final ny = vy * scale;

          final startX = toScreenX(x);
          final startY = toScreenY(y);
          final endX = startX + nx * arrowLength;
          final endY = startY - ny * arrowLength;

        final paint =
            Paint()
              ..color = color
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round;

        canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);

        // Arrowhead
        final angle = atan2(-(endY - startY), endX - startX);
        const headLength = 6.0;
        const headAngle = 0.5;

        canvas.drawLine(
          Offset(endX, endY),
          Offset(
            endX - headLength * cos(angle - headAngle),
            endY + headLength * sin(angle - headAngle),
          ),
          paint,
        );
        canvas.drawLine(
          Offset(endX, endY),
          Offset(
            endX - headLength * cos(angle + headAngle),
            endY + headLength * sin(angle + headAngle),
          ),
          paint,
        );
      }
    }

    if (surfaceMode == SurfaceMode.none) {
      _drawColorbar(canvas, size, 0, maxMag);
    }
  }

  void _drawVectorMagnitudeField(
    Canvas canvas,
    Size size,
    double Function(double) toScreenX,
    double Function(double) toScreenY,
  ) {
    if (vectorParser == null) return;

    const gridCount = 25;
    final circleRadius = min(size.width, size.height) / gridCount / 3;

    double maxMag = 0;
    for (int i = 0; i <= gridCount; i++) {
      for (int j = 0; j <= gridCount; j++) {
        final x = xMin + (xMax - xMin) * i / gridCount;
        final y = yMin + (yMax - yMin) * j / gridCount;
        final mag = vectorParser!.magnitude(x, y);
        if (mag.isFinite) maxMag = max(maxMag, mag);
      }
    }

    if (maxMag == 0) maxMag = 1;

    for (int i = 0; i <= gridCount; i++) {
      for (int j = 0; j <= gridCount; j++) {
        final x = xMin + (xMax - xMin) * i / gridCount;
        final y = yMin + (yMax - yMin) * j / gridCount;

        final mag = vectorParser!.magnitude(x, y);
        if (!mag.isFinite) continue;

        final normalized = mag / maxMag;
        final color = jetColormap(normalized);

        canvas.drawCircle(
          Offset(toScreenX(x), toScreenY(y)),
          circleRadius,
          Paint()..color = color.withValues(alpha: 0.8),
        );
      }
    }

    if (surfaceMode == SurfaceMode.none) {
      _drawColorbar(canvas, size, 0, maxMag);
    }
  }

  void _drawColorbar(Canvas canvas, Size size, double minVal, double maxVal) {
    final theme = PlotThemeData.fromColors(colors);
    const barWidth = 15.0;
    const barHeight = 100.0;
    const margin = 10.0;

    final barRect = Rect.fromLTWH(
      margin,
      size.height / 2 - barHeight / 2,
      barWidth,
      barHeight,
    );

    for (int i = 0; i < barHeight; i++) {
      final t = 1.0 - i / barHeight;
      final color = jetColormap(t);
      canvas.drawLine(
        Offset(barRect.left, barRect.top + i),
        Offset(barRect.right, barRect.top + i),
        Paint()..color = color,
      );
    }

    canvas.drawRect(
      barRect,
      Paint()
        ..color = theme.colorbarBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final textStyle = TextStyle(color: theme.colorbarText, fontSize: 10);
    final maxTp = TextPainter(
      text: TextSpan(text: _formatNumber(maxVal), style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    maxTp.paint(canvas, Offset(barRect.right + 4, barRect.top - 4));

    final minTp = TextPainter(
      text: TextSpan(text: _formatNumber(minVal), style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    minTp.paint(canvas, Offset(barRect.right + 4, barRect.bottom - 6));
  }

  void _drawLabels(
    Canvas canvas,
    Size size,
    double Function(double) toScreenX,
    double Function(double) toScreenY,
  ) {
    final theme = PlotThemeData.fromColors(colors);
    final textStyle = TextStyle(color: theme.label, fontSize: 12);
    final rangeX = (xMax - xMin).abs();
    final rangeY = (yMax - yMin).abs();
    final spacingX = _calculateGridSpacing(rangeX, 8);
    final spacingY = _calculateGridSpacing(rangeY, 8);

    for (
      double x = (xMin / spacingX).ceil() * spacingX;
      x <= xMax;
      x += spacingX
    ) {
      if (x.abs() > 0.001 && yMin <= 0 && yMax >= 0) {
        final y0 = toScreenY(0).clamp(20.0, size.height - 20);
        final tp = TextPainter(
          text: TextSpan(text: _formatNumber(x), style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(toScreenX(x) - tp.width / 2, y0 + 8));
      }
    }
    for (
      double y = (yMin / spacingY).ceil() * spacingY;
      y <= yMax;
      y += spacingY
    ) {
      if (y.abs() > 0.001 && xMin <= 0 && xMax >= 0) {
        final x0 = toScreenX(0).clamp(30.0, size.width - 30);
        final tp = TextPainter(
          text: TextSpan(text: _formatNumber(y), style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(x0 - tp.width - 8, toScreenY(y) - tp.height / 2),
        );
      }
    }
  }

  String _formatNumber(double n) {
    if (n.abs() < 0.001) return '0';
    if (n == n.roundToDouble() && n.abs() < 100) return n.toInt().toString();
    if (n.abs() >= 100) return n.toStringAsFixed(0);
    if (n.abs() >= 10) return n.toStringAsFixed(1);
    return n.toStringAsFixed(2);
  }

  double _calculateGridSpacing(double range, int maxLines) {
    if (range <= 0) return 1;
    final roughStep = range / maxLines;
    final magnitude = pow(10, (log(roughStep) / ln10).floor()).toDouble();
    final normalized = roughStep / magnitude;
    double nice;
    if (normalized <= 1) {
      nice = 1;
    } else if (normalized <= 2) {
      nice = 2;
    } else if (normalized <= 5) {
      nice = 5;
    } else {
      nice = 10;
    }
    return nice * magnitude;
  }

  @override
  bool shouldRepaint(covariant Plot2DPainter old) =>
      old.xMin != xMin ||
      old.xMax != xMax ||
      old.yMin != yMin ||
      old.yMax != yMax ||
      old.function != function ||
      old.plotMode != plotMode ||
      old.fieldType != fieldType ||
      old.showContour != showContour ||
      old.surfaceMode != surfaceMode ||
      old.colors != colors;
}
