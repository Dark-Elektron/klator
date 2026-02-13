// lib/utils/texture_generator.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';

class TextureGenerator {
  static final Map<int, ui.Image?> _cache = {};
  static final Map<int, Completer<ui.Image?>> _pendingRequests = {};

  /// Get or generate a texture for the given color
  static Future<ui.Image?> getTexture(
    Color baseColor,
    Size size, {
    double intensity = 0.15,
    double scale = 1.65,
    double softness = 1.0,
  }) async {
    final cacheKey = baseColor.toARGB32();

    // Return cached image if available
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    // If already generating this color, wait for it
    if (_pendingRequests.containsKey(cacheKey)) {
      return _pendingRequests[cacheKey]!.future;
    }

    // Start generating
    final completer = Completer<ui.Image?>();
    _pendingRequests[cacheKey] = completer;

    try {
      final image = await _generateTexture(
        baseColor,
        size,
        intensity: intensity,
        scale: scale,
        softness: softness,
      );
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
    for (final image in _cache.values) {
      image?.dispose();
    }
    _cache.clear();
    _pendingRequests.clear();
  }

  static Future<ui.Image?> _generateTexture(
    Color baseColor,
    Size size, {
    required double intensity,
    required double scale,
    required double softness,
  }) async {
    final genScale = 0.3 + (softness * 0.2);
    final width = (size.width * genScale).toInt().clamp(50, 600);
    final height = (size.height * genScale).toInt().clamp(50, 600);

    final pixels = _generateNoisePixels(
      baseColor,
      width,
      height,
      intensity: intensity,
      scale: scale,
    );
    return _createImage(pixels, width, height);
  }

  static Future<ui.Image> _createImage(
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

  static Uint8List _generateNoisePixels(
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
}
