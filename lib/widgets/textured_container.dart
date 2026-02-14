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

class _TexturedContainerState extends State<TexturedContainer>
    with SingleTickerProviderStateMixin {
  ui.Image? _textureImage;
  bool _isLoading = false;
  int _loadedColorValue = 0;
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _hasAnimatedIn = false;

  @override
  void initState() {
    super.initState();
    
    // Fade controller for smooth texture appearance
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    
    _primeTextureFromCache(widget.baseColor);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _primeTextureFromCache(widget.baseColor);
    _loadTexture();
  }

  @override
  void didUpdateWidget(TexturedContainer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.baseColor.toARGB32() != widget.baseColor.toARGB32()) {
      _textureImage = null;
      _hasAnimatedIn = false;
      _fadeController.value = 0.0;
      _primeTextureFromCache(widget.baseColor);
      _loadTexture();
    }
  }

  void _primeTextureFromCache(Color color) {
    final cached = TextureGenerator.peekCachedTexture(color);
    if (cached == null) return;

    _textureImage = cached;
    _loadedColorValue = color.toARGB32();
    
    // If we got it from cache, show immediately
    if (!_hasAnimatedIn) {
      _fadeController.value = 1.0;
      _hasAnimatedIn = true;
    }
  }

  Future<void> _loadTexture() async {
    final colorToLoad = widget.baseColor;
    final colorValue = colorToLoad.toARGB32();

    if (!_isLoading &&
        _textureImage != null &&
        _loadedColorValue == colorValue) {
      return;
    }

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

      final hasImage = image != null;

      if (!mounted) {
        _isLoading = false;
        return;
      }

      if (hasImage && widget.baseColor.toARGB32() == colorValue) {
        if (identical(_textureImage, image)) {
          _isLoading = false;
          // Still ensure fade is complete
          if (!_hasAnimatedIn) {
            _fadeController.forward();
            _hasAnimatedIn = true;
          }
          return;
        }
        
        setState(() {
          _textureImage = image;
          _isLoading = false;
        });
        
        // Animate in the texture smoothly
        if (!_hasAnimatedIn) {
          _fadeController.forward();
          _hasAnimatedIn = true;
        }
      } else {
        _isLoading = false;
      }
    } catch (e) {
      assert(() {
        debugPrint('Error generating texture: $e');
        return true;
      }());
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    BoxDecoration baseDecoration = widget.decoration ?? const BoxDecoration();

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
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
                // Texture layer with fade
                if (_textureImage != null)
                  Positioned.fill(
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: RawImage(
                        image: _textureImage,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                // Content
                widget.child,
              ],
            ),
          ),
        );
      },
    );
  }
}