import 'dart:math';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../models/enums.dart';
import '../models/point_3d.dart';
import '../parsers/math_parser.dart';
import '../parsers/vector_field_parser.dart';
import '../utils/colormap.dart';
import '../utils/plot_theme.dart';

// Helper classes for 3D rendering
class Quad {
  final Point3D p1, p2, p3, p4;
  final double avgDepth;
  final double avgValue;

  Quad(this.p1, this.p2, this.p3, this.p4, this.avgDepth, this.avgValue);
}

class FieldPoint3D {
  final Point3D point;
  final double value;

  FieldPoint3D(this.point, this.value);
}

class Arrow3D {
  final Point3D start;
  final double dx, dy, dz;
  final double magnitude;
  final double surfaceValue;

  Arrow3D(
    this.start,
    this.dx,
    this.dy,
    this.dz,
    this.magnitude,
    this.surfaceValue,
  );
}

class Plot3DPainter extends CustomPainter {
  final String function;
  final bool is3DFunction;
  final double rotationX, rotationZ;
  final double rangeX, rangeY, rangeZ; // Changed: rangeZ is now a parameter
  final double panX, panY;
  final PlotMode plotMode;
  final FieldType fieldType;
  final VectorFieldParser? vectorParser;
  final bool showContour;
  final SurfaceMode surfaceMode;
  final AppColors colors;

  Plot3DPainter({
    required this.function,
    required this.is3DFunction,
    required this.rotationX,
    required this.rotationZ,
    required this.rangeX,
    required this.rangeY,
    required this.rangeZ, // New: explicit rangeZ parameter
    required this.panX,
    required this.panY,
    required this.plotMode,
    required this.fieldType,
    this.vectorParser,
    required this.showContour,
    required this.surfaceMode,
    required this.colors,
  });

  // Remove the getter since rangeZ is now a parameter
  // double get rangeZ => (rangeX + rangeY) / 2;

  // double get rangeZ => (rangeX + rangeY) / 2;
  double get scaleX => 200.0 / rangeX;
  double get scaleY => 200.0 / rangeY;
  double get scaleZ => 200.0 / rangeZ;
  PlotThemeData get _theme => PlotThemeData.fromColors(colors);

  @override
  void paint(Canvas canvas, Size size) {
    const focalLength = 500.0;
    final bool showSurface = surfaceMode != SurfaceMode.none;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    _drawFloorGrid(canvas, size, focalLength);
    _drawAxes(canvas, size, focalLength);
    _drawFloorBoundary(canvas, size, focalLength);

    // Handle different visualization modes
    if (fieldType == FieldType.vector && vectorParser != null) {
      // Vector field visualization
      if (showSurface && !vectorParser!.is3D) {
        // Show magnitude surface for 2D vector fields
        if (surfaceMode == SurfaceMode.magnitude) {
          _drawVectorMagnitudeSurface3D(canvas, size, focalLength);
        } else {
          _drawVectorComponentSurface3D(canvas, size, focalLength, surfaceMode);
        }

        // Draw contours on the magnitude surface if enabled
        if (showContour) {
          if (surfaceMode == SurfaceMode.magnitude) {
            _drawVectorMagnitudeContours3D(canvas, size, focalLength);
          } else {
            _drawVectorComponentContours3D(
              canvas,
              size,
              focalLength,
              surfaceMode,
            );
          }
        }

        // Optionally draw vectors on top
        if (plotMode == PlotMode.function) {
          _drawVectorField3D(canvas, size, focalLength);
        }
      } else {
        // Default vector field visualization
        if (plotMode == PlotMode.field) {
          _drawVectorMagnitudeField3D(canvas, size, focalLength);
        } else {
          _drawVectorField3D(canvas, size, focalLength);
        }
      }
    } else {
      // Scalar field visualization
      if (is3DFunction) {
        if (showSurface) {
          // Show surface with jet colormap (magnitude coloring)
          _drawSurfaceWithJetColormap(canvas, size, focalLength);

          // Draw contours on the surface if enabled
          if (showContour) {
            _drawSurfaceContours(canvas, size, focalLength);
          }
        } else {
          // Default visualization
          if (plotMode == PlotMode.field) {
            _drawScalarField3D(canvas, size, focalLength);
          } else {
            _drawSurface(canvas, size, focalLength);
          }

          // Draw contours if enabled
          if (showContour) {
            if (plotMode == PlotMode.field) {
              _drawContourLines3D(canvas, size, focalLength);
            } else {
              _drawSurfaceContours(canvas, size, focalLength);
            }
          }
        }
      } else {
        // 1D function (f(x) only)
        _drawStandingCurve(canvas, size, focalLength);
      }
    }

    canvas.restore();
  }

  void _drawSurfaceWithJetColormap(
    Canvas canvas,
    Size size,
    double focalLength,
  ) {
    const gridSize = 50;
    final parser = MathParser(function);

    List<List<Point3D?>> points = [];
    List<List<double>> zValues = [];

    double minZ = double.infinity;
    double maxZ = double.negativeInfinity;

    // First pass: compute all z values and find min/max
    for (int i = 0; i <= gridSize; i++) {
      List<Point3D?> row = [];
      List<double> zRow = [];
      for (int j = 0; j <= gridSize; j++) {
        final x = -rangeX + (2 * rangeX * i / gridSize);
        final y = -rangeY + (2 * rangeY * j / gridSize);
        double z;
        try {
          z = parser.evaluate(x, y);
          if (!z.isFinite) {
            row.add(null);
            zRow.add(double.nan);
            continue;
          }
          if (z < -rangeZ || z > rangeZ) {
            row.add(null);
            zRow.add(z);
            continue;
          }
        } catch (e) {
          row.add(null);
          zRow.add(double.nan);
          continue;
        }

        minZ = min(minZ, z);
        maxZ = max(maxZ, z);

        row.add(
          Point3D(
            x * scaleX,
            y * scaleY,
            z * scaleZ,
          ).rotateX(rotationX).rotateZ(rotationZ),
        );
        zRow.add(z);
      }
      points.add(row);
      zValues.add(zRow);
    }

    if (minZ == maxZ) maxZ = minZ + 1;

    // Build quads
    List<Quad> quads = [];
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final p1 = points[i][j];
        final p2 = points[i + 1][j];
        final p3 = points[i + 1][j + 1];
        final p4 = points[i][j + 1];

        if (p1 == null || p2 == null || p3 == null || p4 == null) continue;

        final avgY = (p1.y + p2.y + p3.y + p4.y) / 4;
        final avgValue =
            (zValues[i][j] +
                zValues[i + 1][j] +
                zValues[i + 1][j + 1] +
                zValues[i][j + 1]) /
            4;
        quads.add(Quad(p1, p2, p3, p4, avgY, avgValue));
      }
    }

    // Sort by depth (painter's algorithm)
    quads.sort((a, b) => b.avgDepth.compareTo(a.avgDepth));

    // Draw quads with jet colormap
    for (final quad in quads) {
      final o1 = quad.p1.project(focalLength, size, panX, panY);
      final o2 = quad.p2.project(focalLength, size, panX, panY);
      final o3 = quad.p3.project(focalLength, size, panX, panY);
      final o4 = quad.p4.project(focalLength, size, panX, panY);

      // Use jet colormap based on z value
      final normalizedValue = (quad.avgValue - minZ) / (maxZ - minZ);
      final color = jetColormap(normalizedValue.clamp(0.0, 1.0));

      final path =
          Path()
            ..moveTo(o1.dx, o1.dy)
            ..lineTo(o2.dx, o2.dy)
            ..lineTo(o3.dx, o3.dy)
            ..lineTo(o4.dx, o4.dy)
            ..close();

      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = _theme.wireframe
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
    }

    // Draw colorbar
    _drawColorbar3D(canvas, size, minZ, maxZ);
  }

  void _drawVectorMagnitudeSurface3D(
    Canvas canvas,
    Size size,
    double focalLength,
  ) {
    if (vectorParser == null || vectorParser!.is3D) return;

    const gridSize = 50;

    List<List<Point3D?>> points = [];
    List<List<double>> magValues = [];
    List<List<bool>> validMag = [];

    double maxMag = 0;
    double maxSurfaceAbs = 0;

    // First pass: compute magnitudes and find max
    for (int i = 0; i <= gridSize; i++) {
      List<Point3D?> row = [];
      List<double> magRow = [];
      List<bool> validRow = [];
      for (int j = 0; j <= gridSize; j++) {
        final x = -rangeX + (2 * rangeX * i / gridSize);
        final y = -rangeY + (2 * rangeY * j / gridSize);

        final mag = vectorParser!.magnitude(x, y);

        if (!mag.isFinite) {
          row.add(null);
          magRow.add(0);
          validRow.add(false);
          continue;
        }

        maxMag = max(maxMag, mag);
        magRow.add(mag);
        row.add(null);
        validRow.add(true);
      }
      points.add(row);
      magValues.add(magRow);
      validMag.add(validRow);
    }

    if (maxMag == 0) maxMag = 1;

    // Scale factor to make surface height reasonable
    final zScale = rangeZ / maxMag;

    // Second pass: create 3D points
    for (int i = 0; i <= gridSize; i++) {
      for (int j = 0; j <= gridSize; j++) {
        final x = -rangeX + (2 * rangeX * i / gridSize);
        final y = -rangeY + (2 * rangeY * j / gridSize);
        final mag = magValues[i][j];
        if (!validMag[i][j]) continue;

        final z = mag * zScale;
        if (z < -rangeZ || z > rangeZ) {
          points[i][j] = null;
          continue;
        }

        points[i][j] = Point3D(
          x * scaleX,
          y * scaleY,
          z * scaleZ,
        ).rotateX(rotationX).rotateZ(rotationZ);
      }
    }

    // Build quads for painter's algorithm
    List<Quad> quads = [];
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final p1 = points[i][j];
        final p2 = points[i + 1][j];
        final p3 = points[i + 1][j + 1];
        final p4 = points[i][j + 1];

        if (p1 == null || p2 == null || p3 == null || p4 == null) continue;

        final avgY = (p1.y + p2.y + p3.y + p4.y) / 4;
        final avgValue =
            (magValues[i][j] +
                magValues[i + 1][j] +
                magValues[i + 1][j + 1] +
                magValues[i][j + 1]) /
            4;
        quads.add(Quad(p1, p2, p3, p4, avgY, avgValue));
      }
    }

    // Sort by depth (painter's algorithm)
    quads.sort((a, b) => b.avgDepth.compareTo(a.avgDepth));

    // Draw quads
    for (final quad in quads) {
      final o1 = quad.p1.project(focalLength, size, panX, panY);
      final o2 = quad.p2.project(focalLength, size, panX, panY);
      final o3 = quad.p3.project(focalLength, size, panX, panY);
      final o4 = quad.p4.project(focalLength, size, panX, panY);

      final normalizedValue = quad.avgValue / maxMag;
      final color = jetColormap(normalizedValue.clamp(0.0, 1.0));

      final path =
          Path()
            ..moveTo(o1.dx, o1.dy)
            ..lineTo(o2.dx, o2.dy)
            ..lineTo(o3.dx, o3.dy)
            ..lineTo(o4.dx, o4.dy)
            ..close();

      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = _theme.wireframe
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
    }

    _drawColorbar3D(canvas, size, 0, maxMag);
  }

  void _drawVectorComponentSurface3D(
    Canvas canvas,
    Size size,
    double focalLength,
    SurfaceMode mode,
  ) {
    if (vectorParser == null || vectorParser!.is3D) return;

    const gridSize = 50;

    List<List<Point3D?>> points = [];
    List<List<double>> values = [];

    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;
    double maxAbs = 0;

    for (int i = 0; i <= gridSize; i++) {
      List<Point3D?> row = [];
      List<double> valRow = [];
      for (int j = 0; j <= gridSize; j++) {
        final x = -rangeX + (2 * rangeX * i / gridSize);
        final y = -rangeY + (2 * rangeY * j / gridSize);

        final val = vectorParser!.componentValue(mode, x, y);
        if (!val.isFinite) {
          row.add(null);
          valRow.add(double.nan);
          continue;
        }

        minVal = min(minVal, val);
        maxVal = max(maxVal, val);
        maxAbs = max(maxAbs, val.abs());
        valRow.add(val);
        row.add(null);
      }
      points.add(row);
      values.add(valRow);
    }

    if (maxAbs == 0 || !minVal.isFinite || !maxVal.isFinite) return;

    final zScale = rangeZ / maxAbs;

    for (int i = 0; i <= gridSize; i++) {
      for (int j = 0; j <= gridSize; j++) {
        final x = -rangeX + (2 * rangeX * i / gridSize);
        final y = -rangeY + (2 * rangeY * j / gridSize);
        final val = values[i][j];
        if (!val.isFinite) continue;

        final z = val * zScale;
        if (z < -rangeZ || z > rangeZ) {
          points[i][j] = null;
          continue;
        }

        points[i][j] = Point3D(
          x * scaleX,
          y * scaleY,
          z * scaleZ,
        ).rotateX(rotationX).rotateZ(rotationZ);
      }
    }

    List<Quad> quads = [];
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final p1 = points[i][j];
        final p2 = points[i + 1][j];
        final p3 = points[i + 1][j + 1];
        final p4 = points[i][j + 1];

        if (p1 == null || p2 == null || p3 == null || p4 == null) continue;

        final avgY = (p1.y + p2.y + p3.y + p4.y) / 4;
        final avgValue =
            (values[i][j] +
                values[i + 1][j] +
                values[i + 1][j + 1] +
                values[i][j + 1]) /
            4;
        quads.add(Quad(p1, p2, p3, p4, avgY, avgValue));
      }
    }

    quads.sort((a, b) => b.avgDepth.compareTo(a.avgDepth));

    for (final quad in quads) {
      final o1 = quad.p1.project(focalLength, size, panX, panY);
      final o2 = quad.p2.project(focalLength, size, panX, panY);
      final o3 = quad.p3.project(focalLength, size, panX, panY);
      final o4 = quad.p4.project(focalLength, size, panX, panY);

      final normalizedValue =
          (quad.avgValue - minVal) / (maxVal - minVal);
      final color = jetColormap(normalizedValue.clamp(0.0, 1.0));

      final path =
          Path()
            ..moveTo(o1.dx, o1.dy)
            ..lineTo(o2.dx, o2.dy)
            ..lineTo(o3.dx, o3.dy)
            ..lineTo(o4.dx, o4.dy)
            ..close();

      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = _theme.wireframe
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
    }

    _drawColorbar3D(canvas, size, minVal, maxVal);
  }

  void _drawVectorMagnitudeContours3D(
    Canvas canvas,
    Size size,
    double focalLength,
  ) {
    if (vectorParser == null || vectorParser!.is3D) return;

    const gridSize = 60;
    const numContours = 12;

    // Build grid of magnitude values
    List<List<double>> grid = [];
    double maxMag = 0;

    for (int i = 0; i <= gridSize; i++) {
      List<double> row = [];
      for (int j = 0; j <= gridSize; j++) {
        final x = -rangeX + (2 * rangeX * i / gridSize);
        final y = -rangeY + (2 * rangeY * j / gridSize);
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

    final zScale = rangeZ / maxMag;

    // Draw contour lines on the surface
    for (int level = 0; level < numContours; level++) {
      final threshold = maxMag * (level + 1) / (numContours + 1);
      final normalizedLevel = threshold / maxMag;
      final color = jetColormap(normalizedLevel);

      final paint =
          Paint()
            ..color = color
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke;

      _drawVectorMagnitudeContourLevel3D(
        canvas,
        size,
        focalLength,
        grid,
        threshold,
        paint,
        zScale,
      );
    }
  }

  void _drawVectorComponentContours3D(
    Canvas canvas,
    Size size,
    double focalLength,
    SurfaceMode mode,
  ) {
    if (vectorParser == null || vectorParser!.is3D) return;

    const gridSize = 60;
    const numContours = 12;

    List<List<double>> grid = [];
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;
    double maxAbs = 0;

    for (int i = 0; i <= gridSize; i++) {
      List<double> row = [];
      for (int j = 0; j <= gridSize; j++) {
        final x = -rangeX + (2 * rangeX * i / gridSize);
        final y = -rangeY + (2 * rangeY * j / gridSize);
        final val = vectorParser!.componentValue(mode, x, y);
        if (val.isFinite) {
          row.add(val);
          minVal = min(minVal, val);
          maxVal = max(maxVal, val);
          maxAbs = max(maxAbs, val.abs());
        } else {
          row.add(0);
        }
      }
      grid.add(row);
    }

    if (minVal == maxVal || maxAbs == 0) return;

    final zScale = rangeZ / maxAbs;

    for (int level = 0; level < numContours; level++) {
      final threshold =
          minVal + (maxVal - minVal) * (level + 1) / (numContours + 1);
      final normalizedLevel = (threshold - minVal) / (maxVal - minVal);
      final color = jetColormap(normalizedLevel);

      final paint =
          Paint()
            ..color = color
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke;

      _drawVectorComponentContourLevel3D(
        canvas,
        size,
        focalLength,
        grid,
        threshold,
        paint,
        zScale,
      );
    }
  }

  void _drawVectorComponentContourLevel3D(
    Canvas canvas,
    Size size,
    double focalLength,
    List<List<double>> grid,
    double threshold,
    Paint paint,
    double zScale,
  ) {
    final gridSize = grid.length - 1;

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final v0 = grid[i][j];
        final v1 = grid[i + 1][j];
        final v2 = grid[i + 1][j + 1];
        final v3 = grid[i][j + 1];

        int caseIndex = 0;
        if (v0 >= threshold) caseIndex |= 1;
        if (v1 >= threshold) caseIndex |= 2;
        if (v2 >= threshold) caseIndex |= 4;
        if (v3 >= threshold) caseIndex |= 8;

        if (caseIndex == 0 || caseIndex == 15) continue;

        final x0 = -rangeX + (2 * rangeX * i / gridSize);
        final x1 = -rangeX + (2 * rangeX * (i + 1) / gridSize);
        final y0 = -rangeY + (2 * rangeY * j / gridSize);
        final y1 = -rangeY + (2 * rangeY * (j + 1) / gridSize);

        final pz = threshold * zScale;

        List<Point3D> points3D = [];

        if ((v0 >= threshold) != (v1 >= threshold)) {
          final t = (threshold - v0) / (v1 - v0);
          final px = x0 + t * (x1 - x0);
          points3D.add(Point3D(px * scaleX, y0 * scaleY, pz * scaleZ));
        }
        if ((v1 >= threshold) != (v2 >= threshold)) {
          final t = (threshold - v1) / (v2 - v1);
          final py = y0 + t * (y1 - y0);
          points3D.add(Point3D(x1 * scaleX, py * scaleY, pz * scaleZ));
        }
        if ((v2 >= threshold) != (v3 >= threshold)) {
          final t = (threshold - v3) / (v2 - v3);
          final px = x0 + t * (x1 - x0);
          points3D.add(Point3D(px * scaleX, y1 * scaleY, pz * scaleZ));
        }
        if ((v3 >= threshold) != (v0 >= threshold)) {
          final t = (threshold - v0) / (v3 - v0);
          final py = y0 + t * (y1 - y0);
          points3D.add(Point3D(x0 * scaleX, py * scaleY, pz * scaleZ));
        }

        if (points3D.length >= 2) {
          final p1 = points3D[0].rotateX(rotationX).rotateZ(rotationZ);
          final p2 = points3D[1].rotateX(rotationX).rotateZ(rotationZ);
          final proj1 = p1.project(focalLength, size, panX, panY);
          final proj2 = p2.project(focalLength, size, panX, panY);
          canvas.drawLine(proj1, proj2, paint);
        }
        if (points3D.length >= 4) {
          final p3 = points3D[2].rotateX(rotationX).rotateZ(rotationZ);
          final p4 = points3D[3].rotateX(rotationX).rotateZ(rotationZ);
          final proj3 = p3.project(focalLength, size, panX, panY);
          final proj4 = p4.project(focalLength, size, panX, panY);
          canvas.drawLine(proj3, proj4, paint);
        }
      }
    }
  }

  void _drawVectorMagnitudeContourLevel3D(
    Canvas canvas,
    Size size,
    double focalLength,
    List<List<double>> grid,
    double threshold,
    Paint paint,
    double zScale,
  ) {
    final gridSize = grid.length - 1;

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final v0 = grid[i][j];
        final v1 = grid[i + 1][j];
        final v2 = grid[i + 1][j + 1];
        final v3 = grid[i][j + 1];

        if (v0 == 0 || v1 == 0 || v2 == 0 || v3 == 0) continue;

        int caseIndex = 0;
        if (v0 >= threshold) caseIndex |= 1;
        if (v1 >= threshold) caseIndex |= 2;
        if (v2 >= threshold) caseIndex |= 4;
        if (v3 >= threshold) caseIndex |= 8;

        if (caseIndex == 0 || caseIndex == 15) continue;

        final x0 = -rangeX + (2 * rangeX * i / gridSize);
        final x1 = -rangeX + (2 * rangeX * (i + 1) / gridSize);
        final y0 = -rangeY + (2 * rangeY * j / gridSize);
        final y1 = -rangeY + (2 * rangeY * (j + 1) / gridSize);

        final pz = threshold * zScale;

        List<Point3D> points3D = [];

        if ((v0 >= threshold) != (v1 >= threshold)) {
          final t = (threshold - v0) / (v1 - v0);
          final px = x0 + t * (x1 - x0);
          points3D.add(Point3D(px * scaleX, y0 * scaleY, pz * scaleZ));
        }
        if ((v1 >= threshold) != (v2 >= threshold)) {
          final t = (threshold - v1) / (v2 - v1);
          final py = y0 + t * (y1 - y0);
          points3D.add(Point3D(x1 * scaleX, py * scaleY, pz * scaleZ));
        }
        if ((v2 >= threshold) != (v3 >= threshold)) {
          final t = (threshold - v3) / (v2 - v3);
          final px = x0 + t * (x1 - x0);
          points3D.add(Point3D(px * scaleX, y1 * scaleY, pz * scaleZ));
        }
        if ((v3 >= threshold) != (v0 >= threshold)) {
          final t = (threshold - v0) / (v3 - v0);
          final py = y0 + t * (y1 - y0);
          points3D.add(Point3D(x0 * scaleX, py * scaleY, pz * scaleZ));
        }

        if (points3D.length >= 2) {
          final p1 = points3D[0].rotateX(rotationX).rotateZ(rotationZ);
          final p2 = points3D[1].rotateX(rotationX).rotateZ(rotationZ);
          final proj1 = p1.project(focalLength, size, panX, panY);
          final proj2 = p2.project(focalLength, size, panX, panY);
          canvas.drawLine(proj1, proj2, paint);
        }
        if (points3D.length >= 4) {
          final p3 = points3D[2].rotateX(rotationX).rotateZ(rotationZ);
          final p4 = points3D[3].rotateX(rotationX).rotateZ(rotationZ);
          final proj3 = p3.project(focalLength, size, panX, panY);
          final proj4 = p4.project(focalLength, size, panX, panY);
          canvas.drawLine(proj3, proj4, paint);
        }
      }
    }
  }

  void _drawContourLines3D(Canvas canvas, Size size, double focalLength) {
    final parser = MathParser(function);
    const gridSize = 60;
    const numContours = 12;

    List<List<double>> grid = [];
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;

    for (int i = 0; i <= gridSize; i++) {
      List<double> row = [];
      for (int j = 0; j <= gridSize; j++) {
        final x = -rangeX + (2 * rangeX * i / gridSize);
        final y = -rangeY + (2 * rangeY * j / gridSize);
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

    for (int level = 0; level < numContours; level++) {
      final threshold =
          minVal + (maxVal - minVal) * (level + 1) / (numContours + 1);
      final normalizedLevel = (threshold - minVal) / (maxVal - minVal);
      final color = jetColormap(normalizedLevel);

      final paint =
          Paint()
            ..color = color.withValues(alpha: 0.8)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke;

      _drawContourLevel3D(
        canvas,
        size,
        focalLength,
        grid,
        threshold,
        paint,
        onFloor: true,
      );
    }
  }

  void _drawSurfaceContours(Canvas canvas, Size size, double focalLength) {
    final parser = MathParser(function);
    const gridSize = 60;
    const numContours = 10;

    List<List<double>> grid = [];
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;

    for (int i = 0; i <= gridSize; i++) {
      List<double> row = [];
      for (int j = 0; j <= gridSize; j++) {
        final x = -rangeX + (2 * rangeX * i / gridSize);
        final y = -rangeY + (2 * rangeY * j / gridSize);
        double val;
        try {
          val = parser.evaluate(x, y);
          if (!val.isFinite || val < -rangeZ || val > rangeZ) {
            val = double.nan;
          }
        } catch (e) {
          val = double.nan;
        }
        row.add(val);
        if (val.isFinite) {
          minVal = min(minVal, val);
          maxVal = max(maxVal, val);
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
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke;

      _drawContourLevel3D(
        canvas,
        size,
        focalLength,
        grid,
        threshold,
        paint,
        onFloor: false,
      );
    }
  }

  void _drawContourLevel3D(
    Canvas canvas,
    Size size,
    double focalLength,
    List<List<double>> grid,
    double threshold,
    Paint paint, {
    required bool onFloor,
  }) {
    final gridSize = grid.length - 1;

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final v0 = grid[i][j];
        final v1 = grid[i + 1][j];
        final v2 = grid[i + 1][j + 1];
        final v3 = grid[i][j + 1];

        if (!v0.isFinite || !v1.isFinite || !v2.isFinite || !v3.isFinite) {
          continue;
        }

        int caseIndex = 0;
        if (v0 >= threshold) caseIndex |= 1;
        if (v1 >= threshold) caseIndex |= 2;
        if (v2 >= threshold) caseIndex |= 4;
        if (v3 >= threshold) caseIndex |= 8;

        if (caseIndex == 0 || caseIndex == 15) continue;

        final x0 = -rangeX + (2 * rangeX * i / gridSize);
        final x1 = -rangeX + (2 * rangeX * (i + 1) / gridSize);
        final y0 = -rangeY + (2 * rangeY * j / gridSize);
        final y1 = -rangeY + (2 * rangeY * (j + 1) / gridSize);

        List<Point3D> points3D = [];

        if ((v0 >= threshold) != (v1 >= threshold)) {
          final t = (threshold - v0) / (v1 - v0);
          final px = x0 + t * (x1 - x0);
          final pz = onFloor ? 0.0 : threshold;
          points3D.add(Point3D(px * scaleX, y0 * scaleY, pz * scaleZ));
        }
        if ((v1 >= threshold) != (v2 >= threshold)) {
          final t = (threshold - v1) / (v2 - v1);
          final py = y0 + t * (y1 - y0);
          final pz = onFloor ? 0.0 : threshold;
          points3D.add(Point3D(x1 * scaleX, py * scaleY, pz * scaleZ));
        }
        if ((v2 >= threshold) != (v3 >= threshold)) {
          final t = (threshold - v3) / (v2 - v3);
          final px = x0 + t * (x1 - x0);
          final pz = onFloor ? 0.0 : threshold;
          points3D.add(Point3D(px * scaleX, y1 * scaleY, pz * scaleZ));
        }
        if ((v3 >= threshold) != (v0 >= threshold)) {
          final t = (threshold - v0) / (v3 - v0);
          final py = y0 + t * (y1 - y0);
          final pz = onFloor ? 0.0 : threshold;
          points3D.add(Point3D(x0 * scaleX, py * scaleY, pz * scaleZ));
        }

        if (points3D.length >= 2) {
          final p1 = points3D[0].rotateX(rotationX).rotateZ(rotationZ);
          final p2 = points3D[1].rotateX(rotationX).rotateZ(rotationZ);
          final proj1 = p1.project(focalLength, size, panX, panY);
          final proj2 = p2.project(focalLength, size, panX, panY);
          canvas.drawLine(proj1, proj2, paint);
        }
        if (points3D.length >= 4) {
          final p3 = points3D[2].rotateX(rotationX).rotateZ(rotationZ);
          final p4 = points3D[3].rotateX(rotationX).rotateZ(rotationZ);
          final proj3 = p3.project(focalLength, size, panX, panY);
          final proj4 = p4.project(focalLength, size, panX, panY);
          canvas.drawLine(proj3, proj4, paint);
        }
      }
    }
  }

  double _calculateGridSpacing(double range) {
    final magnitude = pow(10, (log(range * 2) / ln10).floor()).toDouble();
    final normalized = (range * 2) / magnitude;
    if (normalized < 2) return magnitude / 5;
    if (normalized < 5) return magnitude / 2;
    return magnitude;
  }

  void _drawFloorGrid(Canvas canvas, Size size, double focalLength) {
    final theme = PlotThemeData.fromColors(colors);
    final gridPaint =
        Paint()
          ..color = theme.grid
          ..strokeWidth = 1.2;
    final subGridPaint =
        Paint()
          ..color = theme.subGrid
          ..strokeWidth = 0.8;

    final gridSpacingX = _calculateGridSpacing(rangeX);
    final gridSpacingY = _calculateGridSpacing(rangeY);

    for (double i = -rangeX; i <= rangeX; i += gridSpacingX / 5) {
      var start = Point3D(
        i * scaleX,
        -rangeY * scaleY,
        0,
      ).rotateX(rotationX).rotateZ(rotationZ);
      var end = Point3D(
        i * scaleX,
        rangeY * scaleY,
        0,
      ).rotateX(rotationX).rotateZ(rotationZ);
      _drawClippedLine(canvas, size, focalLength, start, end, subGridPaint);
    }
    for (double i = -rangeY; i <= rangeY; i += gridSpacingY / 5) {
      var start = Point3D(
        -rangeX * scaleX,
        i * scaleY,
        0,
      ).rotateX(rotationX).rotateZ(rotationZ);
      var end = Point3D(
        rangeX * scaleX,
        i * scaleY,
        0,
      ).rotateX(rotationX).rotateZ(rotationZ);
      _drawClippedLine(canvas, size, focalLength, start, end, subGridPaint);
    }
    for (double i = -rangeX; i <= rangeX; i += gridSpacingX) {
      var start = Point3D(
        i * scaleX,
        -rangeY * scaleY,
        0,
      ).rotateX(rotationX).rotateZ(rotationZ);
      var end = Point3D(
        i * scaleX,
        rangeY * scaleY,
        0,
      ).rotateX(rotationX).rotateZ(rotationZ);
      _drawClippedLine(canvas, size, focalLength, start, end, gridPaint);
    }
    for (double i = -rangeY; i <= rangeY; i += gridSpacingY) {
      var start = Point3D(
        -rangeX * scaleX,
        i * scaleY,
        0,
      ).rotateX(rotationX).rotateZ(rotationZ);
      var end = Point3D(
        rangeX * scaleX,
        i * scaleY,
        0,
      ).rotateX(rotationX).rotateZ(rotationZ);
      _drawClippedLine(canvas, size, focalLength, start, end, gridPaint);
    }
  }

  void _drawFloorBoundary(Canvas canvas, Size size, double focalLength) {
    final theme = PlotThemeData.fromColors(colors);
    final boundaryPaint =
        Paint()
          ..color = theme.boundary
          ..strokeWidth = 2;

    final corners = [
      Point3D(-rangeX * scaleX, -rangeY * scaleY, 0),
      Point3D(rangeX * scaleX, -rangeY * scaleY, 0),
      Point3D(rangeX * scaleX, rangeY * scaleY, 0),
      Point3D(-rangeX * scaleX, rangeY * scaleY, 0),
    ];

    for (int i = 0; i < 4; i++) {
      final start = corners[i].rotateX(rotationX).rotateZ(rotationZ);
      final end = corners[(i + 1) % 4].rotateX(rotationX).rotateZ(rotationZ);
      _drawClippedLine(canvas, size, focalLength, start, end, boundaryPaint);
    }
  }

  void _drawClippedLine(
    Canvas canvas,
    Size size,
    double focalLength,
    Point3D start,
    Point3D end,
    Paint paint,
  ) {
    final startProj = start.project(focalLength, size, panX, panY);
    final endProj = end.project(focalLength, size, panX, panY);
    final clipped = _clipLineToRect(
      startProj,
      endProj,
      Rect.fromLTWH(0, 0, size.width, size.height),
    );
    if (clipped != null) canvas.drawLine(clipped.$1, clipped.$2, paint);
  }

  void _drawAxes(Canvas canvas, Size size, double focalLength) {
    final theme = PlotThemeData.fromColors(colors);
    final gridSpacingX = _calculateGridSpacing(rangeX);
    final gridSpacingY = _calculateGridSpacing(rangeY);
    final gridSpacingZ = _calculateGridSpacing(rangeZ);

    final axes = [
      (theme.axisX, 'X', Point3D(1, 0, 0), gridSpacingX, rangeX, scaleX),
      (theme.axisY, 'Y', Point3D(0, 1, 0), gridSpacingY, rangeY, scaleY),
      (theme.axisZ, 'Z', Point3D(0, 0, 1), gridSpacingZ, rangeZ, scaleZ),
    ];

    for (final axis in axes) {
      final color = axis.$1;
      final label = axis.$2;
      final dir = axis.$3;
      final gridSpacing = axis.$4;
      final range = axis.$5;
      final scale = axis.$6;

      final axisPaint =
          Paint()
            ..color = color.withValues(alpha: 0.8)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round;
      final axisGlowPaint =
          Paint()
            ..color = color.withValues(alpha: 0.35)
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      final negPoint = Point3D(
        -dir.x * range * 2 * scale,
        -dir.y * range * 2 * scale,
        -dir.z * range * 2 * scale,
      ).rotateX(rotationX).rotateZ(rotationZ);
      final posPoint = Point3D(
        dir.x * range * 2 * scale,
        dir.y * range * 2 * scale,
        dir.z * range * 2 * scale,
      ).rotateX(rotationX).rotateZ(rotationZ);

        _drawClippedLine(
          canvas,
          size,
          focalLength,
          negPoint,
          posPoint,
          axisGlowPaint,
        );
        _drawClippedLine(
          canvas,
          size,
          focalLength,
          negPoint,
          posPoint,
          axisPaint,
        );

      final arrowPos = Point3D(
        dir.x * range * 0.9 * scale,
        dir.y * range * 0.9 * scale,
        dir.z * range * 0.9 * scale,
      ).rotateX(rotationX).rotateZ(rotationZ);
      final arrowProj = arrowPos.project(focalLength, size, panX, panY);

      if (_isPointInRect(
        arrowProj,
        Rect.fromLTWH(-20, -20, size.width + 40, size.height + 40),
      )) {
        final origin = const Point3D(
          0,
          0,
          0,
        ).rotateX(rotationX).rotateZ(rotationZ);
        final originProj = origin.project(focalLength, size, panX, panY);
        final direction = Offset(
          arrowProj.dx - originProj.dx,
          arrowProj.dy - originProj.dy,
        );
        final length = direction.distance;

        if (length > 0) {
          final normalized = direction / length;
          final perpendicular = Offset(-normalized.dy, normalized.dx);
          const arrowSize = 10.0;
          canvas.drawPath(
            Path()
              ..moveTo(
                arrowProj.dx -
                    normalized.dx * arrowSize +
                    perpendicular.dx * arrowSize / 2,
                arrowProj.dy -
                    normalized.dy * arrowSize +
                    perpendicular.dy * arrowSize / 2,
              )
              ..lineTo(arrowProj.dx, arrowProj.dy)
              ..lineTo(
                arrowProj.dx -
                    normalized.dx * arrowSize -
                    perpendicular.dx * arrowSize / 2,
                arrowProj.dy -
                    normalized.dy * arrowSize -
                    perpendicular.dy * arrowSize / 2,
              ),
            axisPaint..style = PaintingStyle.stroke,
          );
        }

        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(arrowProj.dx + 8, arrowProj.dy - 8));
      }

        final tickPaint =
            Paint()
              ..color = theme.tick
              ..strokeWidth = 1;

      for (double t = -range; t <= range; t += gridSpacing) {
        if (t.abs() < gridSpacing * 0.1) continue;

        final tickPos = Point3D(
          dir.x * t * scale,
          dir.y * t * scale,
          dir.z * t * scale,
        ).rotateX(rotationX).rotateZ(rotationZ);
        final tickProj = tickPos.project(focalLength, size, panX, panY);

        if (!_isPointInRect(
          tickProj,
          Rect.fromLTWH(0, 0, size.width, size.height),
        )) {
          continue;
        }

        const tickLen = 5.0;
        Point3D tick1End, tick2End;

        if (label == 'X') {
          tick1End = Point3D(
            t * scale,
            tickLen,
            0,
          ).rotateX(rotationX).rotateZ(rotationZ);
          tick2End = Point3D(
            t * scale,
            0,
            tickLen,
          ).rotateX(rotationX).rotateZ(rotationZ);
        } else if (label == 'Y') {
          tick1End = Point3D(
            tickLen,
            t * scale,
            0,
          ).rotateX(rotationX).rotateZ(rotationZ);
          tick2End = Point3D(
            0,
            t * scale,
            tickLen,
          ).rotateX(rotationX).rotateZ(rotationZ);
        } else {
          tick1End = Point3D(
            tickLen,
            0,
            t * scale,
          ).rotateX(rotationX).rotateZ(rotationZ);
          tick2End = Point3D(
            0,
            tickLen,
            t * scale,
          ).rotateX(rotationX).rotateZ(rotationZ);
        }

        canvas.drawLine(
          tickProj,
          tick1End.project(focalLength, size, panX, panY),
          tickPaint,
        );
        canvas.drawLine(
          tickProj,
          tick2End.project(focalLength, size, panX, panY),
          tickPaint,
        );

        Point3D labelPos;
        if (label == 'X') {
          labelPos = Point3D(
            t * scale,
            -15,
            -10,
          ).rotateX(rotationX).rotateZ(rotationZ);
        } else if (label == 'Y') {
          labelPos = Point3D(
            -15,
            t * scale,
            -10,
          ).rotateX(rotationX).rotateZ(rotationZ);
        } else {
          labelPos = Point3D(
            -15,
            -15,
            t * scale,
          ).rotateX(rotationX).rotateZ(rotationZ);
        }

        final labelProj = labelPos.project(focalLength, size, panX, panY);
        if (_isPointInRect(
          labelProj,
          Rect.fromLTWH(0, 0, size.width, size.height),
        )) {
            final ltp = TextPainter(
              text: TextSpan(
                text: _formatNumber(t),
                style: TextStyle(
                  color: theme.label,
                  fontSize: 10,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
          ltp.paint(
            canvas,
            Offset(labelProj.dx - ltp.width / 2, labelProj.dy - ltp.height / 2),
          );
        }
      }
    }
  }

  String _formatNumber(double n) {
    if (n.abs() < 0.001) return '0';
    if (n == n.roundToDouble() && n.abs() < 1000) return n.toInt().toString();
    if (n.abs() >= 100) return n.toInt().toString();
    if (n.abs() >= 10) return n.toStringAsFixed(1);
    return n.toStringAsFixed(2);
  }

  (Offset, Offset)? _clipLineToRect(Offset p1, Offset p2, Rect rect) {
    double x1 = p1.dx, y1 = p1.dy, x2 = p2.dx, y2 = p2.dy;
    const inside = 0, left = 1, right = 2, bottom = 4, top = 8;

    int computeCode(double x, double y) {
      int code = inside;
      if (x < rect.left) {
        code |= left;
      } else if (x > rect.right) {
        code |= right;
      }
      if (y < rect.top) {
        code |= top;
      } else if (y > rect.bottom) {
        code |= bottom;
      }
      return code;
    }

    int code1 = computeCode(x1, y1), code2 = computeCode(x2, y2);

    while (true) {
      if ((code1 | code2) == 0) return (Offset(x1, y1), Offset(x2, y2));
      if ((code1 & code2) != 0) return null;

      int codeOut = code1 != 0 ? code1 : code2;
      double x = 0, y = 0;

      if ((codeOut & top) != 0) {
        x = x1 + (x2 - x1) * (rect.top - y1) / (y2 - y1);
        y = rect.top;
      } else if ((codeOut & bottom) != 0) {
        x = x1 + (x2 - x1) * (rect.bottom - y1) / (y2 - y1);
        y = rect.bottom;
      } else if ((codeOut & right) != 0) {
        y = y1 + (y2 - y1) * (rect.right - x1) / (x2 - x1);
        x = rect.right;
      } else if ((codeOut & left) != 0) {
        y = y1 + (y2 - y1) * (rect.left - x1) / (x2 - x1);
        x = rect.left;
      }

      if (codeOut == code1) {
        x1 = x;
        y1 = y;
        code1 = computeCode(x1, y1);
      } else {
        x2 = x;
        y2 = y;
        code2 = computeCode(x2, y2);
      }
    }
  }

  bool _isPointInRect(Offset point, Rect rect) =>
      point.dx >= rect.left &&
      point.dx <= rect.right &&
      point.dy >= rect.top &&
      point.dy <= rect.bottom;

  void _drawSurface(Canvas canvas, Size size, double focalLength) {
    const gridSize = 50;
    final parser = MathParser(function);

    List<List<Point3D?>> points = [];
    List<List<double>> zValues = [];

    for (int i = 0; i <= gridSize; i++) {
      List<Point3D?> row = [];
      List<double> zRow = [];
      for (int j = 0; j <= gridSize; j++) {
        final x = -rangeX + (2 * rangeX * i / gridSize);
        final y = -rangeY + (2 * rangeY * j / gridSize);
        double z;
        try {
          z = parser.evaluate(x, y);
          if (!z.isFinite) {
            row.add(null);
            zRow.add(0);
            continue;
          }
          if (z < -rangeZ || z > rangeZ) {
            row.add(null);
            zRow.add(z);
            continue;
          }
        } catch (e) {
          row.add(null);
          zRow.add(0);
          continue;
        }

        row.add(
          Point3D(
            x * scaleX,
            y * scaleY,
            z * scaleZ,
          ).rotateX(rotationX).rotateZ(rotationZ),
        );
        zRow.add(z);
      }
      points.add(row);
      zValues.add(zRow);
    }

    List<Quad> quads = [];
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final p1 = points[i][j];
        final p2 = points[i + 1][j];
        final p3 = points[i + 1][j + 1];
        final p4 = points[i][j + 1];

        if (p1 == null || p2 == null || p3 == null || p4 == null) continue;

        final avgY = (p1.y + p2.y + p3.y + p4.y) / 4;
        final avgValue =
            (zValues[i][j] +
                zValues[i + 1][j] +
                zValues[i + 1][j + 1] +
                zValues[i][j + 1]) /
            4;
        quads.add(Quad(p1, p2, p3, p4, avgY, avgValue));
      }
    }

    quads.sort((a, b) => b.avgDepth.compareTo(a.avgDepth));

    for (final quad in quads) {
      final o1 = quad.p1.project(focalLength, size, panX, panY);
      final o2 = quad.p2.project(focalLength, size, panX, panY);
      final o3 = quad.p3.project(focalLength, size, panX, panY);
      final o4 = quad.p4.project(focalLength, size, panX, panY);

      final normalizedValue = (quad.avgValue + rangeZ) / (2 * rangeZ);
      final color = surfaceGradientColor(normalizedValue.clamp(0.0, 1.0));

      final path =
          Path()
            ..moveTo(o1.dx, o1.dy)
            ..lineTo(o2.dx, o2.dy)
            ..lineTo(o3.dx, o3.dy)
            ..lineTo(o4.dx, o4.dy)
            ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.7)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = _theme.wireframe
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
    }
  }

  void _drawStandingCurve(Canvas canvas, Size size, double focalLength) {
    final parser = MathParser(function);
    const steps = 300;

    final paint =
        Paint()
          ..color = colors.accent
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    final shadowPaint =
        Paint()
          ..color = colors.accent.withValues(alpha: 0.2)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
    final verticalPaint =
        Paint()
          ..color = colors.accent.withValues(alpha: 0.12)
          ..strokeWidth = 1;

    final path = Path();
    final shadowPath = Path();
    bool started = false, shadowStarted = false;
    double? lastZ;

    for (int i = 0; i <= steps; i++) {
      final x = -rangeX + (2 * rangeX * i / steps);
      double z;
      try {
        z = parser.evaluate(x, 0);
        if (!z.isFinite) {
          started = false;
          shadowStarted = false;
          lastZ = null;
          continue;
        }
        if (z < -rangeZ || z > rangeZ) {
          started = false;
          shadowStarted = false;
          lastZ = null;
          continue;
        }
      } catch (e) {
        started = false;
        shadowStarted = false;
        lastZ = null;
        continue;
      }

      final point = Point3D(
        x * scaleX,
        0,
        z * scaleZ,
      ).rotateX(rotationX).rotateZ(rotationZ);
      final shadowPoint = Point3D(
        x * scaleX,
        0,
        0,
      ).rotateX(rotationX).rotateZ(rotationZ);
      final proj = point.project(focalLength, size, panX, panY);
      final shadowProj = shadowPoint.project(focalLength, size, panX, panY);

      if (lastZ != null && (z - lastZ).abs() > rangeZ * 0.5) started = false;

      if (!started) {
        path.moveTo(proj.dx, proj.dy);
        started = true;
      } else {
        path.lineTo(proj.dx, proj.dy);
      }
      if (!shadowStarted) {
        shadowPath.moveTo(shadowProj.dx, shadowProj.dy);
        shadowStarted = true;
      } else {
        shadowPath.lineTo(shadowProj.dx, shadowProj.dy);
      }
      lastZ = z;

      if (i % 15 == 0) canvas.drawLine(proj, shadowProj, verticalPaint);
    }

    canvas.drawPath(shadowPath, shadowPaint);
    canvas.drawPath(path, paint);
  }

  void _drawScalarField3D(Canvas canvas, Size size, double focalLength) {
    final parser = MathParser(function);
    const gridCount = 12;

    List<FieldPoint3D> points = [];
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;

    for (int i = 0; i <= gridCount; i++) {
      for (int j = 0; j <= gridCount; j++) {
        for (int k = 0; k <= gridCount; k++) {
          final x = -rangeX + (2 * rangeX * i / gridCount);
          final y = -rangeY + (2 * rangeY * j / gridCount);
          final z = -rangeZ + (2 * rangeZ * k / gridCount);

          try {
            final val = parser.evaluate(x, y, z);
            if (!val.isFinite) continue;

            minVal = min(minVal, val);
            maxVal = max(maxVal, val);

            final point3D = Point3D(
              x * scaleX,
              y * scaleY,
              z * scaleZ,
            ).rotateX(rotationX).rotateZ(rotationZ);

            points.add(FieldPoint3D(point3D, val));
          } catch (e) {}
        }
      }
    }

    if (points.isEmpty) return;
    if (minVal == maxVal) maxVal = minVal + 1;

    points.sort((a, b) => b.point.y.compareTo(a.point.y));

    for (final fp in points) {
      final proj = fp.point.project(focalLength, size, panX, panY);
      if (!_isPointInRect(proj, Rect.fromLTWH(0, 0, size.width, size.height))) {
        continue;
      }

      final normalized = (fp.value - minVal) / (maxVal - minVal);
      final color = jetColormap(normalized);

      final depthScale = focalLength / (focalLength + fp.point.y);
      final radius = 6.0 * depthScale;

      canvas.drawCircle(
        proj,
        radius,
        Paint()..color = color.withValues(alpha: 0.8),
      );

      canvas.drawCircle(
        Offset(proj.dx - radius * 0.3, proj.dy - radius * 0.3),
        radius * 0.3,
        Paint()..color = _theme.label.withValues(alpha: 0.25),
      );
    }

    _drawColorbar3D(canvas, size, minVal, maxVal);
  }

  void _drawVectorField3D(Canvas canvas, Size size, double focalLength) {
    if (vectorParser == null) return;

    final bool showSurface = surfaceMode != SurfaceMode.none;
    const gridCount = 8;
    final bool is3DVector = vectorParser!.is3D;

      List<Arrow3D> arrows = [];
      double maxMag = 0;
      double maxSurfaceAbs = 0;

    if (is3DVector) {
      for (int i = 0; i <= gridCount; i++) {
        for (int j = 0; j <= gridCount; j++) {
          for (int k = 0; k <= gridCount; k++) {
            final x = -rangeX + (2 * rangeX * i / gridCount);
            final y = -rangeY + (2 * rangeY * j / gridCount);
            final z = -rangeZ + (2 * rangeZ * k / gridCount);

              final (fx, fy, fz) = vectorParser!.evaluate(x, y, z);
              double vx = fx;
              double vy = fy;
              double vz = fz;
              double surfaceValue = 0;
              double mag = vectorParser!.magnitude(x, y, z);

              if (surfaceMode == SurfaceMode.x) {
                vx = fx;
                vy = 0;
                vz = 0;
                surfaceValue = fx;
                mag = fx.abs();
              } else if (surfaceMode == SurfaceMode.y) {
                vx = 0;
                vy = fy;
                vz = 0;
                surfaceValue = fy;
                mag = fy.abs();
              } else if (surfaceMode == SurfaceMode.z) {
                vx = 0;
                vy = 0;
                vz = fz;
                surfaceValue = fz;
                mag = fz.abs();
              } else {
                surfaceValue = mag;
              }

              if (!mag.isFinite || mag < 1e-10) continue;

              maxMag = max(maxMag, mag);
              maxSurfaceAbs = max(maxSurfaceAbs, surfaceValue.abs());

              final inv = mag == 0 ? 0.0 : 1 / mag;
              final nx = vx * inv;
              final ny = vy * inv;
              final nz = vz * inv;
              final startPoint = Point3D(x * scaleX, y * scaleY, z * scaleZ);

              arrows.add(Arrow3D(startPoint, nx, ny, nz, mag, surfaceValue));
            }
          }
        }
    } else {
      for (int i = 0; i <= gridCount * 2; i++) {
        for (int j = 0; j <= gridCount * 2; j++) {
          final x = -rangeX + (2 * rangeX * i / (gridCount * 2));
          final y = -rangeY + (2 * rangeY * j / (gridCount * 2));

            final (fx, fy, fz) = vectorParser!.evaluate(x, y, 0);
            double vx = fx;
            double vy = fy;
            double vz = 0;
            double surfaceValue = 0;
            double mag = vectorParser!.magnitude(x, y, 0);

            if (surfaceMode == SurfaceMode.x) {
              vx = fx;
              vy = 0;
              surfaceValue = fx;
              mag = fx.abs();
            } else if (surfaceMode == SurfaceMode.y) {
              vx = 0;
              vy = fy;
              surfaceValue = fy;
              mag = fy.abs();
            } else if (surfaceMode == SurfaceMode.z) {
              vx = 0;
              vy = 0;
              vz = fz;
              surfaceValue = fz;
              mag = fz.abs();
            } else {
              surfaceValue = mag;
            }

            if (!mag.isFinite || mag < 1e-10) continue;

            maxMag = max(maxMag, mag);
            maxSurfaceAbs = max(maxSurfaceAbs, surfaceValue.abs());

            final inv = mag == 0 ? 0.0 : 1 / mag;
            final nx = vx * inv;
            final ny = vy * inv;
            final nz = vz * inv;
            final startPoint = Point3D(x * scaleX, y * scaleY, 0);

            arrows.add(Arrow3D(startPoint, nx, ny, nz, mag, surfaceValue));
          }
        }
      }

    if (arrows.isEmpty || maxMag == 0) return;

    arrows.sort((a, b) {
      final aRotated = a.start.rotateX(rotationX).rotateZ(rotationZ);
      final bRotated = b.start.rotateX(rotationX).rotateZ(rotationZ);
      return bRotated.y.compareTo(aRotated.y);
    });

    const arrowLength = 15.0;
    final double zScale =
        (showSurface && !is3DVector && maxSurfaceAbs > 0)
        ? (rangeZ / maxSurfaceAbs)
        : 0.0;
    for (final arrow in arrows) {
      final double surfaceZ =
          (showSurface && !is3DVector) ? arrow.surfaceValue * zScale : 0.0;
      final startPoint = (showSurface && !is3DVector)
          ? Point3D(arrow.start.x, arrow.start.y, surfaceZ * scaleZ)
          : arrow.start;
      final startRotated = startPoint.rotateX(rotationX).rotateZ(rotationZ);
      final startProj = startRotated.project(focalLength, size, panX, panY);

      if (!_isPointInRect(
        startProj,
        Rect.fromLTWH(-50, -50, size.width + 100, size.height + 100),
      )) {
        continue;
      }

      final endPoint = Point3D(
        startPoint.x + arrow.dx * arrowLength,
        startPoint.y + arrow.dy * arrowLength,
        startPoint.z + arrow.dz * arrowLength,
      );
      final endRotated = endPoint.rotateX(rotationX).rotateZ(rotationZ);
      final endProj = endRotated.project(focalLength, size, panX, panY);

      final normalized = arrow.magnitude / maxMag;
      final color = jetColormap(normalized);

      final paint =
          Paint()
            ..color = color
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round;

      canvas.drawLine(startProj, endProj, paint);

      final dx = endProj.dx - startProj.dx;
      final dy = endProj.dy - startProj.dy;
      final len = sqrt(dx * dx + dy * dy);
      if (len > 0) {
        final ux = dx / len;
        final uy = dy / len;
        const headLength = 5.0;
        const headAngle = 0.5;

        canvas.drawLine(
          endProj,
          Offset(
            endProj.dx -
                headLength * (ux * cos(headAngle) - uy * sin(headAngle)),
            endProj.dy -
                headLength * (ux * sin(headAngle) + uy * cos(headAngle)),
          ),
          paint,
        );
        canvas.drawLine(
          endProj,
          Offset(
            endProj.dx -
                headLength * (ux * cos(-headAngle) - uy * sin(-headAngle)),
            endProj.dy -
                headLength * (ux * sin(-headAngle) + uy * cos(-headAngle)),
          ),
          paint,
        );
      }
    }

    if (surfaceMode == SurfaceMode.none) {
      _drawColorbar3D(canvas, size, 0, maxMag);
    }
  }

  void _drawVectorMagnitudeField3D(
    Canvas canvas,
    Size size,
    double focalLength,
  ) {
    if (vectorParser == null) return;

    const gridCount = 10;
    final bool is3DVector = vectorParser!.is3D;

    List<FieldPoint3D> points = [];
    double maxMag = 0;

    if (is3DVector) {
      for (int i = 0; i <= gridCount; i++) {
        for (int j = 0; j <= gridCount; j++) {
          for (int k = 0; k <= gridCount; k++) {
            final x = -rangeX + (2 * rangeX * i / gridCount);
            final y = -rangeY + (2 * rangeY * j / gridCount);
            final z = -rangeZ + (2 * rangeZ * k / gridCount);

            final mag = vectorParser!.magnitude(x, y, z);
            if (!mag.isFinite) continue;

            maxMag = max(maxMag, mag);

            final point3D = Point3D(
              x * scaleX,
              y * scaleY,
              z * scaleZ,
            ).rotateX(rotationX).rotateZ(rotationZ);

            points.add(FieldPoint3D(point3D, mag));
          }
        }
      }
    } else {
      for (int i = 0; i <= gridCount * 2; i++) {
        for (int j = 0; j <= gridCount * 2; j++) {
          final x = -rangeX + (2 * rangeX * i / (gridCount * 2));
          final y = -rangeY + (2 * rangeY * j / (gridCount * 2));

          final mag = vectorParser!.magnitude(x, y, 0);
          if (!mag.isFinite) continue;

          maxMag = max(maxMag, mag);

          final point3D = Point3D(
            x * scaleX,
            y * scaleY,
            0,
          ).rotateX(rotationX).rotateZ(rotationZ);

          points.add(FieldPoint3D(point3D, mag));
        }
      }
    }

    if (points.isEmpty || maxMag == 0) return;

    points.sort((a, b) => b.point.y.compareTo(a.point.y));

    for (final fp in points) {
      final proj = fp.point.project(focalLength, size, panX, panY);
      if (!_isPointInRect(proj, Rect.fromLTWH(0, 0, size.width, size.height))) {
        continue;
      }

      final normalized = fp.value / maxMag;
      final color = jetColormap(normalized);

      final depthScale = focalLength / (focalLength + fp.point.y);
      final radius = 6.0 * depthScale;

      canvas.drawCircle(
        proj,
        radius,
        Paint()..color = color.withValues(alpha: 0.8),
      );

      canvas.drawCircle(
        Offset(proj.dx - radius * 0.3, proj.dy - radius * 0.3),
        radius * 0.3,
        Paint()..color = _theme.label.withValues(alpha: 0.25),
      );
    }

    _drawColorbar3D(canvas, size, 0, maxMag);
  }

  void _drawColorbar3D(Canvas canvas, Size size, double minVal, double maxVal) {
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
        ..color = _theme.colorbarBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final textStyle = TextStyle(color: _theme.colorbarText, fontSize: 10);

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

  @override
  bool shouldRepaint(covariant Plot3DPainter old) =>
      old.rotationX != rotationX ||
      old.rotationZ != rotationZ ||
      old.rangeX != rangeX ||
      old.rangeY != rangeY ||
      old.rangeZ != rangeZ || // New: check rangeZ
      old.panX != panX ||
      old.panY != panY ||
      old.function != function ||
      old.is3DFunction != is3DFunction ||
      old.plotMode != plotMode ||
      old.fieldType != fieldType ||
      old.showContour != showContour ||
      old.surfaceMode != surfaceMode ||
      old.colors != colors;
}
