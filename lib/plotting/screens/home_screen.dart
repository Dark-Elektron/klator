import 'package:flutter/material.dart';
import '../models/enums.dart';
import '../parsers/math_parser.dart';
import '../parsers/vector_field_parser.dart';
import '../widgets/plot_2d_screen.dart';
import '../widgets/plot_3d_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _functionController = TextEditingController();
  String _currentFunction = 'sin(x)';
  String? _errorMessage;
  bool _is3DFunction = false;
  bool _show3D = false;
  Tool3DMode _tool3DMode = Tool3DMode.zoom;
  PlotMode _plotMode = PlotMode.function;
  FieldType _fieldType = FieldType.scalar;
  VectorFieldParser? _vectorParser;
  bool _showContour = false;
  bool _showSurface = false;
  ZoomAxis _zoomAxis = ZoomAxis.free;

  final GlobalKey<Plot2DScreenState> _plot2DKey = GlobalKey();
  final GlobalKey<Plot3DScreenState> _plot3DKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _functionController.text = _currentFunction;
    _parseFunction();
  }

  @override
  void dispose() {
    _functionController.dispose();
    super.dispose();
  }

  void _parseFunction() {
    final expr = _functionController.text.trim();
    if (expr.isEmpty) {
      setState(() => _errorMessage = 'Please enter a function');
      return;
    }

    if (VectorFieldParser.isVectorField(expr)) {
      final parser = VectorFieldParser.parse(expr);
      if (parser != null) {
        setState(() {
          _currentFunction = expr;
          _vectorParser = parser;
          _fieldType = FieldType.vector;
          _is3DFunction = parser.is3D;
          _errorMessage = null;
        });
        return;
      }
    }

    try {
      final parser = MathParser(expr);
      parser.evaluate(1, 1, 1);
      setState(() {
        _currentFunction = expr;
        _vectorParser = null;
        _fieldType = FieldType.scalar;
        _is3DFunction = parser.usesY;
        _errorMessage = null;
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
      _tool3DMode =
          Tool3DMode.zoom; // Also set to zoom mode when selecting axis
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

  void _toggleSurface() {
    setState(() => _showSurface = !_showSurface);
  }

  String _getInputLabel() {
    if (_fieldType == FieldType.vector) return 'F=';
    if (_is3DFunction) return 'f(x,y)=';
    return 'f(x)=';
  }

  String _getModeDescription() {
    List<String> modes = [];

    if (_fieldType == FieldType.vector) {
      if (_showSurface) {
        modes.add('|F| Surface');
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
      if (_showSurface && _is3DFunction) {
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

  String _getZoomAxisLabel() {
    switch (_zoomAxis) {
      case ZoomAxis.free:
        return 'Free';
      case ZoomAxis.x:
        return 'X';
      case ZoomAxis.y:
        return 'Y';
      case ZoomAxis.z:
        return 'Z';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  if (_show3D)
                    Plot3DScreen(
                      key: _plot3DKey,
                      function: _currentFunction,
                      is3DFunction: _is3DFunction,
                      toolMode: _tool3DMode,
                      plotMode: _plotMode,
                      fieldType: _fieldType,
                      vectorParser: _vectorParser,
                      showContour: _showContour,
                      showSurface: _showSurface,
                      zoomAxis: _zoomAxis,
                    )
                  else
                    Plot2DScreen(
                      key: _plot2DKey,
                      function: _currentFunction,
                      is3DFunction: _is3DFunction,
                      plotMode: _plotMode,
                      fieldType: _fieldType,
                      vectorParser: _vectorParser,
                      showContour: _showContour,
                      showSurface: _showSurface,
                      zoomAxis: _zoomAxis,
                    ),

                  // Zoom axis indicator (when not free, in 3D mode)
                  if (_show3D && _zoomAxis != ZoomAxis.free)
                    Positioned(
                      top: 8,
                      right: 56,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.tealAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.tealAccent),
                        ),
                        child: Text(
                          'Zoom: ${_getZoomAxisShortLabel()} axis',
                          style: const TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // Mode toggles (right side)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Surface toggle
                        if (_canShowSurface())
                          _buildModeButton(
                            icon: Icons.landscape,
                            isSelected: _showSurface,
                            selectedColor: Colors.greenAccent,
                            onTap: _toggleSurface,
                            tooltip:
                                _fieldType == FieldType.vector
                                    ? 'Surface (|F|)'
                                    : 'Surface',
                          ),
                        // Contour toggle
                        if (_fieldType == FieldType.scalar ||
                            (_fieldType == FieldType.vector && _showSurface))
                          _buildModeButton(
                            icon: Icons.show_chart,
                            isSelected: _showContour,
                            selectedColor: Colors.purpleAccent,
                            onTap: _toggleContour,
                            tooltip: 'Contour',
                          ),
                        // Field/dots toggle
                        _buildModeButton(
                          icon: Icons.grain,
                          isSelected: _plotMode == PlotMode.field,
                          selectedColor: Colors.orangeAccent,
                          onTap: _togglePlotMode,
                          tooltip: 'Field',
                        ),
                        // 3D toggle
                        _buildModeButton(
                          label: '3D',
                          isSelected: _show3D,
                          selectedColor: Colors.tealAccent,
                          onTap: () => setState(() => _show3D = true),
                        ),
                        // 2D toggle
                        _buildModeButton(
                          label: '2D',
                          isSelected: !_show3D,
                          selectedColor: Colors.tealAccent,
                          onTap: () => setState(() => _show3D = false),
                        ),
                      ],
                    ),
                  ),

                  // Mode description
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getModeDescription(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),

                  // Error message
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                  // Vector field indicator
                  if (_fieldType == FieldType.vector)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 48,
                      child: Container(
                        color: Colors.blue.withValues(alpha: 0.8),
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          'Vector: $_vectorParser',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Toolbar
            _buildToolbar(),

            // Input row
            _buildInputRow(),
          ],
        ),
      ),
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
    return Container(
      color: const Color(0xFF16213e),
      child: Row(
        children: [
          _buildToolButton(Icons.home, _resetView, false),
          _buildToolButton(Icons.zoom_in, () {}, false),
          _buildToolButton(Icons.zoom_out, () {}, false),
          _buildToolButton(Icons.center_focus_strong, () {}, false),
          _buildToolButton(Icons.grid_on, () {}, false),
          Container(width: 1, height: 40, color: Colors.white24),
          if (_show3D) ...[
            // Zoom dropdown button for 3D
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
    final isSelected = _tool3DMode == Tool3DMode.zoom;

    return Expanded(
      child: PopupMenuButton<ZoomAxis>(
        onSelected: (ZoomAxis axis) {
          _setZoomAxis(axis);
        },
        offset: const Offset(0, -200),
        color: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        itemBuilder:
            (BuildContext context) => <PopupMenuEntry<ZoomAxis>>[
              _buildZoomMenuItem(
                ZoomAxis.free,
                'Free Zoom',
                Icons.zoom_out_map,
              ),
              _buildZoomMenuItem(ZoomAxis.x, 'X Axis Only', Icons.swap_horiz),
              _buildZoomMenuItem(ZoomAxis.y, 'Y Axis Only', Icons.swap_vert),
              _buildZoomMenuItem(ZoomAxis.z, 'Z Axis Only', Icons.height),
            ],
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color:
                isSelected
                    ? Colors.tealAccent.withValues(alpha: 0.2)
                    : Colors.transparent,
            border: Border.all(
              color: isSelected ? Colors.tealAccent : Colors.white12,
              width: isSelected ? 1.5 : 0.5,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Main icon
              Icon(
                Icons.zoom_out_map,
                color: isSelected ? Colors.tealAccent : Colors.white54,
                size: 18,
              ),
              // Axis badge (bottom right)
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
                      color: Colors.tealAccent,
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
              // Dropdown arrow (top right)
              Positioned(
                right: 2,
                top: 4,
                child: Icon(
                  Icons.arrow_drop_down,
                  color:
                      isSelected
                          ? Colors.tealAccent.withValues(alpha: 0.7)
                          : Colors.white38,
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
    final isSelected = _zoomAxis == axis;
    return PopupMenuItem<ZoomAxis>(
      value: axis,
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.tealAccent : Colors.white54,
            size: 18,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.tealAccent : Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const Spacer(),
          if (isSelected)
            const Icon(Icons.check, color: Colors.tealAccent, size: 18),
        ],
      ),
    );
  }

  Widget _buildToolButton(
    IconData icon,
    VoidCallback onPressed,
    bool isSelected,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color:
                isSelected
                    ? Colors.tealAccent.withValues(alpha: 0.2)
                    : Colors.transparent,
            border: Border.all(
              color: isSelected ? Colors.tealAccent : Colors.white12,
              width: isSelected ? 1.5 : 0.5,
            ),
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.tealAccent : Colors.white54,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildInputRow() {
    return Container(
      color: const Color(0xFF16213e),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              _getInputLabel(),
              style: const TextStyle(
                color: Colors.tealAccent,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _functionController,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'sin(x), x^2+y^2, xi+yj, xi+yj+zk',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
                filled: true,
                fillColor: const Color(0xFF0f0f23),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _parseFunction(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow, color: Colors.tealAccent),
            onPressed: _parseFunction,
          ),
        ],
      ),
    );
  }
}
