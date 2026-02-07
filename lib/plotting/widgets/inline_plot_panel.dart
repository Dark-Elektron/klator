import 'package:flutter/material.dart';
import '../models/enums.dart';
import 'package:provider/provider.dart';
import '../../settings/settings_provider.dart';
import '../../utils/app_colors.dart';
import '../parsers/math_parser.dart';
import '../parsers/vector_field_parser.dart';
import 'plot_2d_screen.dart';
import 'plot_3d_screen.dart';

class InlinePlotPanel extends StatefulWidget {
  final String expression;
  final VoidCallback onToggleKeypad;
  final bool isKeypadVisible;

  const InlinePlotPanel({
    super.key,
    required this.expression,
    required this.onToggleKeypad,
    required this.isKeypadVisible,
  });

  @override
  State<InlinePlotPanel> createState() => _InlinePlotPanelState();
}

class _InlinePlotPanelState extends State<InlinePlotPanel> {
  String _currentFunction = '';
  String? _errorMessage;
  bool _is3DFunction = false;
  bool _show3D = false;
  Tool3DMode _tool3DMode = Tool3DMode.zoom;
  PlotMode _plotMode = PlotMode.function;
  FieldType _fieldType = FieldType.scalar;
  VectorFieldParser? _vectorParser;
  bool _showContour = false;
  SurfaceMode _surfaceMode = SurfaceMode.none;
  ZoomAxis _zoomAxis = ZoomAxis.free;

  final GlobalKey<Plot2DScreenState> _plot2DKey = GlobalKey();
  final GlobalKey<Plot3DScreenState> _plot3DKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _parseFunction(widget.expression);
  }

  @override
  void didUpdateWidget(covariant InlinePlotPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expression != widget.expression) {
      _parseFunction(widget.expression);
    }
  }

  void _parseFunction(String expr) {
    final trimmed = expr.trim();
    if (trimmed.isEmpty) {
      setState(() => _errorMessage = 'Please enter a function');
      return;
    }

    if (VectorFieldParser.isVectorField(trimmed)) {
      final parser = VectorFieldParser.parse(trimmed);
      if (parser != null) {
          setState(() {
            _currentFunction = trimmed;
            _vectorParser = parser;
            _fieldType = FieldType.vector;
            _is3DFunction = parser.is3D;
            _errorMessage = null;
            if (!_is3DFunction && _show3D) _show3D = false;
            if (_is3DFunction) {
              _surfaceMode = SurfaceMode.none;
            } else if (_surfaceMode == SurfaceMode.none) {
              _surfaceMode = SurfaceMode.magnitude;
            }
          });
        return;
      }
    }

    try {
      final parser = MathParser(trimmed);
      parser.evaluate(1, 1, 1);
        setState(() {
          _currentFunction = trimmed;
          _vectorParser = null;
          _fieldType = FieldType.scalar;
          _is3DFunction = parser.usesY;
          _errorMessage = null;
          if (!_is3DFunction && _show3D) _show3D = false;
          if (!_is3DFunction) {
            _surfaceMode = SurfaceMode.none;
          } else if (_surfaceMode == SurfaceMode.x ||
              _surfaceMode == SurfaceMode.y ||
              _surfaceMode == SurfaceMode.z) {
            _surfaceMode = SurfaceMode.magnitude;
          }
        });
    } catch (e) {
      setState(() => _errorMessage = 'Invalid function syntax');
    }
  }

  void _resetView() {
    if (_show3D) {
      _plot3DKey.currentState?.resetView();
    } else {
      _plot2DKey.currentState?.resetView();
    }
  }

  void _setTool3DMode(Tool3DMode mode) {
    setState(() => _tool3DMode = mode);
  }

  void _setZoomAxis(ZoomAxis axis) {
    setState(() {
      _zoomAxis = axis;
      _tool3DMode = Tool3DMode.zoom;
    });
  }

  void _togglePlotMode() {
    setState(() {
      _plotMode =
          _plotMode == PlotMode.function ? PlotMode.field : PlotMode.function;
    });
  }

  void _toggleContour() {
    setState(() => _showContour = !_showContour);
  }

  void _setSurfaceMode(SurfaceMode mode) {
    setState(() => _surfaceMode = mode);
  }

  String _getModeDescription() {
    List<String> modes = [];

    if (_fieldType == FieldType.vector) {
      if (_surfaceMode != SurfaceMode.none) {
        modes.add(_surfaceModeLabel());
      }
      if (_plotMode == PlotMode.field) {
        modes.add('Magnitude dots');
      } else {
        modes.add('Vector arrows');
      }
      if (_showContour) {
        modes.add('Contour');
      }
    } else {
      if (_surfaceMode != SurfaceMode.none && _is3DFunction) {
        modes.add('Surface');
      }
      if (_plotMode == PlotMode.field) {
        modes.add('Scalar field');
      } else {
        modes.add(_is3DFunction ? 'Function' : 'Line');
      }
      if (_showContour) {
        modes.add('Contour');
      }
    }

    return modes.join(' + ');
  }

  bool _canShowSurface() {
    if (_fieldType == FieldType.vector) {
      return _vectorParser != null && !_vectorParser!.is3D;
    }
    return _is3DFunction;
  }

  String _surfaceModeLabel() {
    switch (_surfaceMode) {
      case SurfaceMode.magnitude:
        return '|F|';
      case SurfaceMode.x:
        return 'Fx';
      case SurfaceMode.y:
        return 'Fy';
      case SurfaceMode.z:
        return 'Fz';
      case SurfaceMode.none:
        return 'Surface';
    }
  }

  String _getZoomAxisShortLabel() {
    switch (_zoomAxis) {
      case ZoomAxis.free:
        return '';
      case ZoomAxis.x:
        return 'X';
      case ZoomAxis.y:
        return 'Y';
      case ZoomAxis.z:
        return 'Z';
    }
  }

  AppColors _colorsNoListen(BuildContext context) {
    return AppColors.fromType(
      Provider.of<SettingsProvider>(context, listen: false).themeType,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool showOverlays = constraints.maxHeight > 140;
        return Stack(
          children: [
        IndexedStack(
          index: _show3D ? 0 : 1,
          children: [
            IgnorePointer(
              ignoring: !_show3D,
              child: Plot3DScreen(
                key: _plot3DKey,
                function: _currentFunction,
                is3DFunction: _is3DFunction,
                toolMode: _tool3DMode,
                plotMode: _plotMode,
                fieldType: _fieldType,
                vectorParser: _vectorParser,
                showContour: _showContour,
                  surfaceMode: _surfaceMode,
                  zoomAxis: _zoomAxis,
                  colors: _colorsNoListen(context),
                ),
              ),
              IgnorePointer(
                ignoring: _show3D,
                child: Plot2DScreen(
                  key: _plot2DKey,
                  function: _currentFunction,
                  is3DFunction: _is3DFunction,
                  plotMode: _plotMode,
                  fieldType: _fieldType,
                  vectorParser: _vectorParser,
                  showContour: _showContour,
                  surfaceMode: _surfaceMode,
                  zoomAxis: _zoomAxis,
                  colors: _colorsNoListen(context),
                ),
              ),
            ],
          ),

        if (showOverlays)
          Positioned(
            right: 0,
            bottom: 44,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                  if (_canShowSurface())
                    _buildSurfaceMenuButton(),
                  if (_fieldType == FieldType.scalar ||
                      (_fieldType == FieldType.vector &&
                          _surfaceMode != SurfaceMode.none))
                    _buildModeButton(
                      icon: Icons.show_chart,
                      isSelected: _showContour,
                    selectedColor: Colors.purpleAccent,
                    onTap: _toggleContour,
                    tooltip: 'Contour',
                  ),
                _buildModeButton(
                  icon: Icons.grain,
                  isSelected: _plotMode == PlotMode.field,
                  selectedColor: Colors.orangeAccent,
                  onTap: _togglePlotMode,
                  tooltip: 'Field',
                ),
                _buildModeButton(
                  label: '3D',
                  isSelected: _show3D,
                  selectedColor: Colors.tealAccent,
                  onTap: () => setState(() => _show3D = true),
                ),
                _buildModeButton(
                  label: '2D',
                  isSelected: !_show3D,
                  selectedColor: Colors.tealAccent,
                  onTap: () => setState(() => _show3D = false),
                ),
              ],
            ),
          ),

        if (showOverlays)
          Positioned(
            bottom: 52,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _getModeDescription(),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ),

        if (_errorMessage != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.red.withValues(alpha: 0.8),
              padding: const EdgeInsets.all(4),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),

        // Vector indicator removed per UI request

        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildToolbar(),
        ),
      ],
        );
      },
    );
  }

  Widget _buildModeButton({
    IconData? icon,
    String? label,
    required bool isSelected,
    required Color selectedColor,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final button = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color:
              isSelected
                  ? selectedColor.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.5),
          border: Border.all(
            color: isSelected ? selectedColor : Colors.white24,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child:
              icon != null
                  ? Icon(
                    icon,
                    color: isSelected ? selectedColor : Colors.white54,
                    size: 20,
                  )
                  : Text(
                    label!,
                    style: TextStyle(
                      color: isSelected ? selectedColor : Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }

  Widget _buildToolbar() {
    final colors = _colorsNoListen(context);
    return Container(
      color: colors.containerBackground,
      child: Row(
        children: [
          _buildToolButton(Icons.home, _resetView, false),
          _buildToolButton(
            widget.isKeypadVisible
                ? Icons.keyboard_hide
                : Icons.keyboard,
            widget.onToggleKeypad,
            false,
          ),
          _buildToolButton(Icons.zoom_in, () {}, false),
          _buildToolButton(Icons.zoom_out, () {}, false),
          Container(width: 1, height: 40, color: colors.divider),
          if (_show3D) ...[
            _build3DZoomDropdown(),
            _buildToolButton(
              Icons.pan_tool,
              () => _setTool3DMode(Tool3DMode.pan),
              _tool3DMode == Tool3DMode.pan,
            ),
            _buildToolButton(Icons.threed_rotation, () {}, false),
            _buildToolButton(Icons.settings, () {}, false),
          ] else ...[
            _buildToolButton(Icons.show_chart, () {}, false),
            _buildToolButton(Icons.timeline, () {}, false),
            _buildToolButton(Icons.stacked_line_chart, () {}, false),
            _buildToolButton(Icons.area_chart, () {}, false),
          ],
        ],
      ),
    );
  }

  Widget _build3DZoomDropdown() {
    final colors = _colorsNoListen(context);
    final isSelected = _tool3DMode == Tool3DMode.zoom;

    return Expanded(
      child: PopupMenuButton<ZoomAxis>(
        onSelected: (ZoomAxis axis) {
          _setZoomAxis(axis);
        },
        offset: const Offset(0, -215),
        color: colors.containerBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        itemBuilder:
            (BuildContext context) => <PopupMenuEntry<ZoomAxis>>[
              _buildZoomMenuItem(
                ZoomAxis.free,
                'Free',
                Icons.zoom_out_map,
              ),
              _buildZoomMenuItem(ZoomAxis.x, 'X', Icons.swap_horiz),
              _buildZoomMenuItem(ZoomAxis.y, 'Y', Icons.swap_vert),
              _buildZoomMenuItem(ZoomAxis.z, 'Z', Icons.height),
            ],
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color:
                isSelected ? colors.accent.withValues(alpha: 0.25) : Colors.transparent,
            border: Border.all(
              color: isSelected ? colors.accent : colors.divider,
              width: isSelected ? 1.5 : 0.5,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.zoom_out_map,
                color: isSelected ? colors.accent : colors.textSecondary,
                size: 18,
              ),
              if (_zoomAxis != ZoomAxis.free)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      _getZoomAxisShortLabel(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 2,
                top: 4,
                child: Icon(
                  Icons.arrow_drop_down,
                  color:
                      isSelected
                          ? colors.accent.withValues(alpha: 0.7)
                          : colors.textSecondary.withValues(alpha: 0.7),
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<ZoomAxis> _buildZoomMenuItem(
    ZoomAxis axis,
    String label,
    IconData icon,
  ) {
    final colors = _colorsNoListen(context);
    final isSelected = _zoomAxis == axis;
    return PopupMenuItem<ZoomAxis>(
      value: axis,
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected ? colors.accent : colors.textSecondary,
            size: 18,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? colors.accent : colors.textPrimary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const Spacer(),
          if (isSelected)
            Icon(Icons.check, color: colors.accent, size: 18),
        ],
      ),
    );
  }

  Widget _buildToolButton(
    IconData icon,
    VoidCallback onPressed,
    bool isSelected,
  ) {
    final colors = _colorsNoListen(context);
    return Expanded(
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color:
                isSelected
                    ? colors.accent.withValues(alpha: 0.25)
                    : Colors.transparent,
            border: Border.all(
              color: isSelected ? colors.accent : colors.divider,
              width: isSelected ? 1.5 : 0.5,
            ),
          ),
          child: Icon(
            icon,
            color: isSelected ? colors.accent : colors.textSecondary,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildSurfaceMenuButton() {
    final bool isSelected = _surfaceMode != SurfaceMode.none;
    final menuItems = <PopupMenuEntry<SurfaceMode>>[];

    menuItems.add(
      const PopupMenuItem(
        value: SurfaceMode.none,
        child: Text('Off'),
      ),
    );

    if (_fieldType == FieldType.vector) {
      menuItems.add(
        const PopupMenuItem(
          value: SurfaceMode.magnitude,
          child: Text('|F|'),
        ),
      );
      menuItems.add(
        const PopupMenuItem(
          value: SurfaceMode.x,
          child: Text('Fx'),
        ),
      );
      menuItems.add(
        const PopupMenuItem(
          value: SurfaceMode.y,
          child: Text('Fy'),
        ),
      );
      if (_vectorParser?.zComponent != null) {
        menuItems.add(
          const PopupMenuItem(
            value: SurfaceMode.z,
            child: Text('Fz'),
          ),
        );
      }
    } else {
      menuItems.add(
        const PopupMenuItem(
          value: SurfaceMode.magnitude,
          child: Text('Surface'),
        ),
      );
    }

    return PopupMenuButton<SurfaceMode>(
      onSelected: _setSurfaceMode,
      itemBuilder: (context) => menuItems,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color:
              isSelected
                  ? Colors.greenAccent.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.5),
          border: Border.all(
            color: isSelected ? Colors.greenAccent : Colors.white24,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.landscape,
            color: isSelected ? Colors.greenAccent : Colors.white54,
            size: 20,
          ),
        ),
      ),
    );
  }
}
