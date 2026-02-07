import 'package:flutter/material.dart';
import '../models/enums.dart';
import '../../utils/app_colors.dart';
import '../parsers/vector_field_parser.dart';
import '../parsers/math_parser.dart';
import '../painters/plot_2d_painter.dart';
import '../utils/plot_theme.dart';

class Plot2DScreen extends StatefulWidget {
  final String function;
  final bool is3DFunction;
  final PlotMode plotMode;
  final FieldType fieldType;
  final VectorFieldParser? vectorParser;
  final bool showContour;
  final SurfaceMode surfaceMode;
  final ZoomAxis zoomAxis; // New
  final AppColors colors;

  const Plot2DScreen({
    super.key,
    required this.function,
    required this.is3DFunction,
    required this.plotMode,
    required this.fieldType,
    this.vectorParser,
    required this.showContour,
    required this.surfaceMode,
    required this.zoomAxis, // New
    required this.colors,
  });

  @override
  State<Plot2DScreen> createState() => Plot2DScreenState();
}

class Plot2DScreenState extends State<Plot2DScreen> {
  double xMin = -5, xMax = 5;
  double yMin = -5, yMax = 5;
  double _lastScale = 1.0;
  
  // For detecting axis-specific zoom based on gesture location
  static const double _axisZoneSize = 60.0; // pixels from edge to detect axis zone

  @override
  void initState() {
    super.initState();
    _autoScaleIfNeeded();
  }

  @override
  void didUpdateWidget(covariant Plot2DScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.function != widget.function ||
        oldWidget.fieldType != widget.fieldType ||
        oldWidget.is3DFunction != widget.is3DFunction) {
      _autoScaleIfNeeded();
    }
  }

  void resetView() {
    setState(() {
      xMin = -5;
      xMax = 5;
      yMin = -5;
      yMax = 5;
    });
    _autoScaleIfNeeded();
  }

  void _autoScaleIfNeeded() {
    if (widget.fieldType != FieldType.scalar || widget.is3DFunction) {
      return;
    }
    try {
      final parser = MathParser(widget.function);
      double? minY;
      double? maxY;
      const int samples = 80;
      for (int i = 0; i <= samples; i++) {
        final t = i / samples;
        final x = xMin + (xMax - xMin) * t;
        final y = parser.evaluate(x, 0, 0);
        if (y.isNaN || y.isInfinite) continue;
        minY = minY == null ? y : (y < minY ? y : minY);
        maxY = maxY == null ? y : (y > maxY ? y : maxY);
      }
      if (minY == null || maxY == null) return;
      if ((maxY - minY).abs() < 1e-6) {
        maxY = maxY + 1;
        minY = minY - 1;
      }
      final padding = (maxY - minY) * 0.1;
      setState(() {
        yMin = minY! - padding;
        yMax = maxY! + padding;
      });
    } catch (_) {
      // Keep defaults on parse/eval failure
    }
  }

  ZoomAxis _detectZoomAxis(Offset focalPoint, Size size) {
    // If a specific axis is selected, use that
    if (widget.zoomAxis != ZoomAxis.free) {
      return widget.zoomAxis;
    }

    // Auto-detect based on gesture position
    final bool nearXAxis = focalPoint.dy > size.height - _axisZoneSize;
    final bool nearYAxis = focalPoint.dx < _axisZoneSize;

    if (nearXAxis && !nearYAxis) {
      return ZoomAxis.x;
    } else if (nearYAxis && !nearXAxis) {
      return ZoomAxis.y;
    }

    return ZoomAxis.free;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight <= 0 || constraints.maxWidth <= 0) {
          return const SizedBox.shrink();
        }
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          onScaleStart: (details) => _lastScale = 1.0,
          onScaleUpdate: (details) {
            setState(() {
              if (details.pointerCount > 1) {
                // Pinch zoom
                final scaleDelta = details.scale / _lastScale;
                _lastScale = details.scale;
                if ((scaleDelta - 1.0).abs() < 1e-3) return;

                final focalX = xMin +
                    (details.localFocalPoint.dx / constraints.maxWidth) *
                        (xMax - xMin);
                final focalY = yMax -
                    (details.localFocalPoint.dy / constraints.maxHeight) *
                        (yMax - yMin);

                // Detect which axis to zoom
                final zoomAxis = _detectZoomAxis(details.localFocalPoint, size);

                switch (zoomAxis) {
                  case ZoomAxis.x:
                    // Zoom only X axis
                    xMin = focalX - (focalX - xMin) / scaleDelta;
                    xMax = focalX + (xMax - focalX) / scaleDelta;
                    break;
                  case ZoomAxis.y:
                    // Zoom only Y axis
                    yMin = focalY - (focalY - yMin) / scaleDelta;
                    yMax = focalY + (yMax - focalY) / scaleDelta;
                    break;
                  case ZoomAxis.z:
                    // In 2D, Z is same as Y (or we can ignore)
                    yMin = focalY - (focalY - yMin) / scaleDelta;
                    yMax = focalY + (yMax - focalY) / scaleDelta;
                    break;
                  case ZoomAxis.free:
                    // Zoom both axes
                    xMin = focalX - (focalX - xMin) / scaleDelta;
                    xMax = focalX + (xMax - focalX) / scaleDelta;
                    yMin = focalY - (focalY - yMin) / scaleDelta;
                    yMax = focalY + (yMax - focalY) / scaleDelta;
                    break;
                }
              } else if (details.pointerCount == 1) {
                // Pan
                final xShift = -details.focalPointDelta.dx *
                    (xMax - xMin) /
                    constraints.maxWidth;
                final yShift = details.focalPointDelta.dy *
                    (yMax - yMin) /
                    constraints.maxHeight;
                xMin += xShift;
                xMax += xShift;
                yMin += yShift;
                yMax += yShift;
              }
            });
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: PlotThemeData.fromColors(widget.colors).background2D,
            ),
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: Plot2DPainter(
                function: widget.function,
                xMin: xMin,
                xMax: xMax,
                yMin: yMin,
                yMax: yMax,
                plotMode: widget.plotMode,
                fieldType: widget.fieldType,
                vectorParser: widget.vectorParser,
                showContour: widget.showContour,
                surfaceMode: widget.surfaceMode,
                colors: widget.colors,
              ),
            ),
          ),
        );
      },
    );
  }
}
