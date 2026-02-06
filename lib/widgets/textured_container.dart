// lib/widgets/textured_container.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import '../utils/texture_generator.dart';
import '../utils/app_colors.dart';
import '../settings/settings_provider.dart';

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
  String _loadedCacheKey = '';

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _hasAnimatedIn = false;

  // Track the last settings to detect changes
  TextureType? _lastTextureType;
  int? _lastColorValue;

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndLoadTexture();
  }

  @override
  void didUpdateWidget(TexturedContainer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.baseColor.toARGB32() != widget.baseColor.toARGB32()) {
      _resetAndReload();
    }
  }

  void _resetAndReload() {
    _textureImage = null;
    _hasAnimatedIn = false;
    _fadeController.value = 0.0;
    _loadedCacheKey = '';
    _checkAndLoadTexture();
  }

  void _checkAndLoadTexture() {
    if (!mounted) return;

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final currentColorValue = widget.baseColor.toARGB32();

    // Check if settings have changed
    final settingsChanged = _lastTextureType != settings.textureType ||
        _lastColorValue != currentColorValue;

    if (settingsChanged) {
      _lastTextureType = settings.textureType;
      _lastColorValue = currentColorValue;

      _textureImage = null;
      _hasAnimatedIn = false;
      _fadeController.value = 0.0;
      _loadedCacheKey = '';
      _isLoading = false;
    }

    _primeTextureFromCache();
    _loadTexture();
  }

  String _getCacheKey(Color color, TextureType type) {
    return '${color.toARGB32()}_${type.name}';
  }

  void _primeTextureFromCache() {
    if (!mounted) return;

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final textureType = settings.textureType;

    if (textureType == TextureType.none) {
      _textureImage = null;
      return;
    }

    final cached = TextureGenerator.peekCachedTexture(
      widget.baseColor,
      type: textureType,
    );

    if (cached == null) return;

    final cacheKey = _getCacheKey(widget.baseColor, textureType);

    _textureImage = cached;
    _loadedCacheKey = cacheKey;

    // If we got it from cache, show immediately
    if (!_hasAnimatedIn) {
      _fadeController.value = 1.0;
      _hasAnimatedIn = true;
    }
  }

  Future<void> _loadTexture() async {
    if (!mounted) return;

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final textureType = settings.textureType;

    // No texture needed
    if (textureType == TextureType.none) {
      if (_textureImage != null && mounted) {
        setState(() {
          _textureImage = null;
        });
      }
      return;
    }

    final colorToLoad = widget.baseColor;
    final cacheKey = _getCacheKey(colorToLoad, textureType);

    // Already have this texture
    if (_textureImage != null && _loadedCacheKey == cacheKey) {
      return;
    }

    // Already loading this texture
    if (_isLoading && _loadedCacheKey == cacheKey) {
      return;
    }

    _isLoading = true;
    _loadedCacheKey = cacheKey;

    try {
      final colors = AppColors.of(context, listen: false);
      const textureSize = Size(400, 300);

      final image = await TextureGenerator.getTexture(
        colorToLoad,
        textureSize,
        type: textureType,
        // Smooth noise parameters
        intensity: colors.textureIntensity,
        scale: colors.textureScale,
        softness: colors.textureSoftness,
      );

      if (!mounted) {
        _isLoading = false;
        return;
      }

      // Verify the cache key still matches
      final currentCacheKey = _getCacheKey(
        widget.baseColor,
        settings.textureType,
      );

      if (image != null && cacheKey == currentCacheKey) {
        setState(() {
          _textureImage = image;
          _isLoading = false;
        });

        // Animate in the texture smoothly
        if (!_hasAnimatedIn && mounted) {
          _fadeController.forward();
          _hasAnimatedIn = true;
        }
      } else {
        _isLoading = false;
        // Settings changed during load, reload with new settings
        if (cacheKey != currentCacheKey && mounted) {
          _loadTexture();
        }
      }
    } catch (e) {
      assert(() {
        debugPrint('Error generating texture: $e');
        return true;
      }());
      if (mounted) {
        _isLoading = false;
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _textureImage = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to settings changes to trigger rebuild
    final settings = Provider.of<SettingsProvider>(context);
    final textureType = settings.textureType;

    // Check if we need to reload due to settings change
    final currentColorValue = widget.baseColor.toARGB32();
    final needsReload = _lastTextureType != textureType ||
        _lastColorValue != currentColorValue;

    if (needsReload) {
      // Schedule the check for after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkAndLoadTexture();
        }
      });
    }

    BoxDecoration baseDecoration = widget.decoration ?? const BoxDecoration();

    // If texture type is none, just return a simple container
    if (textureType == TextureType.none) {
      return Container(
        width: widget.width,
        height: widget.height,
        padding: widget.padding,
        margin: widget.margin,
        decoration: baseDecoration.copyWith(color: widget.baseColor),
        child: widget.child,
      );
    }

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