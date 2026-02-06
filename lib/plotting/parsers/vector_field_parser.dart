import 'dart:math';
import 'math_parser.dart';

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

  static bool isVectorField(String expr) {
    String normalized = expr.replaceAll(' ', '').toLowerCase();
    return RegExp(r'[ijk](?=[+\-]|$)').hasMatch(normalized);
  }

  static VectorFieldParser? parse(String expr) {
    if (!isVectorField(expr)) return null;

    String? xComp, yComp, zComp;
    String normalized = expr.replaceAll(' ', '');

    List<String> terms = [];
    String currentTerm = '';
    int parenDepth = 0;

    for (int idx = 0; idx < normalized.length; idx++) {
      final char = normalized[idx];

      if (char == '(') parenDepth++;
      if (char == ')') parenDepth--;

      if ((char == '+' || char == '-') && idx > 0 && parenDepth == 0) {
        if (currentTerm.isNotEmpty) terms.add(currentTerm);
        currentTerm = char == '-' ? '-' : '';
      } else {
        currentTerm += char;
      }
    }
    if (currentTerm.isNotEmpty) terms.add(currentTerm);

    for (String term in terms) {
      String component;
      String coefficient;

      String termLower = term.toLowerCase();

      if (termLower.endsWith('i') && !_endsWithFunction(termLower)) {
        coefficient = term.substring(0, term.length - 1);
        component = 'i';
      } else if (termLower.endsWith('j')) {
        coefficient = term.substring(0, term.length - 1);
        component = 'j';
      } else if (termLower.endsWith('k')) {
        coefficient = term.substring(0, term.length - 1);
        component = 'k';
      } else {
        continue;
      }

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

    if (xComp == null && yComp == null && zComp == null) {
      return null;
    }

    return VectorFieldParser(
      xComponent: xComp,
      yComponent: yComp,
      zComponent: zComp,
    );
  }

  static bool _endsWithFunction(String term) {
    const functions = ['sin', 'asin', 'sinh', 'min', 'ceil'];
    for (final func in functions) {
      if (term.endsWith(func)) return true;
    }
    return false;
  }

  bool get is3D => zComponent != null;

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
  String toString() => 'Vector(i: $xComponent, j: $yComponent, k: $zComponent)';
}