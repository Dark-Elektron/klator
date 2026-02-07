import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class PlotThemeData {
  final Gradient background2D;
  final Gradient background3D;
  final Color grid;
  final Color subGrid;
  final Color axis;
  final Color tick;
  final Color label;
  final Color boundary;
  final Color colorbarBorder;
  final Color colorbarText;
  final Color wireframe;
  final Color axisX;
  final Color axisY;
  final Color axisZ;

  const PlotThemeData({
    required this.background2D,
    required this.background3D,
    required this.grid,
    required this.subGrid,
    required this.axis,
    required this.tick,
    required this.label,
    required this.boundary,
    required this.colorbarBorder,
    required this.colorbarText,
    required this.wireframe,
    required this.axisX,
    required this.axisY,
    required this.axisZ,
  });

  factory PlotThemeData.fromColors(AppColors colors) {
    final baseLum = colors.displayBackground.computeLuminance();
    final isLight = baseLum > 0.5;
    final base = colors.displayBackground;
    final alt = colors.containerBackground;

    Color shift(Color c, double amount) {
      if (amount == 0) return c;
      if (amount > 0) {
        return Color.lerp(c, Colors.white, amount) ?? c;
      }
      return Color.lerp(c, Colors.black, -amount) ?? c;
    }

    final edge2D = shift(alt, isLight ? -0.18 : -0.38).withValues(alpha: 0.99);
    final mid2D = shift(alt, isLight ? -0.05 : -0.22).withValues(alpha: 0.99);
    final center2D =
        shift(base, isLight ? 0.04 : 0.16).withValues(alpha: 0.99);

    final background2D = RadialGradient(
      center: Alignment.center,
      radius: 1.1,
      colors: [center2D, mid2D, edge2D],
      stops: const [0.0, 0.55, 1.0],
    );

    final edge3D = shift(alt, isLight ? -0.22 : -0.42).withValues(alpha: 0.99);
    final mid3D = shift(alt, isLight ? -0.08 : -0.26).withValues(alpha: 0.99);
    final center3D =
        shift(base, isLight ? 0.03 : 0.14).withValues(alpha: 0.99);

    final background3D = RadialGradient(
      center: Alignment.center,
      radius: 1.15,
      colors: [center3D, mid3D, edge3D],
      stops: const [0.0, 0.6, 1.0],
    );

    final lineBase = colors.textPrimary;
    final grid = lineBase.withValues(alpha: isLight ? 0.22 : 0.25);
    final subGrid = lineBase.withValues(alpha: isLight ? 0.12 : 0.12);
    final axis = lineBase.withValues(alpha: isLight ? 0.45 : 0.6);
    final tick = lineBase.withValues(alpha: isLight ? 0.35 : 0.5);
    final label = lineBase.withValues(alpha: isLight ? 0.75 : 0.8);
    final boundary = lineBase.withValues(alpha: isLight ? 0.5 : 0.65);
    final colorbarBorder = lineBase.withValues(alpha: isLight ? 0.45 : 0.6);
    final colorbarText = lineBase.withValues(alpha: isLight ? 0.8 : 0.85);
    final wireframe = lineBase.withValues(alpha: isLight ? 0.12 : 0.18);

    Color axisTone(Color baseColor) {
      return isLight
          ? (Color.lerp(baseColor, Colors.black, 0.25) ?? baseColor)
          : (Color.lerp(baseColor, Colors.white, 0.2) ?? baseColor);
    }

    final axisX = axisTone(const Color(0xFFEF5350));
    final axisY = axisTone(const Color(0xFF66BB6A));
    final axisZ = axisTone(const Color(0xFF42A5F5));

    return PlotThemeData(
      background2D: background2D,
      background3D: background3D,
      grid: grid,
      subGrid: subGrid,
      axis: axis,
      tick: tick,
      label: label,
      boundary: boundary,
      colorbarBorder: colorbarBorder,
      colorbarText: colorbarText,
      wireframe: wireframe,
      axisX: axisX,
      axisY: axisY,
      axisZ: axisZ,
    );
  }
}
