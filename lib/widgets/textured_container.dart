// lib/widgets/textured_container.dart

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../utils/texture_generator.dart';
import '../utils/app_colors.dart';

class TexturedContainer extends StatefulWidget {
  final Color baseColor;
  final Widget child;
  final BoxDecoration? decoration;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;

  const TexturedContainer({
    super.key,
    required this.baseColor,
    required this.child,
    this.decoration,
    this.padding,
    this.margin,
    this.width,
    this.height,
  });

  @override
  State<TexturedContainer> createState() => _TexturedContainerState();
}

class _TexturedContainerState extends State<TexturedContainer> {
  ui.Image? _textureImage;
  bool _isLoading = false;
  int _loadedColorValue = 0;

  @override
  void initState() {
    super.initState();
    // Initial load happens in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadTexture();
  }

  @override
  void didUpdateWidget(TexturedContainer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Always reload if color changed
    if (oldWidget.baseColor.toARGB32() != widget.baseColor.toARGB32()) {
      _textureImage = null; // Clear old image immediately
      _loadTexture();
    }
  }

  Future<void> _loadTexture() async {
    final colorToLoad = widget.baseColor;
    final colorValue = colorToLoad.toARGB32();

    // debugPrint('🖼️ _loadTexture called for color: ${colorValue.toRadixString(16)}, isLoading: $_isLoading');

    // If already loading this exact color, skip
    if (_isLoading && _loadedColorValue == colorValue) {
      return;
    }

    _isLoading = true;
    _loadedColorValue = colorValue;

    try {
      final colors = AppColors.of(context, listen: false);
      const textureSize = Size(400, 300);

      final image = await TextureGenerator.getTexture(
        colorToLoad,
        textureSize,
        intensity: colors.textureIntensity,
        scale: colors.textureScale,
        softness: colors.textureSoftness,
      );

      final mounted = image != null;
      debugPrint(
        '🖼️ Texture generated, mounted: $mounted, colorMatch: ${widget.baseColor.toARGB32() == colorValue}',
      );

      if (mounted && widget.baseColor.toARGB32() == colorValue) {
        setState(() {
          _textureImage = image;
          _isLoading = false;
        });
      } else {
        _isLoading = false;
      }
    } catch (e) {
      debugPrint('🖼️ Error generating texture: $e');
      _isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    BoxDecoration baseDecoration = widget.decoration ?? const BoxDecoration();

    return Container(
      width: widget.width,
      height: widget.height,
      padding: widget.padding,
      margin: widget.margin,
      decoration: baseDecoration.copyWith(color: widget.baseColor),
      child: ClipRect(
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            // Texture layer
            if (_textureImage != null)
              Positioned.fill(
                child: RawImage(
                  image: _textureImage,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            // Content
            widget.child,
          ],
        ),
      ),
    );
  }
}
