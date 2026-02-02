import 'package:flutter/material.dart';
import 'dart:math';

void main() {
  runApp(const MathPlotterApp());
}

class MathPlotterApp extends StatelessWidget {
  const MathPlotterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Math Plotter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1a1a2e),
        colorScheme: ColorScheme.dark(
          primary: Colors.blue.shade400,
          secondary: Colors.tealAccent,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// ============================================================
// MATH EXPRESSION PARSER
// ============================================================

class MathParser {
  final String expression;
  int _pos = 0;
  String? _currentToken;

  MathParser(this.expression);

  double evaluate(double x, [double y = 0, double z = 0]) {
    _pos = 0;
    _nextToken();
    return _parseExpression(x, y, z);
  }

  bool get usesY => expression.contains(RegExp(r'(?<![a-zA-Z])y(?![a-zA-Z])'));
  bool get usesZ => expression.contains(RegExp(r'(?<![a-zA-Z])z(?![a-zA-Z])'));

  void _nextToken() {
    while (_pos < expression.length && expression[_pos] == ' ') _pos++;
    if (_pos >= expression.length) {
      _currentToken = null;
      return;
    }
    final char = expression[_pos];
    if ('+-*/^(),'.contains(char)) {
      _currentToken = char;
      _pos++;
      return;
    }
    if (char.contains(RegExp(r'[0-9.]'))) {
      final start = _pos;
      while (_pos < expression.length &&
          expression[_pos].contains(RegExp(r'[0-9.]'))) _pos++;
      _currentToken = expression.substring(start, _pos);
      return;
    }
    if (char.contains(RegExp(r'[a-zA-Z]'))) {
      final start = _pos;
      while (_pos < expression.length &&
          expression[_pos].contains(RegExp(r'[a-zA-Z0-9]'))) _pos++;
      _currentToken = expression.substring(start, _pos);
      return;
    }
    _pos++;
    _nextToken();
  }

  double _parseExpression(double x, double y, double z) {
    var result = _parseTerm(x, y, z);
    while (_currentToken == '+' || _currentToken == '-') {
      final op = _currentToken;
      _nextToken();
      result = op == '+' 
          ? result + _parseTerm(x, y, z) 
          : result - _parseTerm(x, y, z);
    }
    return result;
  }

  double _parseTerm(double x, double y, double z) {
    var result = _parsePower(x, y, z);
    while (_currentToken == '*' || _currentToken == '/') {
      final op = _currentToken;
      _nextToken();
      result = op == '*' 
          ? result * _parsePower(x, y, z) 
          : result / _parsePower(x, y, z);
    }
    return result;
  }

  double _parsePower(double x, double y, double z) {
    var result = _parseUnary(x, y, z);
    if (_currentToken == '^') {
      _nextToken();
      result = pow(result, _parseUnary(x, y, z)).toDouble();
    }
    return result;
  }

  double _parseUnary(double x, double y, double z) {
    if (_currentToken == '-') {
      _nextToken();
      return -_parseFactor(x, y, z);
    }
    if (_currentToken == '+') _nextToken();
    return _parseFactor(x, y, z);
  }

  double _parseFactor(double x, double y, double z) {
    if (_currentToken == '(') {
      _nextToken();
      final result = _parseExpression(x, y, z);
      if (_currentToken == ')') _nextToken();
      return result;
    }
    if (_currentToken != null && _currentToken!.contains(RegExp(r'^[0-9.]'))) {
      final value = double.tryParse(_currentToken!) ?? 0;
      _nextToken();
      return value;
    }
    if (_currentToken != null) {
      final token = _currentToken!.toLowerCase();
      _nextToken();
      if (token == 'x') return x;
      if (token == 'y') return y;
      if (token == 'z') return z;
      if (token == 'pi') return pi;
      if (token == 'e') return e;
      if (_currentToken == '(') {
        _nextToken();
        final arg1 = _parseExpression(x, y, z);
        double? arg2;
        if (_currentToken == ',') {
          _nextToken();
          arg2 = _parseExpression(x, y, z);
        }
        if (_currentToken == ')') _nextToken();
        return _evaluateFunction(token, arg1, arg2);
      }
    }
    return 0;
  }

  double _evaluateFunction(String name, double arg1, [double? arg2]) {
    switch (name) {
      case 'sin': return sin(arg1);
      case 'cos': return cos(arg1);
      case 'tan': return tan(arg1);
      case 'asin': return asin(arg1);
      case 'acos': return acos(arg1);
      case 'atan': return atan(arg1);
      case 'atan2': return atan2(arg1, arg2 ?? 1);
      case 'sinh': return (exp(arg1) - exp(-arg1)) / 2;
      case 'cosh': return (exp(arg1) + exp(-arg1)) / 2;
      case 'tanh': return (exp(arg1) - exp(-arg1)) / (exp(arg1) + exp(-arg1));
      case 'exp': return exp(arg1);
      case 'log': case 'ln': return log(arg1);
      case 'log10': return log(arg1) / ln10;
      case 'sqrt': return sqrt(arg1);
      case 'abs': return arg1.abs();
      case 'floor': return arg1.floorToDouble();
      case 'ceil': return arg1.ceilToDouble();
      case 'round': return arg1.roundToDouble();
      case 'sign': return arg1.sign;
      case 'min': return min(arg1, arg2 ?? arg1);
      case 'max': return max(arg1, arg2 ?? arg1);
      case 'pow': return pow(arg1, arg2 ?? 1).toDouble();
      case 'mod': return arg1 % (arg2 ?? 1);
      default: return 0;
    }
  }
}

// ============================================================
// VECTOR FIELD PARSER
// ============================================================

// ============================================================
// VECTOR FIELD PARSER
// ============================================================

class VectorFieldParser {
  final String? xComponent;
  final String? yComponent;
  final String? zComponent;
  
  late final MathParser? _xParser;
  late final MathParser? _yParser;
  late final MathParser? _zParser;

  VectorFieldParser({this.xComponent, this.yComponent, this.zComponent}) {
    _xParser = xComponent != null ? MathParser(xComponent!) : null;
    _yParser = yComponent != null ? MathParser(yComponent!) : null;
    _zParser = zComponent != null ? MathParser(zComponent!) : null;
  }

  /// Check if expression is a vector field
  /// Looks for i, j, k at end of terms (followed by +, -, or end of string)
  static bool isVectorField(String expr) {
    String normalized = expr.replaceAll(' ', '').toLowerCase();
    
    // Look for i, j, or k that are at the end of terms
    // (followed by +, -, or end of string, but not by letters or '(')
    // This avoids matching 'i' in 'sin', 'min', etc.
    return RegExp(r'[ijk](?=[+\-]|$)(?!\()').hasMatch(normalized);
  }

  /// Parse expression like "xi + yj + zk" or "2*x*i + sin(y)*j"
  static VectorFieldParser? parse(String expr) {
    if (!isVectorField(expr)) return null;

    String? xComp, yComp, zComp;
    
    // Normalize the expression - remove spaces
    String normalized = expr.replaceAll(' ', '');
    
    // Split into terms (keeping signs)
    List<String> terms = [];
    String currentTerm = '';
    int parenDepth = 0;
    
    for (int i = 0; i < normalized.length; i++) {
      final char = normalized[i];
      
      if (char == '(') parenDepth++;
      if (char == ')') parenDepth--;
      
      // Only split on + or - when not inside parentheses
      if ((char == '+' || char == '-') && i > 0 && parenDepth == 0) {
        if (currentTerm.isNotEmpty) terms.add(currentTerm);
        currentTerm = char == '-' ? '-' : '';
      } else {
        currentTerm += char;
      }
    }
    if (currentTerm.isNotEmpty) terms.add(currentTerm);

    // Process each term
    for (String term in terms) {
      String component;
      String coefficient;
      
      // Check which component (i, j, or k) this term represents
      String termLower = term.toLowerCase();
      
      if (termLower.endsWith('i') && !_endsWithFunction(termLower, 'i')) {
        coefficient = term.substring(0, term.length - 1);
        component = 'i';
      } else if (termLower.endsWith('j') && !_endsWithFunction(termLower, 'j')) {
        coefficient = term.substring(0, term.length - 1);
        component = 'j';
      } else if (termLower.endsWith('k') && !_endsWithFunction(termLower, 'k')) {
        coefficient = term.substring(0, term.length - 1);
        component = 'k';
      } else {
        continue; // Not a vector component term
      }

      // Clean up coefficient
      coefficient = coefficient.trim();
      if (coefficient.isEmpty || coefficient == '+') {
        coefficient = '1';
      } else if (coefficient == '-') {
        coefficient = '-1';
      } else if (coefficient.endsWith('*')) {
        coefficient = coefficient.substring(0, coefficient.length - 1);
      }

      switch (component) {
        case 'i': xComp = coefficient; break;
        case 'j': yComp = coefficient; break;
        case 'k': zComp = coefficient; break;
      }
    }

    // Only return if we found at least one component
    if (xComp == null && yComp == null && zComp == null) {
      return null;
    }

    return VectorFieldParser(
      xComponent: xComp,
      yComponent: yComp,
      zComponent: zComp,
    );
  }

  /// Check if the term ends with a function name containing the letter
  /// e.g., "sin" ends with 'i' in the middle, not as a vector component
  static bool _endsWithFunction(String term, String letter) {
    // Common function names that contain i, j, or k
    const functionsWithI = ['sin', 'asin', 'sinh', 'min', 'ceil'];
    const functionsWithK = ['sqrt']; // None really, but for safety
    
    if (letter == 'i') {
      for (final func in functionsWithI) {
        if (term.endsWith(func)) return true;
      }
    }
    // j and k typically don't appear in function names
    return false;
  }

  bool get is3D => zComponent != null;
  bool get is2D => zComponent == null && (xComponent != null || yComponent != null);

  (double, double, double) evaluate(double x, double y, [double z = 0]) {
    final fx = _xParser?.evaluate(x, y, z) ?? 0;
    final fy = _yParser?.evaluate(x, y, z) ?? 0;
    final fz = _zParser?.evaluate(x, y, z) ?? 0;
    return (fx, fy, fz);
  }

  double magnitude(double x, double y, [double z = 0]) {
    final (fx, fy, fz) = evaluate(x, y, z);
    return sqrt(fx * fx + fy * fy + fz * fz);
  }

  (double, double, double) normalized(double x, double y, [double z = 0]) {
    final (fx, fy, fz) = evaluate(x, y, z);
    final mag = sqrt(fx * fx + fy * fy + fz * fz);
    if (mag < 1e-10) return (0, 0, 0);
    return (fx / mag, fy / mag, fz / mag);
  }
  
  @override
  String toString() {
    return 'VectorFieldParser(x: $xComponent, y: $yComponent, z: $zComponent)';
  }
}

// ============================================================
// JET COLORMAP
// ============================================================

Color jetColormap(double t) {
  t = t.clamp(0.0, 1.0);
  
  if (t < 0.125) {
    return Color.lerp(
      const Color(0xFF000080), // Dark blue
      const Color(0xFF0000FF), // Blue
      t / 0.125,
    )!;
  } else if (t < 0.375) {
    return Color.lerp(
      const Color(0xFF0000FF), // Blue
      const Color(0xFF00FFFF), // Cyan
      (t - 0.125) / 0.25,
    )!;
  } else if (t < 0.625) {
    return Color.lerp(
      const Color(0xFF00FFFF), // Cyan
      const Color(0xFF00FF00), // Green
      (t - 0.375) / 0.25,
    )!;
  } else if (t < 0.875) {
    return Color.lerp(
      const Color(0xFFFFFF00), // Yellow
      const Color(0xFFFF0000), // Red
      (t - 0.625) / 0.25,
    )!;
  } else {
    return Color.lerp(
      const Color(0xFFFF0000), // Red
      const Color(0xFF800000), // Dark red
      (t - 0.875) / 0.125,
    )!;
  }
}

// ============================================================
// HOME SCREEN
// ============================================================

enum Tool3DMode { zoom, pan }
enum PlotMode { function, field }
enum FieldType { scalar, vector }

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

  final GlobalKey<_Plot2DScreenState> _plot2DKey = GlobalKey();
  final GlobalKey<_Plot3DScreenState> _plot3DKey = GlobalKey();

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

    // Check if it's a vector field
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

    // Scalar function
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
    setState(() {
      _tool3DMode = mode;
    });
  }

  void _togglePlotMode() {
    setState(() {
      _plotMode = _plotMode == PlotMode.function 
          ? PlotMode.field 
          : PlotMode.function;
    });
  }

  String _getInputLabel() {
    if (_fieldType == FieldType.vector) {
      return 'F=';
    } else if (_is3DFunction) {
      return 'f(x,y)=';
    } else {
      return 'f(x)=';
    }
  }

  String _getModeDescription() {
    if (_fieldType == FieldType.vector) {
      if (_plotMode == PlotMode.field) {
        return 'Vector magnitude (colored points)';
      } else {
        return 'Vector field (arrows)';
      }
    } else {
      if (_plotMode == PlotMode.field) {
        return 'Scalar field (colored points)';
      } else {
        return _is3DFunction ? 'Surface plot' : 'Line plot';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // PLOT AREA
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
                    )
                  else
                    Plot2DScreen(
                      key: _plot2DKey,
                      function: _currentFunction,
                      is3DFunction: _is3DFunction,
                      plotMode: _plotMode,
                      fieldType: _fieldType,
                      vectorParser: _vectorParser,
                    ),

                  // Mode toggles (right side)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Field mode toggle
                        GestureDetector(
                          onTap: _togglePlotMode,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _plotMode == PlotMode.field
                                  ? Colors.orangeAccent.withOpacity(0.3)
                                  : Colors.black.withOpacity(0.5),
                              border: Border.all(
                                color: _plotMode == PlotMode.field
                                    ? Colors.orangeAccent
                                    : Colors.white24,
                                width: _plotMode == PlotMode.field ? 2 : 1,
                              ),
                            ),
                            child: Icon(
                              Icons.grain,
                              color: _plotMode == PlotMode.field
                                  ? Colors.orangeAccent
                                  : Colors.white54,
                              size: 20,
                            ),
                          ),
                        ),
                        // 3D toggle
                        GestureDetector(
                          onTap: () => setState(() => _show3D = true),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _show3D
                                  ? Colors.tealAccent.withOpacity(0.3)
                                  : Colors.black.withOpacity(0.5),
                              border: Border.all(
                                color: _show3D ? Colors.tealAccent : Colors.white24,
                                width: _show3D ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '3D',
                                style: TextStyle(
                                  color: _show3D ? Colors.tealAccent : Colors.white54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 2D toggle
                        GestureDetector(
                          onTap: () => setState(() => _show3D = false),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: !_show3D
                                  ? Colors.tealAccent.withOpacity(0.3)
                                  : Colors.black.withOpacity(0.5),
                              border: Border.all(
                                color: !_show3D ? Colors.tealAccent : Colors.white24,
                                width: !_show3D ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '2D',
                                style: TextStyle(
                                  color: !_show3D ? Colors.tealAccent : Colors.white54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Mode description overlay
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getModeDescription(),
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ),

                  // Error message overlay
                  if (_errorMessage != null)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.red.withOpacity(0.8),
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                  // Vector field hint
                  if (_fieldType == FieldType.vector && _plotMode == PlotMode.function)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 48,
                      child: Container(
                        color: Colors.blue.withOpacity(0.8),
                        padding: const EdgeInsets.all(4),
                        child: const Text(
                          'Vector field detected — showing arrows',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // BUTTONS ROW
            Container(
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
                    _buildToolButton(
                      Icons.zoom_out_map,
                      () => _setTool3DMode(Tool3DMode.zoom),
                      _tool3DMode == Tool3DMode.zoom,
                    ),
                    _buildToolButton(
                      Icons.pan_tool,
                      () => _setTool3DMode(Tool3DMode.pan),
                      _tool3DMode == Tool3DMode.pan,
                    ),
                    _buildToolButton(Icons.flip_to_front, () {}, false),
                    _buildToolButton(Icons.threed_rotation, () {}, false),
                  ] else ...[
                    _buildToolButton(Icons.show_chart, () {}, false),
                    _buildToolButton(Icons.timeline, () {}, false),
                    _buildToolButton(Icons.stacked_line_chart, () {}, false),
                    _buildToolButton(Icons.area_chart, () {}, false),
                  ],
                ],
              ),
            ),

            // TEXT INPUT ROW
            Container(
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
                          color: Colors.white.withOpacity(0.3),
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
            ),
          ],
        ),
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
            color: isSelected
                ? Colors.tealAccent.withOpacity(0.2)
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
}

// ============================================================
// 2D PLOTTING
// ============================================================

class Plot2DScreen extends StatefulWidget {
  final String function;
  final bool is3DFunction;
  final PlotMode plotMode;
  final FieldType fieldType;
  final VectorFieldParser? vectorParser;

  const Plot2DScreen({
    super.key,
    required this.function,
    required this.is3DFunction,
    required this.plotMode,
    required this.fieldType,
    this.vectorParser,
  });

  @override
  State<Plot2DScreen> createState() => _Plot2DScreenState();
}

class _Plot2DScreenState extends State<Plot2DScreen> {
  double xMin = -5, xMax = 5;
  double yMin = -3, yMax = 3;
  double _lastScale = 1.0;

  void resetView() {
    setState(() {
      xMin = -5;
      xMax = 5;
      yMin = -3;
      yMax = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onScaleStart: (details) {
            _lastScale = 1.0;
          },
          onScaleUpdate: (details) {
            setState(() {
              if (details.pointerCount > 1) {
                final scaleDelta = details.scale / _lastScale;
                _lastScale = details.scale;

                if ((scaleDelta - 1.0).abs() < 1e-3) return;

                final focalPointX = details.localFocalPoint.dx.clamp(0, constraints.maxWidth);
                final focalPointY = details.localFocalPoint.dy.clamp(0, constraints.maxHeight);

                final focalX = xMin + (focalPointX / constraints.maxWidth) * (xMax - xMin);
                final focalY = yMax - (focalPointY / constraints.maxHeight) * (yMax - yMin);

                xMin = focalX - (focalX - xMin) / scaleDelta;
                xMax = focalX + (xMax - focalX) / scaleDelta;
                yMin = focalY - (focalY - yMin) / scaleDelta;
                yMax = focalY + (yMax - focalY) / scaleDelta;
              } else if (details.pointerCount == 1) {
                final dx = details.focalPointDelta.dx;
                final dy = details.focalPointDelta.dy;
                final xShift = -dx * (xMax - xMin) / constraints.maxWidth;
                final yShift = dy * (yMax - yMin) / constraints.maxHeight;
                xMin += xShift;
                xMax += xShift;
                yMin += yShift;
                yMax += yShift;
              }
            });
          },
          child: Container(
            color: Colors.black,
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: Plot2DPainter(
                function: widget.function,
                xMin: xMin,
                xMax: xMax,
                yMin: yMin,
                yMax: yMax,
                plotMode: widget.plotMode,
                fieldType: widget.fieldType,
                vectorParser: widget.vectorParser,
              ),
            ),
          ),
        );
      },
    );
  }
}

class Plot2DPainter extends CustomPainter {
  final String function;
  final double xMin, xMax, yMin, yMax;
  final PlotMode plotMode;
  final FieldType fieldType;
  final VectorFieldParser? vectorParser;

  Plot2DPainter({
    required this.function,
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    required this.plotMode,
    required this.fieldType,
    this.vectorParser,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double toScreenX(double x) => (x - xMin) / (xMax - xMin) * size.width;
    double toScreenY(double y) => size.height - (y - yMin) / (yMax - yMin) * size.height;

    _drawGrid(canvas, size, toScreenX, toScreenY);
    _drawAxes(canvas, size, toScreenX, toScreenY);

    if (plotMode == PlotMode.field) {
      if (fieldType == FieldType.vector) {
        _drawVectorMagnitudeField(canvas, size, toScreenX, toScreenY);
      } else {
        _drawScalarField(canvas, size, toScreenX, toScreenY);
      }
    } else {
      if (fieldType == FieldType.vector) {
        _drawVectorField(canvas, size, toScreenX, toScreenY);
      } else {
        _drawFunction(canvas, size, toScreenX, toScreenY);
      }
    }

    _drawLabels(canvas, size, toScreenX, toScreenY);
  }

  void _drawGrid(Canvas canvas, Size size, double Function(double) toScreenX, double Function(double) toScreenY) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1.2;
    final subGridPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 0.8;
    double gridSpacing = _calculateGridSpacing(xMax - xMin);

    for (double x = (xMin / gridSpacing).floor() * gridSpacing; x <= xMax; x += gridSpacing / 5) {
      canvas.drawLine(Offset(toScreenX(x), 0), Offset(toScreenX(x), size.height), subGridPaint);
    }
    for (double y = (yMin / gridSpacing).floor() * gridSpacing; y <= yMax; y += gridSpacing / 5) {
      canvas.drawLine(Offset(0, toScreenY(y)), Offset(size.width, toScreenY(y)), subGridPaint);
    }
    for (double x = (xMin / gridSpacing).floor() * gridSpacing; x <= xMax; x += gridSpacing) {
      canvas.drawLine(Offset(toScreenX(x), 0), Offset(toScreenX(x), size.height), gridPaint);
    }
    for (double y = (yMin / gridSpacing).floor() * gridSpacing; y <= yMax; y += gridSpacing) {
      canvas.drawLine(Offset(0, toScreenY(y)), Offset(size.width, toScreenY(y)), gridPaint);
    }
  }

  void _drawAxes(Canvas canvas, Size size, double Function(double) toScreenX, double Function(double) toScreenY) {
    final axisPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 2;
    final arrowPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final tickPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 1;

    if (yMin <= 0 && yMax >= 0) {
      final y0 = toScreenY(0);
      canvas.drawLine(Offset(0, y0), Offset(size.width, y0), axisPaint);
      canvas.drawPath(
        Path()
          ..moveTo(size.width - 10, y0 - 5)
          ..lineTo(size.width, y0)
          ..lineTo(size.width - 10, y0 + 5),
        arrowPaint,
      );
    }
    if (xMin <= 0 && xMax >= 0) {
      final x0 = toScreenX(0);
      canvas.drawLine(Offset(x0, 0), Offset(x0, size.height), axisPaint);
      canvas.drawPath(
        Path()
          ..moveTo(x0 - 5, 10)
          ..lineTo(x0, 0)
          ..lineTo(x0 + 5, 10),
        arrowPaint,
      );
    }

    double gridSpacing = _calculateGridSpacing(xMax - xMin);
    for (double x = (xMin / gridSpacing).ceil() * gridSpacing; x <= xMax; x += gridSpacing) {
      if (x.abs() > 0.001) {
        final y0 = toScreenY(0).clamp(10.0, size.height - 10);
        canvas.drawLine(Offset(toScreenX(x), y0 - 5), Offset(toScreenX(x), y0 + 5), tickPaint);
      }
    }
    for (double y = (yMin / gridSpacing).ceil() * gridSpacing; y <= yMax; y += gridSpacing) {
      if (y.abs() > 0.001) {
        final x0 = toScreenX(0).clamp(10.0, size.width - 10);
        canvas.drawLine(Offset(x0 - 5, toScreenY(y)), Offset(x0 + 5, toScreenY(y)), tickPaint);
      }
    }
  }

  void _drawFunction(Canvas canvas, Size size, double Function(double) toScreenX, double Function(double) toScreenY) {
    final paint = Paint()
      ..color = const Color(0xFF58C4DD)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final parser = MathParser(function);
    final path = Path();
    const steps = 1000;
    bool started = false;
    double? lastY;

    for (int i = 0; i <= steps; i++) {
      final x = xMin + i * (xMax - xMin) / steps;
      double y;
      try {
        y = parser.evaluate(x, 0);
      } catch (e) {
        started = false;
        lastY = null;
        continue;
      }

      if (y.isFinite && y.abs() < 1000) {
        if (lastY != null && (y - lastY!).abs() > (yMax - yMin) * 0.5) started = false;
        if (!started) {
          path.moveTo(toScreenX(x), toScreenY(y));
          started = true;
        } else {
          path.lineTo(toScreenX(x), toScreenY(y));
        }
        lastY = y;
      } else {
        started = false;
        lastY = null;
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawScalarField(Canvas canvas, Size size, double Function(double) toScreenX, double Function(double) toScreenY) {
    final parser = MathParser(function);
    const gridCount = 25;
    final circleRadius = min(size.width, size.height) / gridCount / 3;

    // First pass: find min/max values
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;
    
    for (int i = 0; i <= gridCount; i++) {
      for (int j = 0; j <= gridCount; j++) {
        final x = xMin + (xMax - xMin) * i / gridCount;
        final y = yMin + (yMax - yMin) * j / gridCount;
        try {
          final val = parser.evaluate(x, y);
          if (val.isFinite) {
            minVal = min(minVal, val);
            maxVal = max(maxVal, val);
          }
        } catch (e) {}
      }
    }

    if (minVal == maxVal) {
      maxVal = minVal + 1;
    }

    // Second pass: draw circles
    for (int i = 0; i <= gridCount; i++) {
      for (int j = 0; j <= gridCount; j++) {
        final x = xMin + (xMax - xMin) * i / gridCount;
        final y = yMin + (yMax - yMin) * j / gridCount;
        
        try {
          final val = parser.evaluate(x, y);
          if (!val.isFinite) continue;

          final normalized = (val - minVal) / (maxVal - minVal);
          final color = jetColormap(normalized);

          canvas.drawCircle(
            Offset(toScreenX(x), toScreenY(y)),
            circleRadius,
            Paint()..color = color.withOpacity(0.8),
          );
        } catch (e) {}
      }
    }

    // Draw colorbar
    _drawColorbar(canvas, size, minVal, maxVal);
  }

  void _drawVectorField(Canvas canvas, Size size, double Function(double) toScreenX, double Function(double) toScreenY) {
    if (vectorParser == null) return;

    const gridCount = 20;
    final arrowLength = min(size.width, size.height) / gridCount / 2.5;

    // First pass: find max magnitude
    double maxMag = 0;
    for (int i = 0; i <= gridCount; i++) {
      for (int j = 0; j <= gridCount; j++) {
        final x = xMin + (xMax - xMin) * i / gridCount;
        final y = yMin + (yMax - yMin) * j / gridCount;
        final mag = vectorParser!.magnitude(x, y);
        if (mag.isFinite) maxMag = max(maxMag, mag);
      }
    }

    if (maxMag == 0) maxMag = 1;

    // Second pass: draw arrows
    for (int i = 0; i <= gridCount; i++) {
      for (int j = 0; j <= gridCount; j++) {
        final x = xMin + (xMax - xMin) * i / gridCount;
        final y = yMin + (yMax - yMin) * j / gridCount;

        final (nx, ny, _) = vectorParser!.normalized(x, y);
        final mag = vectorParser!.magnitude(x, y);

        if (!mag.isFinite || mag < 1e-10) continue;

        final normalized = mag / maxMag;
        final color = jetColormap(normalized);

        final startX = toScreenX(x);
        final startY = toScreenY(y);
        
        // Note: screen Y is inverted
        final endX = startX + nx * arrowLength;
        final endY = startY - ny * arrowLength;

        final paint = Paint()
          ..color = color
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);

        // Draw arrowhead
        final angle = atan2(-(endY - startY), endX - startX);
        const headLength = 6.0;
        const headAngle = 0.5;

        canvas.drawLine(
          Offset(endX, endY),
          Offset(
            endX - headLength * cos(angle - headAngle),
            endY + headLength * sin(angle - headAngle),
          ),
          paint,
        );
        canvas.drawLine(
          Offset(endX, endY),
          Offset(
            endX - headLength * cos(angle + headAngle),
            endY + headLength * sin(angle + headAngle),
          ),
          paint,
        );
      }
    }

    // Draw colorbar
    _drawColorbar(canvas, size, 0, maxMag);
  }

  void _drawVectorMagnitudeField(Canvas canvas, Size size, double Function(double) toScreenX, double Function(double) toScreenY) {
    if (vectorParser == null) return;

    const gridCount = 25;
    final circleRadius = min(size.width, size.height) / gridCount / 3;

    // First pass: find max magnitude
    double maxMag = 0;
    for (int i = 0; i <= gridCount; i++) {
      for (int j = 0; j <= gridCount; j++) {
        final x = xMin + (xMax - xMin) * i / gridCount;
        final y = yMin + (yMax - yMin) * j / gridCount;
        final mag = vectorParser!.magnitude(x, y);
        if (mag.isFinite) maxMag = max(maxMag, mag);
      }
    }

    if (maxMag == 0) maxMag = 1;

    // Second pass: draw circles
    for (int i = 0; i <= gridCount; i++) {
      for (int j = 0; j <= gridCount; j++) {
        final x = xMin + (xMax - xMin) * i / gridCount;
        final y = yMin + (yMax - yMin) * j / gridCount;

        final mag = vectorParser!.magnitude(x, y);
        if (!mag.isFinite) continue;

        final normalized = mag / maxMag;
        final color = jetColormap(normalized);

        canvas.drawCircle(
          Offset(toScreenX(x), toScreenY(y)),
          circleRadius,
          Paint()..color = color.withOpacity(0.8),
        );
      }
    }

    // Draw colorbar
    _drawColorbar(canvas, size, 0, maxMag);
  }

  void _drawColorbar(Canvas canvas, Size size, double minVal, double maxVal) {
    const barWidth = 15.0;
    const barHeight = 100.0;
    const margin = 10.0;
    
    final barRect = Rect.fromLTWH(
      margin,
      size.height / 2 - barHeight / 2,
      barWidth,
      barHeight,
    );

    // Draw gradient
    for (int i = 0; i < barHeight; i++) {
      final t = 1.0 - i / barHeight;
      final color = jetColormap(t);
      canvas.drawLine(
        Offset(barRect.left, barRect.top + i),
        Offset(barRect.right, barRect.top + i),
        Paint()..color = color,
      );
    }

    // Draw border
    canvas.drawRect(
      barRect,
      Paint()
        ..color = Colors.white54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Draw labels
    final textStyle = TextStyle(color: Colors.white70, fontSize: 10);
    
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

  void _drawLabels(Canvas canvas, Size size, double Function(double) toScreenX, double Function(double) toScreenY) {
    final textStyle = TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12);
    double gridSpacing = _calculateGridSpacing(xMax - xMin);

    for (double x = (xMin / gridSpacing).ceil() * gridSpacing; x <= xMax; x += gridSpacing) {
      if (x.abs() > 0.001) {
        final y0 = toScreenY(0).clamp(20.0, size.height - 20);
        final tp = TextPainter(
          text: TextSpan(text: _formatNumber(x), style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(toScreenX(x) - tp.width / 2, y0 + 8));
      }
    }
    for (double y = (yMin / gridSpacing).ceil() * gridSpacing; y <= yMax; y += gridSpacing) {
      if (y.abs() > 0.001) {
        final x0 = toScreenX(0).clamp(30.0, size.width - 30);
        final tp = TextPainter(
          text: TextSpan(text: _formatNumber(y), style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x0 - tp.width - 8, toScreenY(y) - tp.height / 2));
      }
    }
  }

  String _formatNumber(double n) {
    if (n.abs() < 0.001) return '0';
    if (n == n.roundToDouble() && n.abs() < 100) return n.toInt().toString();
    if (n.abs() >= 100) return n.toStringAsFixed(0);
    if (n.abs() >= 10) return n.toStringAsFixed(1);
    return n.toStringAsFixed(2);
  }

  double _calculateGridSpacing(double range) {
    final magnitude = pow(10, (log(range) / ln10).floor() - 1).toDouble();
    final normalized = range / magnitude;
    if (normalized < 20) return magnitude;
    if (normalized < 50) return magnitude * 2;
    return magnitude * 5;
  }

  @override
  bool shouldRepaint(covariant Plot2DPainter old) =>
      old.xMin != xMin ||
      old.xMax != xMax ||
      old.yMin != yMin ||
      old.yMax != yMax ||
      old.function != function ||
      old.plotMode != plotMode ||
      old.fieldType != fieldType;
}

// ============================================================
// 3D PLOTTING
// ============================================================

class Plot3DScreen extends StatefulWidget {
  final String function;
  final bool is3DFunction;
  final Tool3DMode toolMode;
  final PlotMode plotMode;
  final FieldType fieldType;
  final VectorFieldParser? vectorParser;

  const Plot3DScreen({
    super.key,
    required this.function,
    required this.is3DFunction,
    required this.toolMode,
    required this.plotMode,
    required this.fieldType,
    this.vectorParser,
  });

  @override
  State<Plot3DScreen> createState() => _Plot3DScreenState();
}

class _Plot3DScreenState extends State<Plot3DScreen> {
  double rotationX = 0.6;
  double rotationZ = 0.8;
  double xRange = 5.0;
  double yRange = 5.0;
  double panX = 0.0;
  double panY = 0.0;
  double _lastHorizontalScale = 1.0;
  double _lastVerticalScale = 1.0;

  void resetView() {
    setState(() {
      rotationX = 0.6;
      rotationZ = 0.8;
      xRange = 5.0;
      yRange = 5.0;
      panX = 0.0;
      panY = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onScaleStart: (details) {
            _lastHorizontalScale = 1.0;
            _lastVerticalScale = 1.0;
          },
          onScaleUpdate: (details) {
            setState(() {
              if (details.pointerCount == 2) {
                if (widget.toolMode == Tool3DMode.pan) {
                  panX += details.focalPointDelta.dx;
                  panY += details.focalPointDelta.dy;
                } else {
                  final hScaleDelta = details.horizontalScale / _lastHorizontalScale;
                  final vScaleDelta = details.verticalScale / _lastVerticalScale;
                  _lastHorizontalScale = details.horizontalScale;
                  _lastVerticalScale = details.verticalScale;

                  if ((hScaleDelta - 1.0).abs() > 0.001) {
                    xRange /= hScaleDelta;
                    xRange = xRange.clamp(1.0, 50.0);
                  }
                  if ((vScaleDelta - 1.0).abs() > 0.001) {
                    yRange /= vScaleDelta;
                    yRange = yRange.clamp(1.0, 50.0);
                  }
                }
              } else if (details.pointerCount == 1) {
                rotationZ += details.focalPointDelta.dx * 0.01;
                rotationX += details.focalPointDelta.dy * 0.01;
                rotationX = rotationX.clamp(-pi / 2 + 0.1, pi / 2 - 0.1);
              }
            });
          },
          onScaleEnd: (details) {
            _lastHorizontalScale = 1.0;
            _lastVerticalScale = 1.0;
          },
          child: Container(
            color: Colors.black,
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: Plot3DPainter(
                function: widget.function,
                is3DFunction: widget.is3DFunction,
                rotationX: rotationX,
                rotationZ: rotationZ,
                rangeX: xRange,
                rangeY: yRange,
                panX: panX,
                panY: panY,
                plotMode: widget.plotMode,
                fieldType: widget.fieldType,
                vectorParser: widget.vectorParser,
              ),
            ),
          ),
        );
      },
    );
  }
}

class Point3D {
  final double x, y, z;
  const Point3D(this.x, this.y, this.z);

  Point3D rotateX(double angle) {
    final c = cos(angle), s = sin(angle);
    return Point3D(x, y * c - z * s, y * s + z * c);
  }

  Point3D rotateZ(double angle) {
    final c = cos(angle), s = sin(angle);
    return Point3D(x * c - y * s, x * s + y * c, z);
  }

  Offset project(double focalLength, Size size, double panX, double panY) {
    final scale = focalLength / (focalLength + y);
    return Offset(
      size.width / 2 + x * scale + panX,
      size.height / 2 - z * scale + panY,
    );
  }
}

class Plot3DPainter extends CustomPainter {
  final String function;
  final bool is3DFunction;
  final double rotationX, rotationZ;
  final double rangeX, rangeY;
  final double panX, panY;
  final PlotMode plotMode;
  final FieldType fieldType;
  final VectorFieldParser? vectorParser;

  Plot3DPainter({
    required this.function,
    required this.is3DFunction,
    required this.rotationX,
    required this.rotationZ,
    required this.rangeX,
    required this.rangeY,
    required this.panX,
    required this.panY,
    required this.plotMode,
    required this.fieldType,
    this.vectorParser,
  });

  double get rangeZ => (rangeX + rangeY) / 2;
  double get scaleX => 300.0 / rangeX;
  double get scaleY => 300.0 / rangeY;
  double get scaleZ => 300.0 / rangeZ;

  @override
  void paint(Canvas canvas, Size size) {
    const focalLength = 500.0;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    _drawFloorGrid(canvas, size, focalLength);
    _drawAxes(canvas, size, focalLength);
    _drawFloorBoundary(canvas, size, focalLength);

    if (plotMode == PlotMode.field) {
      if (fieldType == FieldType.vector) {
        _drawVectorMagnitudeField3D(canvas, size, focalLength);
      } else {
        _drawScalarField3D(canvas, size, focalLength);
      }
    } else {
      if (fieldType == FieldType.vector) {
        _drawVectorField3D(canvas, size, focalLength);
      } else if (is3DFunction) {
        _drawSurface(canvas, size, focalLength);
      } else {
        _drawStandingCurve(canvas, size, focalLength);
      }
    }

    canvas.restore();
  }

  double _calculateGridSpacing(double range) {
    final magnitude = pow(10, (log(range * 2) / ln10).floor()).toDouble();
    final normalized = (range * 2) / magnitude;
    if (normalized < 2) return magnitude / 5;
    if (normalized < 5) return magnitude / 2;
    return magnitude;
  }

  void _drawFloorGrid(Canvas canvas, Size size, double focalLength) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1.2;
    final subGridPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 0.8;

    final gridSpacingX = _calculateGridSpacing(rangeX);
    final gridSpacingY = _calculateGridSpacing(rangeY);

    for (double i = -rangeX; i <= rangeX; i += gridSpacingX / 5) {
      var start = Point3D(i * scaleX, -rangeY * scaleY, 0)
          .rotateX(rotationX)
          .rotateZ(rotationZ);
      var end = Point3D(i * scaleX, rangeY * scaleY, 0)
          .rotateX(rotationX)
          .rotateZ(rotationZ);
      _drawClippedLine(canvas, size, focalLength, start, end, subGridPaint);
    }
    for (double i = -rangeY; i <= rangeY; i += gridSpacingY / 5) {
      var start = Point3D(-rangeX * scaleX, i * scaleY, 0)
          .rotateX(rotationX)
          .rotateZ(rotationZ);
      var end = Point3D(rangeX * scaleX, i * scaleY, 0)
          .rotateX(rotationX)
          .rotateZ(rotationZ);
      _drawClippedLine(canvas, size, focalLength, start, end, subGridPaint);
    }
    for (double i = -rangeX; i <= rangeX; i += gridSpacingX) {
      var start = Point3D(i * scaleX, -rangeY * scaleY, 0)
          .rotateX(rotationX)
          .rotateZ(rotationZ);
      var end = Point3D(i * scaleX, rangeY * scaleY, 0)
          .rotateX(rotationX)
          .rotateZ(rotationZ);
      _drawClippedLine(canvas, size, focalLength, start, end, gridPaint);
    }
    for (double i = -rangeY; i <= rangeY; i += gridSpacingY) {
      var start = Point3D(-rangeX * scaleX, i * scaleY, 0)
          .rotateX(rotationX)
          .rotateZ(rotationZ);
      var end = Point3D(rangeX * scaleX, i * scaleY, 0)
          .rotateX(rotationX)
          .rotateZ(rotationZ);
      _drawClippedLine(canvas, size, focalLength, start, end, gridPaint);
    }
  }

  void _drawFloorBoundary(Canvas canvas, Size size, double focalLength) {
    final boundaryPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
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
    final gridSpacingX = _calculateGridSpacing(rangeX);
    final gridSpacingY = _calculateGridSpacing(rangeY);
    final gridSpacingZ = _calculateGridSpacing(rangeZ);

    final axes = [
      (Colors.red, 'X', Point3D(1, 0, 0), gridSpacingX, rangeX, scaleX),
      (Colors.green, 'Y', Point3D(0, 1, 0), gridSpacingY, rangeY, scaleY),
      (Colors.blue, 'Z', Point3D(0, 0, 1), gridSpacingZ, rangeZ, scaleZ),
    ];

    for (final axis in axes) {
      final color = axis.$1;
      final label = axis.$2;
      final dir = axis.$3;
      final gridSpacing = axis.$4;
      final range = axis.$5;
      final scale = axis.$6;

      final axisPaint = Paint()
        ..color = color.withOpacity(0.8)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

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

      _drawClippedLine(canvas, size, focalLength, negPoint, posPoint, axisPaint);

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
        final origin = const Point3D(0, 0, 0).rotateX(rotationX).rotateZ(rotationZ);
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
                arrowProj.dx - normalized.dx * arrowSize + perpendicular.dx * arrowSize / 2,
                arrowProj.dy - normalized.dy * arrowSize + perpendicular.dy * arrowSize / 2,
              )
              ..lineTo(arrowProj.dx, arrowProj.dy)
              ..lineTo(
                arrowProj.dx - normalized.dx * arrowSize - perpendicular.dx * arrowSize / 2,
                arrowProj.dy - normalized.dy * arrowSize - perpendicular.dy * arrowSize / 2,
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

      final tickPaint = Paint()
        ..color = color.withOpacity(0.5)
        ..strokeWidth = 1;
      for (double t = -range; t <= range; t += gridSpacing) {
        if (t.abs() < gridSpacing * 0.1) continue;

        final tickPos = Point3D(
          dir.x * t * scale,
          dir.y * t * scale,
          dir.z * t * scale,
        ).rotateX(rotationX).rotateZ(rotationZ);
        final tickProj = tickPos.project(focalLength, size, panX, panY);

        if (!_isPointInRect(tickProj, Rect.fromLTWH(0, 0, size.width, size.height))) continue;

        const tickLen = 5.0;
        Point3D tick1End, tick2End;

        if (label == 'X') {
          tick1End = Point3D(t * scale, tickLen, 0).rotateX(rotationX).rotateZ(rotationZ);
          tick2End = Point3D(t * scale, 0, tickLen).rotateX(rotationX).rotateZ(rotationZ);
        } else if (label == 'Y') {
          tick1End = Point3D(tickLen, t * scale, 0).rotateX(rotationX).rotateZ(rotationZ);
          tick2End = Point3D(0, t * scale, tickLen).rotateX(rotationX).rotateZ(rotationZ);
        } else {
          tick1End = Point3D(tickLen, 0, t * scale).rotateX(rotationX).rotateZ(rotationZ);
          tick2End = Point3D(0, tickLen, t * scale).rotateX(rotationX).rotateZ(rotationZ);
        }

        canvas.drawLine(tickProj, tick1End.project(focalLength, size, panX, panY), tickPaint);
        canvas.drawLine(tickProj, tick2End.project(focalLength, size, panX, panY), tickPaint);

        Point3D labelPos;
        if (label == 'X') {
          labelPos = Point3D(t * scale, -15, -10).rotateX(rotationX).rotateZ(rotationZ);
        } else if (label == 'Y') {
          labelPos = Point3D(-15, t * scale, -10).rotateX(rotationX).rotateZ(rotationZ);
        } else {
          labelPos = Point3D(-15, -15, t * scale).rotateX(rotationX).rotateZ(rotationZ);
        }

        final labelProj = labelPos.project(focalLength, size, panX, panY);
        if (_isPointInRect(labelProj, Rect.fromLTWH(0, 0, size.width, size.height))) {
          final ltp = TextPainter(
            text: TextSpan(
              text: _formatNumber(t),
              style: TextStyle(color: color.withOpacity(0.6), fontSize: 10),
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
          Point3D(x * scaleX, y * scaleY, z * scaleZ)
              .rotateX(rotationX)
              .rotateZ(rotationZ),
        );
        zRow.add(z);
      }
      points.add(row);
      zValues.add(zRow);
    }

    List<_Quad> quads = [];
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final p1 = points[i][j];
        final p2 = points[i + 1][j];
        final p3 = points[i + 1][j + 1];
        final p4 = points[i][j + 1];

        if (p1 == null || p2 == null || p3 == null || p4 == null) continue;

        final avgY = (p1.y + p2.y + p3.y + p4.y) / 4;
        final avgValue = (zValues[i][j] +
                zValues[i + 1][j] +
                zValues[i + 1][j + 1] +
                zValues[i][j + 1]) /
            4;
        quads.add(_Quad(p1, p2, p3, p4, avgY, avgValue));
      }
    }

    quads.sort((a, b) => b.avgDepth.compareTo(a.avgDepth));

    for (final quad in quads) {
      final o1 = quad.p1.project(focalLength, size, panX, panY);
      final o2 = quad.p2.project(focalLength, size, panX, panY);
      final o3 = quad.p3.project(focalLength, size, panX, panY);
      final o4 = quad.p4.project(focalLength, size, panX, panY);

      final normalizedValue = (quad.avgValue + rangeZ) / (2 * rangeZ);
      final color = _getGradientColor(normalizedValue.clamp(0.0, 1.0));

      final path = Path()
        ..moveTo(o1.dx, o1.dy)
        ..lineTo(o2.dx, o2.dy)
        ..lineTo(o3.dx, o3.dy)
        ..lineTo(o4.dx, o4.dy)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withOpacity(0.7)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withOpacity(0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
    }
  }

  void _drawStandingCurve(Canvas canvas, Size size, double focalLength) {
    final parser = MathParser(function);
    const steps = 300;

    final paint = Paint()
      ..color = const Color(0xFF58C4DD)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final shadowPaint = Paint()
      ..color = const Color(0xFF58C4DD).withOpacity(0.2)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final verticalPaint = Paint()
      ..color = const Color(0xFF58C4DD).withOpacity(0.1)
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

      final point = Point3D(x * scaleX, 0, z * scaleZ)
          .rotateX(rotationX)
          .rotateZ(rotationZ);
      final shadowPoint = Point3D(x * scaleX, 0, 0)
          .rotateX(rotationX)
          .rotateZ(rotationZ);
      final proj = point.project(focalLength, size, panX, panY);
      final shadowProj = shadowPoint.project(focalLength, size, panX, panY);

      if (lastZ != null && (z - lastZ!).abs() > rangeZ * 0.5) started = false;

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
    const gridCount = 15;

    // Collect all points with their values
    List<_FieldPoint3D> points = [];
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

            final point3D = Point3D(x * scaleX, y * scaleY, z * scaleZ)
                .rotateX(rotationX)
                .rotateZ(rotationZ);

            points.add(_FieldPoint3D(point3D, val));
          } catch (e) {}
        }
      }
    }

    if (points.isEmpty) return;
    if (minVal == maxVal) maxVal = minVal + 1;

    // Sort by depth (y after rotation) for proper rendering
    points.sort((a, b) => b.point.y.compareTo(a.point.y));

    // Draw spheres
    for (final fp in points) {
      final proj = fp.point.project(focalLength, size, panX, panY);
      if (!_isPointInRect(proj, Rect.fromLTWH(0, 0, size.width, size.height))) continue;

      final normalized = (fp.value - minVal) / (maxVal - minVal);
      final color = jetColormap(normalized);

      // Size based on depth
      final depthScale = focalLength / (focalLength + fp.point.y);
      final radius = 6.0 * depthScale;

      // Draw sphere with gradient effect
      final paint = Paint()..color = color.withOpacity(0.8);
      canvas.drawCircle(proj, radius, paint);

      // Highlight
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(proj.dx - radius * 0.3, proj.dy - radius * 0.3),
        radius * 0.3,
        highlightPaint,
      );
    }

    // Draw colorbar
    _drawColorbar3D(canvas, size, minVal, maxVal);
  }

  void _drawVectorField3D(Canvas canvas, Size size, double focalLength) {
    if (vectorParser == null) return;

    const gridCount = 10;
    final bool is3DVector = vectorParser!.is3D;

    // Collect all arrows
    List<_Arrow3D> arrows = [];
    double maxMag = 0;

    if (is3DVector) {
      // 3D vector field - sample in 3D space
      for (int i = 0; i <= gridCount; i++) {
        for (int j = 0; j <= gridCount; j++) {
          for (int k = 0; k <= gridCount; k++) {
            final x = -rangeX + (2 * rangeX * i / gridCount);
            final y = -rangeY + (2 * rangeY * j / gridCount);
            final z = -rangeZ + (2 * rangeZ * k / gridCount);

            final mag = vectorParser!.magnitude(x, y, z);
            if (!mag.isFinite || mag < 1e-10) continue;

            maxMag = max(maxMag, mag);

            final (nx, ny, nz) = vectorParser!.normalized(x, y, z);
            final startPoint = Point3D(x * scaleX, y * scaleY, z * scaleZ);
            
            arrows.add(_Arrow3D(startPoint, nx, ny, nz, mag));
          }
        }
      }
    } else {
      // 2D vector field on XY plane
      for (int i = 0; i <= gridCount * 2; i++) {
        for (int j = 0; j <= gridCount * 2; j++) {
          final x = -rangeX + (2 * rangeX * i / (gridCount * 2));
          final y = -rangeY + (2 * rangeY * j / (gridCount * 2));

          final mag = vectorParser!.magnitude(x, y, 0);
          if (!mag.isFinite || mag < 1e-10) continue;

          maxMag = max(maxMag, mag);

          final (nx, ny, _) = vectorParser!.normalized(x, y, 0);
          final startPoint = Point3D(x * scaleX, y * scaleY, 0);
          
          arrows.add(_Arrow3D(startPoint, nx, ny, 0, mag));
        }
      }
    }

    if (arrows.isEmpty || maxMag == 0) return;

    // Sort by depth
    arrows.sort((a, b) {
      final aRotated = a.start.rotateX(rotationX).rotateZ(rotationZ);
      final bRotated = b.start.rotateX(rotationX).rotateZ(rotationZ);
      return bRotated.y.compareTo(aRotated.y);
    });

    // Draw arrows
    const arrowLength = 15.0;
    for (final arrow in arrows) {
      final startRotated = arrow.start.rotateX(rotationX).rotateZ(rotationZ);
      final startProj = startRotated.project(focalLength, size, panX, panY);

      if (!_isPointInRect(startProj, Rect.fromLTWH(-50, -50, size.width + 100, size.height + 100))) continue;

      // Calculate end point in 3D space
      final endPoint = Point3D(
        arrow.start.x + arrow.dx * arrowLength,
        arrow.start.y + arrow.dy * arrowLength,
        arrow.start.z + arrow.dz * arrowLength,
      );
      final endRotated = endPoint.rotateX(rotationX).rotateZ(rotationZ);
      final endProj = endRotated.project(focalLength, size, panX, panY);

      final normalized = arrow.magnitude / maxMag;
      final color = jetColormap(normalized);

      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(startProj, endProj, paint);

      // Draw arrowhead
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
            endProj.dx - headLength * (ux * cos(headAngle) - uy * sin(headAngle)),
            endProj.dy - headLength * (ux * sin(headAngle) + uy * cos(headAngle)),
          ),
          paint,
        );
        canvas.drawLine(
          endProj,
          Offset(
            endProj.dx - headLength * (ux * cos(-headAngle) - uy * sin(-headAngle)),
            endProj.dy - headLength * (ux * sin(-headAngle) + uy * cos(-headAngle)),
          ),
          paint,
        );
      }
    }

    // Draw colorbar
    _drawColorbar3D(canvas, size, 0, maxMag);
  }

  void _drawVectorMagnitudeField3D(Canvas canvas, Size size, double focalLength) {
    if (vectorParser == null) return;

    const gridCount = 12;
    final bool is3DVector = vectorParser!.is3D;

    List<_FieldPoint3D> points = [];
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

            final point3D = Point3D(x * scaleX, y * scaleY, z * scaleZ)
                .rotateX(rotationX)
                .rotateZ(rotationZ);

            points.add(_FieldPoint3D(point3D, mag));
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

          final point3D = Point3D(x * scaleX, y * scaleY, 0)
              .rotateX(rotationX)
              .rotateZ(rotationZ);

          points.add(_FieldPoint3D(point3D, mag));
        }
      }
    }

    if (points.isEmpty || maxMag == 0) return;

    // Sort by depth
    points.sort((a, b) => b.point.y.compareTo(a.point.y));

    // Draw spheres
    for (final fp in points) {
      final proj = fp.point.project(focalLength, size, panX, panY);
      if (!_isPointInRect(proj, Rect.fromLTWH(0, 0, size.width, size.height))) continue;

      final normalized = fp.value / maxMag;
      final color = jetColormap(normalized);

      final depthScale = focalLength / (focalLength + fp.point.y);
      final radius = 6.0 * depthScale;

      canvas.drawCircle(proj, radius, Paint()..color = color.withOpacity(0.8));

      // Highlight
      canvas.drawCircle(
        Offset(proj.dx - radius * 0.3, proj.dy - radius * 0.3),
        radius * 0.3,
        Paint()..color = Colors.white.withOpacity(0.3),
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
        ..color = Colors.white54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final textStyle = TextStyle(color: Colors.white70, fontSize: 10);

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

  Color _getGradientColor(double t) {
    final colors = [
      const Color(0xFF1E88E5),
      const Color(0xFF00ACC1),
      const Color(0xFF00897B),
      const Color(0xFF43A047),
      const Color(0xFFFDD835),
    ];
    final scaledT = t * (colors.length - 1);
    final index = scaledT.floor().clamp(0, colors.length - 2);
    return Color.lerp(colors[index], colors[index + 1], scaledT - index)!;
  }

  @override
  bool shouldRepaint(covariant Plot3DPainter old) =>
      old.rotationX != rotationX ||
      old.rotationZ != rotationZ ||
      old.rangeX != rangeX ||
      old.rangeY != rangeY ||
      old.panX != panX ||
      old.panY != panY ||
      old.function != function ||
      old.is3DFunction != is3DFunction ||
      old.plotMode != plotMode ||
      old.fieldType != fieldType;
}

class _Quad {
  final Point3D p1, p2, p3, p4;
  final double avgDepth, avgValue;
  _Quad(this.p1, this.p2, this.p3, this.p4, this.avgDepth, this.avgValue);
}

class _FieldPoint3D {
  final Point3D point;
  final double value;
  _FieldPoint3D(this.point, this.value);
}

class _Arrow3D {
  final Point3D start;
  final double dx, dy, dz;
  final double magnitude;
  _Arrow3D(this.start, this.dx, this.dy, this.dz, this.magnitude);
}