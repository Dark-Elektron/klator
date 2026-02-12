// lib/widgets/textured_container.dart

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../utils/texture_generator.dart';

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
    debugPrint('🖼️ TexturedContainer initState - color: ${widget.baseColor.value.toRadixString(16)}');
    _loadTexture();
  }

  @override
  void didUpdateWidget(TexturedContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugPrint('🖼️ didUpdateWidget - old: ${oldWidget.baseColor.value.toRadixString(16)}, new: ${widget.baseColor.value.toRadixString(16)}');
    
    // Always reload if color changed
    if (oldWidget.baseColor.value != widget.baseColor.value) {
      debugPrint('🖼️ Color changed! Reloading texture...');
      _textureImage = null; // Clear old image immediately
      _loadTexture();
    }
  }

  Future<void> _loadTexture() async {
    final colorToLoad = widget.baseColor;
    final colorValue = colorToLoad.value;
    
    debugPrint('🖼️ _loadTexture called for color: ${colorValue.toRadixString(16)}, isLoading: $_isLoading');
    
    // If already loading this exact color, skip
    if (_isLoading && _loadedColorValue == colorValue) {
      debugPrint('🖼️ Already loading this color, skipping');
      return;
    }
    
    _isLoading = true;
    _loadedColorValue = colorValue;

    const textureSize = Size(400, 300);
    
    try {
      final image = await TextureGenerator.getTexture(colorToLoad, textureSize);
      
      debugPrint('🖼️ Texture generated, mounted: $mounted, colorMatch: ${widget.baseColor.value == colorValue}');
      
      if (mounted && widget.baseColor.value == colorValue) {
        setState(() {
          _textureImage = image;
          _isLoading = false;
        });
        debugPrint('🖼️ Texture applied!');
      } else {
        _isLoading = false;
        debugPrint('🖼️ Texture discarded (color changed during load or unmounted)');
      }
    } catch (e) {
      debugPrint('🖼️ Error loading texture: $e');
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
      decoration: baseDecoration.copyWith(
        color: widget.baseColor,
      ),
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