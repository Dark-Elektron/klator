// lib/utils/texture_generator.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';

enum TextureType {
  smoothNoise, // Original texture
  paperFiber, // Handmade paper look
  none, // No texture (solid color)
}

class TextureGenerator {
  // Fixed values for paper fiber texture
  static const double _defaultGrainIntensity = 0.15;
  static const double _defaultFiberDensity = 0.0;

  static final Map<String, ui.Image?> _cache = {};
  static final Map<String, Completer<ui.Image?>> _pendingRequests = {};

  static String _getCacheKey(Color color, TextureType type) {
    return '${color.toARGB32()}_${type.name}';
  }

  static ui.Image? peekCachedTexture(
    Color baseColor, {
    TextureType type = TextureType.smoothNoise,
  }) {
    return _cache[_getCacheKey(baseColor, type)];
  }

  /// Get or generate a texture for the given color
  static Future<ui.Image?> getTexture(
    Color baseColor,
    Size size, {
    TextureType type = TextureType.smoothNoise,
    // Smooth noise parameters
    double intensity = 0.15,
    double scale = 1.65,
    double softness = 1.0,
  }) async {
    // No texture needed
    if (type == TextureType.none) {
      return null;
    }

    final cacheKey = _getCacheKey(baseColor, type);

    // Return cached image if available
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    // If already generating this color/type, wait for it
    if (_pendingRequests.containsKey(cacheKey)) {
      return _pendingRequests[cacheKey]!.future;
    }

    // Start generating
    final completer = Completer<ui.Image?>();
    _pendingRequests[cacheKey] = completer;

    try {
      ui.Image? image;

      switch (type) {
        case TextureType.smoothNoise:
          image = await _generateSmoothNoiseTexture(
            baseColor,
            size,
            intensity: intensity,
            scale: scale,
            softness: softness,
          );
          break;
        case TextureType.paperFiber:
          image = await _generatePaperFiberTexture(
            baseColor,
            size,
          );
          break;
        case TextureType.none:
          image = null;
          break;
      }

      _cache[cacheKey] = image;
      completer.complete(image);
    } catch (e) {
      completer.complete(null);
    } finally {
      _pendingRequests.remove(cacheKey);
    }

    return completer.future;
  }

  /// Clear cached textures (call when theme changes)
  static void clearCache() {
    final imagesToDispose = _cache.values.whereType<ui.Image>().toList();
    _cache.clear();
    _pendingRequests.clear();

    // Dispose after clearing references
    for (final image in imagesToDispose) {
      image.dispose();
    }
  }

  // ============================================
  // SMOOTH NOISE TEXTURE (Original)
  // ============================================

  static Future<ui.Image?> _generateSmoothNoiseTexture(
    Color baseColor,
    Size size, {
    required double intensity,
    required double scale,
    required double softness,
  }) async {
    final genScale = 0.3 + (softness * 0.2);
    final width = (size.width * genScale).toInt().clamp(50, 600);
    final height = (size.height * genScale).toInt().clamp(50, 600);

    final pixels = _generateSmoothNoisePixels(
      baseColor,
      width,
      height,
      intensity: intensity,
      scale: scale,
    );
    return _createImageFromPixels(pixels, width, height);
  }

  static Uint8List _generateSmoothNoisePixels(
    Color baseColor,
    int width,
    int height, {
    required double intensity,
    required double scale,
  }) {
    final pixels = Uint8List(width * height * 4);
    final random = math.Random(42);

    const gridSize = 32;
    final grid = List.generate(gridSize * gridSize, (_) => random.nextDouble());

    double getValue(int gx, int gy) {
      return grid[(gy % gridSize) * gridSize + (gx % gridSize)];
    }

    double smoothNoise(double x, double y) {
      final scaleX = x * scale * 0.02;
      final scaleY = y * scale * 0.02;

      final x0 = scaleX.floor();
      final y0 = scaleY.floor();
      final x1 = x0 + 1;
      final y1 = y0 + 1;

      final sx = scaleX - x0;
      final sy = scaleY - y0;

      final tx = sx * sx * (3 - 2 * sx);
      final ty = sy * sy * (3 - 2 * sy);

      final n00 = getValue(x0, y0);
      final n10 = getValue(x1, y0);
      final n01 = getValue(x0, y1);
      final n11 = getValue(x1, y1);

      final nx0 = n00 + tx * (n10 - n00);
      final nx1 = n01 + tx * (n11 - n01);

      return nx0 + ty * (nx1 - nx0);
    }

    double layeredNoise(double x, double y) {
      double value = 0;
      double amp = 1;
      double freq = 1;
      double maxAmp = 0;

      for (int i = 0; i < 5; i++) {
        value += smoothNoise(x * freq, y * freq) * amp;
        maxAmp += amp;
        amp *= 0.5;
        freq *= 2;
      }

      return value / maxAmp;
    }

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final noise = layeredNoise(x.toDouble(), y.toDouble());
        final variation = (noise - 0.5) * 2 * intensity;

        final r = ((baseColor.r * 255 * (1 + variation))).round().clamp(0, 255);
        final g = ((baseColor.g * 255 * (1 + variation))).round().clamp(0, 255);
        final b = ((baseColor.b * 255 * (1 + variation))).round().clamp(0, 255);

        final idx = (y * width + x) * 4;
        pixels[idx] = r;
        pixels[idx + 1] = g;
        pixels[idx + 2] = b;
        pixels[idx + 3] = 255;
      }
    }

    return pixels;
  }

  // ============================================
  // PAPER FIBER TEXTURE (Using Canvas)
  // ============================================

  static Future<ui.Image?> _generatePaperFiberTexture(
    Color baseColor,
    Size size,
  ) async {
    // Use a reasonable size for the texture
    final width = size.width.clamp(100, 600).toDouble();
    final height = size.height.clamp(100, 600).toDouble();
    final textureSize = Size(width, height);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    _paintPaperTexture(
      canvas,
      textureSize,
      baseColor: baseColor,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    picture.dispose();

    return image;
  }

  /// Paint paper texture to canvas
  static void _paintPaperTexture(
    Canvas canvas,
    Size size, {
    required Color baseColor,
  }) {
    final paint = Paint()..color = baseColor;
    final random = math.Random(42);

    // 1. Draw Background Base
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // 2. Draw Grain (Micro-noise)
    // High density of tiny dots to simulate paper pulp
    final grainCount = (size.width * size.height * 0.5).toInt();
    for (int i = 0; i < grainCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;

      // Randomly choose between a white speck or a dark speck
      final isLight = random.nextBool();
      paint.color = (isLight ? Colors.white : Colors.black)
          .withOpacity(random.nextDouble() * _defaultGrainIntensity);
      paint.style = PaintingStyle.fill;

      canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), paint);
    }

    // 3. Draw Fibers (only if fiber density > 0)
    if (_defaultFiberDensity > 0) {
      final int fiberCount =
          (size.width * size.height * _defaultFiberDensity * 5.0).toInt();

      for (int i = 0; i < fiberCount; i++) {
        final x = random.nextDouble() * size.width;
        final y = random.nextDouble() * size.height;

        paint.color = Colors.black.withOpacity(0.15);
        paint.strokeWidth = 0.6;
        paint.style = PaintingStyle.stroke;

        final path = Path();
        path.moveTo(x, y);
        path.quadraticBezierTo(
          x + random.nextDouble() * 4,
          y + random.nextDouble() * 4,
          x + random.nextDouble() * 8 - 4,
          y + random.nextDouble() * 8 - 4,
        );
        canvas.drawPath(path, paint);
      }
    }
  }

  // ============================================
  // SHARED UTILITIES
  // ============================================

  static Future<ui.Image> _createImageFromPixels(
    Uint8List pixels,
    int width,
    int height,
  ) {
    final completer = Completer<ui.Image>();

    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      (image) => completer.complete(image),
    );

    return completer.future;
  }
}