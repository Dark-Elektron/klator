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

  double evaluate(double x, [double y = 0]) {
    _pos = 0;
    _nextToken();
    final result = _parseExpression(x, y);
    return result;
  }

  bool get usesY {
    return expression.contains(RegExp(r'\by\b'));
  }

  void _nextToken() {
    while (_pos < expression.length && expression[_pos] == ' ') {
      _pos++;
    }

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
          expression[_pos].contains(RegExp(r'[0-9.]'))) {
        _pos++;
      }
      _currentToken = expression.substring(start, _pos);
      return;
    }

    if (char.contains(RegExp(r'[a-zA-Z]'))) {
      final start = _pos;
      while (_pos < expression.length &&
          expression[_pos].contains(RegExp(r'[a-zA-Z0-9]'))) {
        _pos++;
      }
      _currentToken = expression.substring(start, _pos);
      return;
    }

    _pos++;
    _nextToken();
  }

  double _parseExpression(double x, double y) {
    var result = _parseTerm(x, y);

    while (_currentToken == '+' || _currentToken == '-') {
      final op = _currentToken;
      _nextToken();
      final term = _parseTerm(x, y);
      if (op == '+') {
        result += term;
      } else {
        result -= term;
      }
    }

    return result;
  }

  double _parseTerm(double x, double y) {
    var result = _parsePower(x, y);

    while (_currentToken == '*' || _currentToken == '/') {
      final op = _currentToken;
      _nextToken();
      final factor = _parsePower(x, y);
      if (op == '*') {
        result *= factor;
      } else {
        result /= factor;
      }
    }

    return result;
  }

  double _parsePower(double x, double y) {
    var result = _parseUnary(x, y);

    if (_currentToken == '^') {
      _nextToken();
      final exponent = _parseUnary(x, y);
      result = pow(result, exponent).toDouble();
    }

    return result;
  }

  double _parseUnary(double x, double y) {
    if (_currentToken == '-') {
      _nextToken();
      return -_parseFactor(x, y);
    }
    if (_currentToken == '+') {
      _nextToken();
    }
    return _parseFactor(x, y);
  }

  double _parseFactor(double x, double y) {
    if (_currentToken == '(') {
      _nextToken();
      final result = _parseExpression(x, y);
      if (_currentToken == ')') {
        _nextToken();
      }
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

      if (token == 'pi') return pi;
      if (token == 'e') return e;

      if (_currentToken == '(') {
        _nextToken();
        final arg1 = _parseExpression(x, y);
        double? arg2;

        if (_currentToken == ',') {
          _nextToken();
          arg2 = _parseExpression(x, y);
        }

        if (_currentToken == ')') {
          _nextToken();
        }

        return _evaluateFunction(token, arg1, arg2);
      }
    }

    return 0;
  }

  double _evaluateFunction(String name, double arg1, [double? arg2]) {
    switch (name) {
      case 'sin':
        return sin(arg1);
      case 'cos':
        return cos(arg1);
      case 'tan':
        return tan(arg1);
      case 'asin':
        return asin(arg1);
      case 'acos':
        return acos(arg1);
      case 'atan':
        return atan(arg1);
      case 'atan2':
        return atan2(arg1, arg2 ?? 0);
      case 'sinh':
        return (exp(arg1) - exp(-arg1)) / 2;
      case 'cosh':
        return (exp(arg1) + exp(-arg1)) / 2;
      case 'tanh':
        return (exp(arg1) - exp(-arg1)) / (exp(arg1) + exp(-arg1));
      case 'exp':
        return exp(arg1);
      case 'log':
        return log(arg1);
      case 'ln':
        return log(arg1);
      case 'log10':
        return log(arg1) / ln10;
      case 'sqrt':
        return sqrt(arg1);
      case 'abs':
        return arg1.abs();
      case 'floor':
        return arg1.floorToDouble();
      case 'ceil':
        return arg1.ceilToDouble();
      case 'round':
        return arg1.roundToDouble();
      case 'sign':
        return arg1.sign;
      case 'min':
        return min(arg1, arg2 ?? arg1);
      case 'max':
        return max(arg1, arg2 ?? arg1);
      case 'pow':
        return pow(arg1, arg2 ?? 1).toDouble();
      case 'mod':
        return arg1 % (arg2 ?? 1);
      default:
        return 0;
    }
  }
}

// ============================================================
// HOME SCREEN
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _functionController = TextEditingController();
  String _currentFunction = 'sin(x)';
  String? _errorMessage;
  bool _is3DFunction = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _functionController.text = _currentFunction;
    _parseFunction();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _functionController.dispose();
    super.dispose();
  }

  void _parseFunction() {
    final expr = _functionController.text.trim();
    if (expr.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a function';
      });
      return;
    }

    try {
      final parser = MathParser(expr);
      parser.evaluate(1, 1);
      setState(() {
        _currentFunction = expr;
        _is3DFunction = parser.usesY;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Invalid function syntax';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manim-Style Math Plotter'),
        backgroundColor: const Color(0xFF16213e),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.tealAccent,
          tabs: const [
            Tab(icon: Icon(Icons.show_chart), text: '2D Plot'),
            Tab(icon: Icon(Icons.threed_rotation), text: '3D Plot'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF16213e),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      _is3DFunction ? 'f(x, y) = ' : 'f(x) = ',
                      style: const TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _functionController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g., sin(x), x^2, sin(sqrt(x^2+y^2))',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontFamily: 'monospace',
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0f0f23),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.play_arrow,
                                color: Colors.tealAccent),
                            onPressed: _parseFunction,
                          ),
                        ),
                        onSubmitted: (_) => _parseFunction(),
                      ),
                    ),
                  ],
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildExampleChip('sin(x)'),
                      _buildExampleChip('x^2'),
                      _buildExampleChip('cos(x)*sin(y)'),
                      _buildExampleChip('sin(sqrt(x^2+y^2))'),
                      _buildExampleChip('exp(-x^2-y^2)'),
                      _buildExampleChip('x^2-y^2'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                Plot2DScreen(
                  function: _currentFunction,
                  is3DFunction: _is3DFunction,
                ),
                Plot3DScreen(
                  function: _currentFunction,
                  is3DFunction: _is3DFunction,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleChip(String expr) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(
          expr,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        ),
        backgroundColor: Colors.white.withOpacity(0.05),
        onPressed: () {
          _functionController.text = expr;
          _parseFunction();
        },
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

  const Plot2DScreen({
    super.key,
    required this.function,
    required this.is3DFunction,
  });

  @override
  State<Plot2DScreen> createState() => _Plot2DScreenState();
}

class _Plot2DScreenState extends State<Plot2DScreen> {
  double xMin = -5, xMax = 5;
  double yMin = -3, yMax = 3;
  double _lastScale = 1.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.is3DFunction)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '2D plot shows f(x, 0) — switch to 3D for full surface',
                    style:
                        TextStyle(color: Colors.orange.shade200, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onScaleStart: (details) {
                    _lastScale = 1.0;
                  },
                  onScaleUpdate: (details) {
                    setState(() {
                      if ((details.scale - 1.0).abs() > 0.01) {
                        final scaleDelta = details.scale / _lastScale;
                        _lastScale = details.scale;
                        final zoomFactor = 1.0 + (scaleDelta - 1.0) * 0.3;
                        final factor = 1 / zoomFactor;
                        final xCenter = (xMin + xMax) / 2;
                        final yCenter = (yMin + yMax) / 2;
                        final xRange = (xMax - xMin) * factor / 2;
                        final yRange = (yMax - yMin) * factor / 2;
                        xMin = xCenter - xRange;
                        xMax = xCenter + xRange;
                        yMin = yCenter - yRange;
                        yMax = yCenter + yRange;
                      }

                      if (details.pointerCount == 1) {
                        final dx = details.focalPointDelta.dx;
                        final dy = details.focalPointDelta.dy;
                        final xShift =
                            -dx * (xMax - xMin) / constraints.maxWidth;
                        final yShift =
                            dy * (yMax - yMin) / constraints.maxHeight;
                        xMin += xShift;
                        xMax += xShift;
                        yMin += yShift;
                        yMax += yShift;
                      }
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0f0f23),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CustomPaint(
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                        painter: Plot2DPainter(
                          function: widget.function,
                          xMin: xMin,
                          xMax: xMax,
                          yMin: yMin,
                          yMax: yMax,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                xMin = -5;
                xMax = 5;
                yMin = -3;
                yMax = 3;
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Reset View'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent.withOpacity(0.2),
              foregroundColor: Colors.tealAccent,
            ),
          ),
        ),
      ],
    );
  }
}

class Plot2DPainter extends CustomPainter {
  final String function;
  final double xMin, xMax, yMin, yMax;

  Plot2DPainter({
    required this.function,
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double toScreenX(double x) => (x - xMin) / (xMax - xMin) * size.width;
    double toScreenY(double y) =>
        size.height - (y - yMin) / (yMax - yMin) * size.height;

    _drawGrid(canvas, size, toScreenX, toScreenY);
    _drawAxes(canvas, size, toScreenX, toScreenY);
    _drawFunction(canvas, size, toScreenX, toScreenY);
    _drawLabels(canvas, size, toScreenX, toScreenY);
  }

  void _drawGrid(Canvas canvas, Size size, double Function(double) toScreenX,
      double Function(double) toScreenY) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    final subGridPaint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..strokeWidth = 0.5;

    double gridSpacing = _calculateGridSpacing(xMax - xMin);

    for (double x = (xMin / gridSpacing).floor() * gridSpacing;
        x <= xMax;
        x += gridSpacing / 5) {
      final sx = toScreenX(x);
      canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), subGridPaint);
    }
    for (double y = (yMin / gridSpacing).floor() * gridSpacing;
        y <= yMax;
        y += gridSpacing / 5) {
      final sy = toScreenY(y);
      canvas.drawLine(Offset(0, sy), Offset(size.width, sy), subGridPaint);
    }

    for (double x = (xMin / gridSpacing).floor() * gridSpacing;
        x <= xMax;
        x += gridSpacing) {
      final sx = toScreenX(x);
      canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), gridPaint);
    }
    for (double y = (yMin / gridSpacing).floor() * gridSpacing;
        y <= yMax;
        y += gridSpacing) {
      final sy = toScreenY(y);
      canvas.drawLine(Offset(0, sy), Offset(size.width, sy), gridPaint);
    }
  }

  void _drawAxes(Canvas canvas, Size size, double Function(double) toScreenX,
      double Function(double) toScreenY) {
    final axisPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 2;

    if (yMin <= 0 && yMax >= 0) {
      final y0 = toScreenY(0);
      canvas.drawLine(Offset(0, y0), Offset(size.width, y0), axisPaint);

      final arrowPaint = Paint()
        ..color = Colors.white.withOpacity(0.6)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final arrowPath = Path()
        ..moveTo(size.width - 10, y0 - 5)
        ..lineTo(size.width, y0)
        ..lineTo(size.width - 10, y0 + 5);
      canvas.drawPath(arrowPath, arrowPaint);
    }

    if (xMin <= 0 && xMax >= 0) {
      final x0 = toScreenX(0);
      canvas.drawLine(Offset(x0, 0), Offset(x0, size.height), axisPaint);

      final arrowPaint = Paint()
        ..color = Colors.white.withOpacity(0.6)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final arrowPath = Path()
        ..moveTo(x0 - 5, 10)
        ..lineTo(x0, 0)
        ..lineTo(x0 + 5, 10);
      canvas.drawPath(arrowPath, arrowPaint);
    }

    final tickPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 1;

    double gridSpacing = _calculateGridSpacing(xMax - xMin);

    for (double x = (xMin / gridSpacing).ceil() * gridSpacing;
        x <= xMax;
        x += gridSpacing) {
      if (x.abs() > 0.001) {
        final sx = toScreenX(x);
        final y0 = toScreenY(0).clamp(10.0, size.height - 10);
        canvas.drawLine(Offset(sx, y0 - 5), Offset(sx, y0 + 5), tickPaint);
      }
    }

    for (double y = (yMin / gridSpacing).ceil() * gridSpacing;
        y <= yMax;
        y += gridSpacing) {
      if (y.abs() > 0.001) {
        final sy = toScreenY(y);
        final x0 = toScreenX(0).clamp(10.0, size.width - 10);
        canvas.drawLine(Offset(x0 - 5, sy), Offset(x0 + 5, sy), tickPaint);
      }
    }
  }

  void _drawFunction(Canvas canvas, Size size,
      double Function(double) toScreenX, double Function(double) toScreenY) {
    final paint = Paint()
      ..color = const Color(0xFF58C4DD)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final glowPaint = Paint()
      ..color = const Color(0xFF58C4DD).withOpacity(0.3)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final parser = MathParser(function);
    final path = Path();
    const steps = 1000;
    final dx = (xMax - xMin) / steps;

    bool started = false;
    double? lastY;

    for (int i = 0; i <= steps; i++) {
      final x = xMin + i * dx;
      double y;
      try {
        y = parser.evaluate(x, 0);
      } catch (e) {
        started = false;
        lastY = null;
        continue;
      }

      if (y.isFinite && y.abs() < 1000) {
        final sy = toScreenY(y);
        final sx = toScreenX(x);

        if (lastY != null && (y - lastY!).abs() > (yMax - yMin) * 0.5) {
          started = false;
        }

        if (!started) {
          path.moveTo(sx, sy);
          started = true;
        } else {
          path.lineTo(sx, sy);
        }
        lastY = y;
      } else {
        started = false;
        lastY = null;
      }
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);
  }

  void _drawLabels(Canvas canvas, Size size, double Function(double) toScreenX,
      double Function(double) toScreenY) {
    final textStyle = TextStyle(
      color: Colors.white.withOpacity(0.6),
      fontSize: 12,
    );

    double gridSpacing = _calculateGridSpacing(xMax - xMin);

    for (double x = (xMin / gridSpacing).ceil() * gridSpacing;
        x <= xMax;
        x += gridSpacing) {
      if (x.abs() > 0.001) {
        final sx = toScreenX(x);
        final y0 = toScreenY(0).clamp(20.0, size.height - 20);

        final textSpan = TextSpan(text: _formatNumber(x), style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(sx - textPainter.width / 2, y0 + 8),
        );
      }
    }

    for (double y = (yMin / gridSpacing).ceil() * gridSpacing;
        y <= yMax;
        y += gridSpacing) {
      if (y.abs() > 0.001) {
        final sy = toScreenY(y);
        final x0 = toScreenX(0).clamp(30.0, size.width - 30);

        final textSpan = TextSpan(text: _formatNumber(y), style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(x0 - textPainter.width - 8, sy - textPainter.height / 2),
        );
      }
    }
  }

  String _formatNumber(double n) {
    if (n.abs() < 0.001) return '0';
    if (n == n.roundToDouble() && n.abs() < 100) {
      return n.toInt().toString();
    }
    return n.toStringAsFixed(1);
  }

  double _calculateGridSpacing(double range) {
    final magnitude = pow(10, (log(range) / ln10).floor() - 1).toDouble();
    final normalized = range / magnitude;
    if (normalized < 20) return magnitude;
    if (normalized < 50) return magnitude * 2;
    return magnitude * 5;
  }

  @override
  bool shouldRepaint(covariant Plot2DPainter oldDelegate) {
    return oldDelegate.xMin != xMin ||
        oldDelegate.xMax != xMax ||
        oldDelegate.yMin != yMin ||
        oldDelegate.yMax != yMax ||
        oldDelegate.function != function;
  }
}

// ============================================================
// 3D PLOTTING
// ============================================================

class Plot3DScreen extends StatefulWidget {
  final String function;
  final bool is3DFunction;

  const Plot3DScreen({
    super.key,
    required this.function,
    required this.is3DFunction,
  });

  @override
  State<Plot3DScreen> createState() => _Plot3DScreenState();
}

class _Plot3DScreenState extends State<Plot3DScreen> {
  double rotationX = 0.6;
  double rotationZ = 0.8;
  
  // Now using range similar to 2D plot
  double range = 5.0; // This is like (xMax - xMin) / 2
  
  double _lastScale = 1.0;
  int _pointerCount = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onScaleStart: (details) {
                    _lastScale = 1.0;
                    _pointerCount = details.pointerCount;
                  },
                  onScaleUpdate: (details) {
                    setState(() {
                      _pointerCount = details.pointerCount;

                      // Zoom changes the range (like 2D plot)
                      if (_pointerCount >= 2 &&
                          (details.scale - 1.0).abs() > 0.01) {
                        final scaleDelta = details.scale / _lastScale;
                        _lastScale = details.scale;
                        
                        // Zooming in = smaller range, zooming out = larger range
                        final zoomFactor = 1.0 + (scaleDelta - 1.0) * 0.3;
                        range = range / zoomFactor;
                        range = range.clamp(1.0, 50.0);
                      }

                      // Rotation
                      if (_pointerCount == 1) {
                        rotationZ += details.focalPointDelta.dx * 0.01;
                        rotationX += details.focalPointDelta.dy * 0.01;
                        rotationX =
                            rotationX.clamp(-pi / 2 + 0.1, pi / 2 - 0.1);
                      }
                    });
                  },
                  onScaleEnd: (details) {
                    _lastScale = 1.0;
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0f0f23),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CustomPaint(
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                        painter: Plot3DPainter(
                          function: widget.function,
                          is3DFunction: widget.is3DFunction,
                          rotationX: rotationX,
                          rotationZ: rotationZ,
                          range: range,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildInfoChip(Icons.touch_app, 'Drag to rotate'),
                const SizedBox(width: 8),
                _buildInfoChip(Icons.pinch, 'Pinch to zoom'),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      rotationX = 0.6;
                      rotationZ = 0.8;
                      range = 5.0;
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reset'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent.withOpacity(0.2),
                    foregroundColor: Colors.tealAccent,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white54),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
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

  Offset project(double focalLength, Size size) {
    final scale = focalLength / (focalLength + y);
    return Offset(
      size.width / 2 + x * scale,
      size.height / 2 - z * scale,
    );
  }
}

class Plot3DPainter extends CustomPainter {
  final String function;
  final bool is3DFunction;
  final double rotationX, rotationZ;
  final double range; // The visible range in math units

  Plot3DPainter({
    required this.function,
    required this.is3DFunction,
    required this.rotationX,
    required this.rotationZ,
    required this.range,
  });

  // Convert math units to screen units
  // We scale so that the range fits nicely on screen
  double get scale => 150.0 / range;

  @override
  void paint(Canvas canvas, Size size) {
    const focalLength = 500.0;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    _drawFloorGrid(canvas, size, focalLength);
    _drawAxes(canvas, size, focalLength);

    if (is3DFunction) {
      _drawSurface(canvas, size, focalLength);
    } else {
      _drawStandingCurve(canvas, size, focalLength);
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
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;

    final subGridPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 0.5;

    final gridSpacing = _calculateGridSpacing(range);
    final subGridSpacing = gridSpacing / 5;

    // Draw sub-grid
    for (double i = -range; i <= range; i += subGridSpacing) {
      // Lines parallel to Y
      var start = Point3D(i * scale, -range * scale, 0)
          .rotateX(rotationX)
          .rotateZ(rotationZ);
      var end = Point3D(i * scale, range * scale, 0)
          .rotateX(rotationX)
          .rotateZ(rotationZ);

      _drawClippedLine(canvas, size, focalLength, start, end, subGridPaint);

      // Lines parallel to X
      start = Point3D(-range * scale, i * scale, 0)
          .rotateX(rotationX)
          .rotateZ(rotationZ);
      end = Point3D(range * scale, i * scale, 0)
          .rotateX(rotationX)
          .rotateZ(rotationZ);

      _drawClippedLine(canvas, size, focalLength, start, end, subGridPaint);
    }

    // Draw main grid
    for (double i = -range; i <= range; i += gridSpacing) {
      // Lines parallel to Y
      var start = Point3D(i * scale, -range * scale, 0)
          .rotateX(rotationX)
          .rotateZ(rotationZ);
      var end = Point3D(i * scale, range * scale, 0)
          .rotateX(rotationX)
          .rotateZ(rotationZ);

      _drawClippedLine(canvas, size, focalLength, start, end, gridPaint);

      // Lines parallel to X
      start = Point3D(-range * scale, i * scale, 0)
          .rotateX(rotationX)
          .rotateZ(rotationZ);
      end = Point3D(range * scale, i * scale, 0)
          .rotateX(rotationX)
          .rotateZ(rotationZ);

      _drawClippedLine(canvas, size, focalLength, start, end, gridPaint);
    }
  }

  void _drawClippedLine(Canvas canvas, Size size, double focalLength,
      Point3D start, Point3D end, Paint paint) {
    final startProj = start.project(focalLength, size);
    final endProj = end.project(focalLength, size);

    final clipped = _clipLineToRect(
        startProj, endProj, Rect.fromLTWH(0, 0, size.width, size.height));

    if (clipped != null) {
      canvas.drawLine(clipped.$1, clipped.$2, paint);
    }
  }

  void _drawAxes(Canvas canvas, Size size, double focalLength) {
    final gridSpacing = _calculateGridSpacing(range);

    // Extend axes well beyond visible range
    final axisExtent = range * 2;

    final axes = [
      (Colors.red, 'X', Point3D(1, 0, 0)),
      (Colors.green, 'Y', Point3D(0, 1, 0)),
      (Colors.blue, 'Z', Point3D(0, 0, 1)),
    ];

    for (final axis in axes) {
      final color = axis.$1;
      final label = axis.$2;
      final dir = axis.$3;

      final axisPaint = Paint()
        ..color = color.withOpacity(0.8)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      // Axis line from -extent to +extent
      final negPoint = Point3D(
        -dir.x * axisExtent * scale,
        -dir.y * axisExtent * scale,
        -dir.z * axisExtent * scale,
      ).rotateX(rotationX).rotateZ(rotationZ);

      final posPoint = Point3D(
        dir.x * axisExtent * scale,
        dir.y * axisExtent * scale,
        dir.z * axisExtent * scale,
      ).rotateX(rotationX).rotateZ(rotationZ);

      _drawClippedLine(canvas, size, focalLength, negPoint, posPoint, axisPaint);

      // Arrow at positive end (draw near edge of visible range)
      final arrowPos = Point3D(
        dir.x * range * 0.9 * scale,
        dir.y * range * 0.9 * scale,
        dir.z * range * 0.9 * scale,
      ).rotateX(rotationX).rotateZ(rotationZ);

      final arrowProj = arrowPos.project(focalLength, size);

      if (_isPointInRect(
          arrowProj, Rect.fromLTWH(-20, -20, size.width + 40, size.height + 40))) {
        final origin =
            const Point3D(0, 0, 0).rotateX(rotationX).rotateZ(rotationZ);
        final originProj = origin.project(focalLength, size);

        final direction = Offset(
          arrowProj.dx - originProj.dx,
          arrowProj.dy - originProj.dy,
        );
        final length = direction.distance;

        if (length > 0) {
          final normalized = direction / length;
          final perpendicular = Offset(-normalized.dy, normalized.dx);
          const arrowSize = 10.0;

          final arrowPath = Path()
            ..moveTo(
                arrowProj.dx -
                    normalized.dx * arrowSize +
                    perpendicular.dx * arrowSize / 2,
                arrowProj.dy -
                    normalized.dy * arrowSize +
                    perpendicular.dy * arrowSize / 2)
            ..lineTo(arrowProj.dx, arrowProj.dy)
            ..lineTo(
                arrowProj.dx -
                    normalized.dx * arrowSize -
                    perpendicular.dx * arrowSize / 2,
                arrowProj.dy -
                    normalized.dy * arrowSize -
                    perpendicular.dy * arrowSize / 2);

          canvas.drawPath(arrowPath, axisPaint..style = PaintingStyle.stroke);
        }

        // Label
        final textSpan = TextSpan(
          text: label,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(arrowProj.dx + 8, arrowProj.dy - 8),
        );
      }

      // Tick marks
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

        final tickProj = tickPos.project(focalLength, size);

        if (!_isPointInRect(
            tickProj, Rect.fromLTWH(0, 0, size.width, size.height))) {
          continue;
        }

        // Draw small perpendicular ticks
        const tickLen = 5.0;

        Point3D tick1End, tick2End;

        if (label == 'X') {
          tick1End = Point3D(t * scale, tickLen, 0)
              .rotateX(rotationX)
              .rotateZ(rotationZ);
          tick2End = Point3D(t * scale, 0, tickLen)
              .rotateX(rotationX)
              .rotateZ(rotationZ);
        } else if (label == 'Y') {
          tick1End = Point3D(tickLen, t * scale, 0)
              .rotateX(rotationX)
              .rotateZ(rotationZ);
          tick2End = Point3D(0, t * scale, tickLen)
              .rotateX(rotationX)
              .rotateZ(rotationZ);
        } else {
          tick1End = Point3D(tickLen, 0, t * scale)
              .rotateX(rotationX)
              .rotateZ(rotationZ);
          tick2End = Point3D(0, tickLen, t * scale)
              .rotateX(rotationX)
              .rotateZ(rotationZ);
        }

        canvas.drawLine(
            tickProj, tick1End.project(focalLength, size), tickPaint);
        canvas.drawLine(
            tickProj, tick2End.project(focalLength, size), tickPaint);

        // Tick label
        final textStyle = TextStyle(
          color: color.withOpacity(0.6),
          fontSize: 10,
        );

        final value = t;
        final textSpan =
            TextSpan(text: _formatNumber(value), style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        // Offset label position
        Point3D labelPos;
        if (label == 'X') {
          labelPos = Point3D(t * scale, -15, -10)
              .rotateX(rotationX)
              .rotateZ(rotationZ);
        } else if (label == 'Y') {
          labelPos = Point3D(-15, t * scale, -10)
              .rotateX(rotationX)
              .rotateZ(rotationZ);
        } else {
          labelPos = Point3D(-15, -15, t * scale)
              .rotateX(rotationX)
              .rotateZ(rotationZ);
        }

        final labelProj = labelPos.project(focalLength, size);

        if (_isPointInRect(
            labelProj, Rect.fromLTWH(0, 0, size.width, size.height))) {
          textPainter.paint(
            canvas,
            Offset(labelProj.dx - textPainter.width / 2,
                labelProj.dy - textPainter.height / 2),
          );
        }
      }
    }
  }

  String _formatNumber(double n) {
    if (n.abs() < 0.001) return '0';
    if (n == n.roundToDouble() && n.abs() < 1000) {
      return n.toInt().toString();
    }
    if (n.abs() >= 100) {
      return n.toInt().toString();
    }
    if (n.abs() >= 10) {
      return n.toStringAsFixed(1);
    }
    return n.toStringAsFixed(2);
  }

  (Offset, Offset)? _clipLineToRect(Offset p1, Offset p2, Rect rect) {
    double x1 = p1.dx, y1 = p1.dy;
    double x2 = p2.dx, y2 = p2.dy;

    const inside = 0;
    const left = 1;
    const right = 2;
    const bottom = 4;
    const top = 8;

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

    int code1 = computeCode(x1, y1);
    int code2 = computeCode(x2, y2);

    while (true) {
      if ((code1 | code2) == 0) {
        return (Offset(x1, y1), Offset(x2, y2));
      } else if ((code1 & code2) != 0) {
        return null;
      } else {
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
  }

  bool _isPointInRect(Offset point, Rect rect) {
    return point.dx >= rect.left &&
        point.dx <= rect.right &&
        point.dy >= rect.top &&
        point.dy <= rect.bottom;
  }

  void _drawSurface(Canvas canvas, Size size, double focalLength) {
    const gridSize = 50;

    final parser = MathParser(function);

    List<List<Point3D>> points = [];
    List<List<double>> zValues = [];

    for (int i = 0; i <= gridSize; i++) {
      List<Point3D> row = [];
      List<double> zRow = [];
      for (int j = 0; j <= gridSize; j++) {
        final x = -range + (2 * range * i / gridSize);
        final y = -range + (2 * range * j / gridSize);

        double z;
        try {
          z = parser.evaluate(x, y);
          if (!z.isFinite) z = 0;
          z = z.clamp(-range, range);
        } catch (e) {
          z = 0;
        }

        var point = Point3D(x * scale, y * scale, z * scale);
        point = point.rotateX(rotationX).rotateZ(rotationZ);

        row.add(point);
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
      final o1 = quad.p1.project(focalLength, size);
      final o2 = quad.p2.project(focalLength, size);
      final o3 = quad.p3.project(focalLength, size);
      final o4 = quad.p4.project(focalLength, size);

      // Normalize value based on current range
      final normalizedValue = (quad.avgValue + range) / (2 * range);
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

    final glowPaint = Paint()
      ..color = const Color(0xFF58C4DD).withOpacity(0.4)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final path = Path();
    bool started = false;
    double? lastZ;

    for (int i = 0; i <= steps; i++) {
      final x = -range + (2 * range * i / steps);

      double z;
      try {
        z = parser.evaluate(x, 0);
        if (!z.isFinite) {
          started = false;
          lastZ = null;
          continue;
        }
        z = z.clamp(-range, range);
      } catch (e) {
        started = false;
        lastZ = null;
        continue;
      }

      var point = Point3D(x * scale, 0, z * scale);
      point = point.rotateX(rotationX).rotateZ(rotationZ);
      final proj = point.project(focalLength, size);

      if (lastZ != null && (z - lastZ!).abs() > range * 0.5) {
        started = false;
      }

      if (!started) {
        path.moveTo(proj.dx, proj.dy);
        started = true;
      } else {
        path.lineTo(proj.dx, proj.dy);
      }
      lastZ = z;
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);

    // Shadow on floor
    final shadowPath = Path();
    started = false;

    final shadowPaint = Paint()
      ..color = const Color(0xFF58C4DD).withOpacity(0.2)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= steps; i++) {
      final x = -range + (2 * range * i / steps);

      double z;
      try {
        z = parser.evaluate(x, 0);
        if (!z.isFinite) {
          started = false;
          continue;
        }
      } catch (e) {
        started = false;
        continue;
      }

      var point = Point3D(x * scale, 0, 0);
      point = point.rotateX(rotationX).rotateZ(rotationZ);
      final proj = point.project(focalLength, size);

      if (!started) {
        shadowPath.moveTo(proj.dx, proj.dy);
        started = true;
      } else {
        shadowPath.lineTo(proj.dx, proj.dy);
      }
    }

    canvas.drawPath(shadowPath, shadowPaint);

    // Vertical lines
    final verticalPaint = Paint()
      ..color = const Color(0xFF58C4DD).withOpacity(0.1)
      ..strokeWidth = 1;

    for (int i = 0; i <= steps; i += 15) {
      final x = -range + (2 * range * i / steps);

      double z;
      try {
        z = parser.evaluate(x, 0);
        if (!z.isFinite) continue;
        z = z.clamp(-range, range);
      } catch (e) {
        continue;
      }

      var top = Point3D(x * scale, 0, z * scale)
          .rotateX(rotationX)
          .rotateZ(rotationZ);
      var bottom =
          Point3D(x * scale, 0, 0).rotateX(rotationX).rotateZ(rotationZ);

      canvas.drawLine(
        top.project(focalLength, size),
        bottom.project(focalLength, size),
        verticalPaint,
      );
    }
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
    final localT = scaledT - index;

    return Color.lerp(colors[index], colors[index + 1], localT)!;
  }

  @override
  bool shouldRepaint(covariant Plot3DPainter oldDelegate) {
    return oldDelegate.rotationX != rotationX ||
        oldDelegate.rotationZ != rotationZ ||
        oldDelegate.range != range ||
        oldDelegate.function != function ||
        oldDelegate.is3DFunction != is3DFunction;
  }
}

class _Quad {
  final Point3D p1, p2, p3, p4;
  final double avgDepth;
  final double avgValue;

  _Quad(this.p1, this.p2, this.p3, this.p4, this.avgDepth, this.avgValue);
}