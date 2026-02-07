import 'dart:math';
import 'package:flutter/material.dart';
import '../models/enums.dart';
import '../../utils/app_colors.dart';
import '../parsers/vector_field_parser.dart';
import '../parsers/math_parser.dart';
import '../painters/plot_3d_painter.dart';
import '../utils/plot_theme.dart';

class Plot3DScreen extends StatefulWidget {
  final String function;
  final bool is3DFunction;
  final Tool3DMode toolMode;
  final PlotMode plotMode;
  final FieldType fieldType;
  final VectorFieldParser? vectorParser;
  final bool showContour;
  final SurfaceMode surfaceMode;
  final ZoomAxis zoomAxis; // New
  final AppColors colors;

  const Plot3DScreen({
    super.key,
    required this.function,
    required this.is3DFunction,
    required this.toolMode,
    required this.plotMode,
    required this.fieldType,
    this.vectorParser,
    required this.showContour,
    required this.surfaceMode,
    required this.zoomAxis, // New
    required this.colors,
  });

  @override
  State<Plot3DScreen> createState() => Plot3DScreenState();
}

class Plot3DScreenState extends State<Plot3DScreen> {
  double rotationX = 0.6;
  double rotationZ = 0.8;
  double xRange = 5.0;
  double yRange = 5.0;
  double zRange = 5.0; // New: separate Z range
  double panX = 0.0;
  double panY = 0.0;
  double _lastScale = 1.0;
  double _lastHorizontalScale = 1.0;
  double _lastVerticalScale = 1.0;

  void resetView() {
    setState(() {
      rotationX = 0.6;
      rotationZ = 0.8;
      xRange = 5.0;
      yRange = 5.0;
      zRange = 5.0;
      panX = 0.0;
      panY = 0.0;
    });
    _autoScaleIfNeeded();
  }

  double? _computeAutoZRange() {
    if (widget.fieldType != FieldType.scalar || !widget.is3DFunction) {
      return null;
    }
    try {
      final parser = MathParser(widget.function);
      double maxAbs = 0;
      const int samples = 6;
      for (int i = 0; i <= samples; i++) {
        final tx = i / samples;
        final x = -xRange + (2 * xRange) * tx;
        for (int j = 0; j <= samples; j++) {
          final ty = j / samples;
          final y = -yRange + (2 * yRange) * ty;
          final z = parser.evaluate(x, y, 0);
          if (!z.isFinite) continue;
          final absZ = z.abs();
          if (absZ > maxAbs) maxAbs = absZ;
        }
      }
      if (maxAbs <= 0) return null;
      return maxAbs * 1.2;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _autoScaleIfNeeded();
  }

  @override
  void didUpdateWidget(covariant Plot3DScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.function != widget.function ||
        oldWidget.fieldType != widget.fieldType) {
      _autoScaleIfNeeded();
    }
  }

  void _autoScaleIfNeeded() {
    final newZ = _computeAutoZRange();
    if (newZ == null) return;
    setState(() {
      zRange = newZ;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight <= 0 || constraints.maxWidth <= 0) {
          return const SizedBox.shrink();
        }
        return GestureDetector(
          onScaleStart: (details) {
            _lastScale = 1.0;
            _lastHorizontalScale = 1.0;
            _lastVerticalScale = 1.0;
          },
          onScaleUpdate: (details) {
            setState(() {
              if (details.pointerCount == 2) {
                if (widget.toolMode == Tool3DMode.pan) {
                  panX += details.focalPointDelta.dx;
                  panY += details.focalPointDelta.dy;
                } else {
                  // Zoom mode
                  switch (widget.zoomAxis) {
                    case ZoomAxis.free:
                      // Free zoom - use horizontal/vertical scale for X/Y
                      final hScaleDelta =
                          details.horizontalScale / _lastHorizontalScale;
                      final vScaleDelta =
                          details.verticalScale / _lastVerticalScale;
                      _lastHorizontalScale = details.horizontalScale;
                      _lastVerticalScale = details.verticalScale;

                      if ((hScaleDelta - 1.0).abs() > 0.001) {
                        xRange /= hScaleDelta;
                        xRange = xRange.clamp(1.0, 50.0);
                      }
                      if ((vScaleDelta - 1.0).abs() > 0.001) {
                        yRange /= vScaleDelta;
                        yRange = yRange.clamp(1.0, 50.0);
                      }
                        // Keep Z in sync with data when possible
                        final autoZ = _computeAutoZRange();
                        zRange = autoZ ?? ((xRange + yRange) / 2);
                        break;

                    case ZoomAxis.x:
                      // X-axis only zoom
                      final scaleDelta = details.scale / _lastScale;
                      _lastScale = details.scale;
                        if ((scaleDelta - 1.0).abs() > 0.001) {
                          xRange /= scaleDelta;
                          xRange = xRange.clamp(1.0, 50.0);
                          final autoZ = _computeAutoZRange();
                          if (autoZ != null) zRange = autoZ;
                        }
                        break;

                    case ZoomAxis.y:
                      // Y-axis only zoom
                      final scaleDelta = details.scale / _lastScale;
                      _lastScale = details.scale;
                        if ((scaleDelta - 1.0).abs() > 0.001) {
                          yRange /= scaleDelta;
                          yRange = yRange.clamp(1.0, 50.0);
                          final autoZ = _computeAutoZRange();
                          if (autoZ != null) zRange = autoZ;
                        }
                        break;

                    case ZoomAxis.z:
                      // Z-axis only zoom
                      final scaleDelta = details.scale / _lastScale;
                      _lastScale = details.scale;
                        if ((scaleDelta - 1.0).abs() > 0.001) {
                          zRange /= scaleDelta;
                          zRange = zRange.clamp(1.0, 50.0);
                        }
                        break;
                  }
                }
              } else if (details.pointerCount == 1) {
                // Single finger rotation
                rotationZ += details.focalPointDelta.dx * 0.01;
                rotationX += details.focalPointDelta.dy * 0.01;
                rotationX = rotationX.clamp(-pi / 2 + 0.1, pi / 2 - 0.1);
              }
            });
          },
          onScaleEnd: (details) {
            _lastScale = 1.0;
            _lastHorizontalScale = 1.0;
            _lastVerticalScale = 1.0;
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: PlotThemeData.fromColors(widget.colors).background3D,
            ),
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: Plot3DPainter(
                function: widget.function,
                is3DFunction: widget.is3DFunction,
                rotationX: rotationX,
                rotationZ: rotationZ,
                rangeX: xRange,
                rangeY: yRange,
                rangeZ: zRange, // New: pass separate Z range
                panX: panX,
                panY: panY,
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
