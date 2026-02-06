import 'dart:math';

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
      case 'log':
      case 'ln': return log(arg1);
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