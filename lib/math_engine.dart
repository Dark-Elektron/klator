import 'dart:math';
import 'settings_provider.dart'; // ADD THIS IMPORT

/// Math solver for expressions from the new math renderer

class MathSolverNew {
  // ============== GLOBAL PRECISION SETTING ==============
  static int precision = 6; // Default precision, can be changed globally
  static NumberFormat numberFormat = NumberFormat.automatic; // NEW

  /// Call this to update precision from settings
  static void setPrecision(int value) {
    precision = value;
  }

  /// Call this to update number format from settings
  static void setNumberFormat(NumberFormat value) {
    numberFormat = value;
  }

  /// Main entry point - determines what type of expression and solves accordingly
  static String? solve(String expression, {Map<int, String>? ansValues}) {
    expression = expression.trim();
    if (expression.isEmpty) return null;

    // Replace ANS references first
    if (ansValues != null && ansValues.isNotEmpty) {
      expression = _preprocessAnsReferences(expression, ansValues);
    }

    // Check if it's a system of equations (multiple lines)
    if (expression.contains('\n')) {
      // Count variables across all equations
      Set<String> allVariables = {};
      List<String> equations =
          expression.split('\n').where((e) => e.trim().isNotEmpty).toList();

      for (String eq in equations) {
        allVariables.addAll(_findVariables(eq));
      }

      // Need at least as many equations as variables
      if (allVariables.length > equations.length) {
        // print('DEBUG: ${allVariables.length} variables but only ${equations.length} equations');
        return null; // Not enough equations
      }

      return solveLinearSystem(expression);
    }

    // Check if it's an equation
    if (expression.contains('=')) {
      // Check variable count before attempting to solve
      Set<String> variables = _findVariables(expression);

      if (variables.length > 1) {
        // More than one variable - cannot solve single equation
        return null;
      }

      return solveEquation(expression);
    }

    // Otherwise, evaluate as an expression
    return evaluate(expression);
  }
  // ============== EXPRESSION EVALUATION ==============

  /// Evaluates a mathematical expression and returns the result
  static String? evaluate(String expression) {
    try {
      expression = _preprocess(expression);
      double result = _evaluateExpression(expression);
      return _formatResult(result);
    } catch (e) {
      return '';
    }
  }

  /// Preprocesses the expression for evaluation
  static String _preprocess(String expr) {
    // Remove spaces
    expr = expr.replaceAll(' ', '');

    expr = expr.replaceAll('\u00B7', '*'); // middle dot ·
    expr = expr.replaceAll('\u00D7', '*'); // times sign ×

    // Convert small caps E back to regular e for parsing
    expr = expr.replaceAll('\u1D07', 'E');

    expr = expr.replaceAll('\u00B0', '*($pi/180)'); // degrees
    expr = expr.replaceAll('rad', '*((1/$pi)*180)'); // radian

    // Replace pi constant - only add * if preceded by digit or )
    expr = expr.replaceAllMapped(RegExp(r'([\d\)])?\u03C0'), (match) {
      String? before = match.group(1);
      if (before != null) {
        return '$before*($pi)';
      }
      return '($pi)';
    });

    // Replace standalone e (Euler's number) - only add * if preceded by digit or )
    expr = expr.replaceAllMapped(
      RegExp(r'([\d\)])?(?<![a-zA-Z])e(?![a-zA-Z])'),
      (match) {
        String? before = match.group(1);
        if (before != null) {
          return '$before*($e)';
        }
        return '($e)';
      },
    );

    // Process special functions
    expr = _preprocessPermuCombination(expr);
    expr = _processFactorials(expr);

    return expr;
  }

  /// Evaluates an expression string to a double
  static double _evaluateExpression(String expr) {
    _ExpressionParser parser = _ExpressionParser(expr);
    return parser.parse();
  }

  // ============== EQUATION SOLVING ==============

  /// Solves an equation (linear or quadratic)
  /// Only solves if there's exactly one variable
  static String? solveEquation(String equation) {
    equation = equation.replaceAll(' ', '');

    // Find all unique variables in the equation
    Set<String> variables = _findVariables(equation);

    // print('DEBUG: Found variables: $variables');

    // If no variables, just evaluate the expression
    if (variables.isEmpty) {
      return evaluate('${equation.replaceAll('=', '-(')})');
    }

    // If more than one variable, return null or the original equation
    // (needs more equations to solve)
    if (variables.length > 1) {
      // print(
      //   'DEBUG: Multiple variables found (${variables.length}), cannot solve single equation',
      // );
      return null; // Or return equation to show it as-is
    }

    // Exactly one variable - proceed to solve
    String variable = variables.first;

    List<String> parts = equation.split('=');
    if (parts.length != 2) return null;

    String lhs = parts[0].trim();
    String rhs = parts[1].trim();

    // Get coefficients for both sides
    List<double> coeffsLHS = _getCoefficients(lhs, variable);
    List<double> coeffsRHS = _getCoefficients(rhs, variable);

    double a = coeffsLHS[0] - coeffsRHS[0]; // x^2 coefficient
    double b = coeffsLHS[1] - coeffsRHS[1]; // x coefficient
    double c = coeffsLHS[2] - coeffsRHS[2]; // constant

    // Linear equation (a = 0)
    if (a.abs() < 1e-10) {
      if (b.abs() < 1e-10) {
        if (c.abs() < 1e-10) return "Infinite solutions";
        return "No solution";
      }
      return '$variable = ${_formatResult(-c / b)}';
    }

    // Quadratic equation
    if (c.abs() < 1e-10) {
      // x(ax + b) = 0
      return '$variable = 0\n$variable = ${_formatResult(-b / a)}';
    }

    double discriminant = b * b - 4 * a * c;

    if (discriminant < 0) {
      // Complex roots
      double realPart = -b / (2 * a);
      double imagPart = sqrt(-discriminant) / (2 * a);
      return '$variable = ${_formatResult(realPart)} ± ${_formatResult(imagPart.abs())}i';
    }

    // Real roots using numerically stable formula
    double root1, root2;
    if (discriminant == 0) {
      root1 = root2 = -b / (2 * a);
    } else {
      // Use citardauq formula for numerical stability
      double sqrtDisc = sqrt(discriminant);
      if (b >= 0) {
        root1 = (-b - sqrtDisc) / (2 * a);
        root2 = (2 * c) / (-b - sqrtDisc);
      } else {
        root1 = (2 * c) / (-b + sqrtDisc);
        root2 = (-b + sqrtDisc) / (2 * a);
      }
    }

    if ((root1 - root2).abs() < 1e-10) {
      return '$variable = ${_formatResult(root1)}';
    }

    return '$variable = ${_formatResult(root1)}\n$variable = ${_formatResult(root2)}';
  }

  /// Find all unique variables in an expression
  static Set<String> _findVariables(String expression) {
    Set<String> variables = {};

    // Reserved function names and constants to exclude
    const reserved = {
      'sin',
      'cos',
      'tan',
      'asin',
      'acos',
      'atan',
      'log',
      'ln',
      'sqrt',
      'abs',
      'exp',
      'perm',
      'comb',
      'ans',
      'e',
      'pi',
      'i',
    };

    // Find all letter sequences
    RegExp letterRegex = RegExp(r'[a-zA-Z]+');

    for (Match match in letterRegex.allMatches(expression)) {
      String potential = match.group(0)!.toLowerCase();

      // Check if it's a reserved word
      if (!reserved.contains(potential)) {
        // For single letters, add them as variables
        // For multi-letter sequences not in reserved, check each letter
        if (match.group(0)!.length == 1) {
          variables.add(match.group(0)!);
        } else if (!reserved.contains(potential)) {
          // Multi-letter non-reserved - might be implicit multiplication like "xy"
          // Add each letter as a separate variable
          for (int i = 0; i < match.group(0)!.length; i++) {
            String char = match.group(0)![i];
            if (!reserved.contains(char.toLowerCase())) {
              variables.add(char);
            }
          }
        }
      }
    }

    return variables;
  }

  /// Extracts coefficients [a, b, c] for ax^2 + bx + c
  static List<double> _getCoefficients(String expression, String variable) {
    double a = 0, b = 0, c = 0;

    expression = expression.replaceAll(' ', '');

    // Ensure starts with sign
    if (!expression.startsWith('+') && !expression.startsWith('-')) {
      expression = '+$expression';
    }

    // Split into terms by + or - while keeping the sign
    List<String> terms = [];
    String currentTerm = '';

    for (int i = 0; i < expression.length; i++) {
      String char = expression[i];
      if ((char == '+' || char == '-') && i > 0) {
        if (currentTerm.isNotEmpty) {
          terms.add(currentTerm.trim());
        }
        currentTerm = char;
      } else {
        currentTerm += char;
      }
    }
    if (currentTerm.isNotEmpty) {
      terms.add(currentTerm.trim());
    }

    String quadSuffix = '$variable^(2)';
    String quadSuffixAlt = variable + r'^2';

    for (String term in terms) {
      // Check for quadratic term: ends with x^(2) or x^2
      if (term.endsWith(quadSuffix) || term.endsWith(quadSuffixAlt)) {
        String coeffPart;
        if (term.endsWith(quadSuffix)) {
          coeffPart = term.substring(0, term.length - quadSuffix.length);
        } else {
          coeffPart = term.substring(0, term.length - quadSuffixAlt.length);
        }
        if (coeffPart.endsWith('*')) {
          coeffPart = coeffPart.substring(0, coeffPart.length - 1);
        }
        double coeff = _parseCoefficient(coeffPart);
        a += coeff;
      }
      // Check for linear term: contains variable but no ^
      else if (term.contains(variable) && !term.contains('^')) {
        int varIndex = term.indexOf(variable);
        String coeffPart = term.substring(0, varIndex);
        if (coeffPart.endsWith('*')) {
          coeffPart = coeffPart.substring(0, coeffPart.length - 1);
        }
        double coeff = _parseCoefficient(coeffPart);
        b += coeff;
      }
      // Constant term: no variable
      else if (!term.contains(variable)) {
        try {
          double val = double.parse(term);
          c += val;
        } catch (e) {
          // Could not parse constant
        }
      }
    }

    return [a, b, c];
  }

  /// Parses a coefficient string, handling empty/sign-only cases
  static double _parseCoefficient(String coeff) {
    coeff = coeff.trim();
    if (coeff.isEmpty || coeff == '+') return 1.0;
    if (coeff == '-') return -1.0;
    try {
      return double.parse(coeff);
    } catch (e) {
      return 0.0;
    }
  }

  // ============== LINEAR SYSTEM SOLVING ==============

  /// Solves a system of linear equations using Cramer's rule
  static String? solveLinearSystem(String equationsString) {
    List<String> equations = equationsString.replaceAll(' ', '').split('\n');
    equations = equations.where((eq) => eq.trim().isNotEmpty).toList();

    if (equations.isEmpty || equations.length > 3) return null;

    Set<String> variableSet = {};
    List<Map<String, double>> equationCoefficients = [];
    List<double> constants = [];

    const reserved = {
      'sin',
      'cos',
      'tan',
      'log',
      'ln',
      'sqrt',
      'abs',
      'exp',
      'e',
      'pi',
      'i',
    };

    RegExp equationRegex = RegExp(r'(.+)=([^=]+)');

    for (String eq in equations) {
      final match = equationRegex.firstMatch(eq);
      if (match == null) return null;

      String leftSide = match.group(1)!;
      String rightSide = match.group(2)!;

      Map<String, double> equationMap = {};
      double constant = 0.0;

      void processSide(String side, int sign) {
        RegExp termRegex = RegExp(r'([+-]?)(\d*\.?\d*)\*?([a-zA-Z]?)');

        for (Match m in termRegex.allMatches(side)) {
          String signStr = m.group(1) ?? '';
          String coeffStr = m.group(2) ?? '';
          String varName = m.group(3) ?? '';

          if (varName.isEmpty && coeffStr.isEmpty) continue;
          if (reserved.contains(varName)) continue;

          int termSign = (signStr == '-') ? -1 : 1;

          if (varName.isNotEmpty) {
            double coeff;
            if (coeffStr.isEmpty) {
              coeff = 1.0;
            } else {
              coeff = double.tryParse(coeffStr) ?? 1.0;
            }
            coeff *= termSign * sign;

            equationMap[varName] = (equationMap[varName] ?? 0) + coeff;
            variableSet.add(varName);
          } else if (coeffStr.isNotEmpty) {
            double val = double.tryParse(coeffStr) ?? 0;
            constant += termSign * sign * val;
          }
        }
      }

      processSide(leftSide, 1);
      processSide(rightSide, -1);

      constants.add(-constant);
      equationCoefficients.add(equationMap);
    }

    List<String> variables = variableSet.toList()..sort();
    if (variables.length != equations.length) {
      return null;
    }

    List<List<double>> coefficients = [];
    for (var equationMap in equationCoefficients) {
      List<double> row = variables.map((v) => equationMap[v] ?? 0.0).toList();
      coefficients.add(row);
    }

    double mainDet = _determinant(coefficients);

    if (mainDet.abs() < 1e-10) return null;

    StringBuffer solution = StringBuffer();
    for (int i = 0; i < variables.length; i++) {
      List<List<double>> tempMatrix = [];
      for (int j = 0; j < coefficients.length; j++) {
        List<double> row = List.from(coefficients[j]);
        row[i] = constants[j];
        tempMatrix.add(row);
      }
      double value = _determinant(tempMatrix) / mainDet;
      solution.writeln('${variables[i]} = ${_formatResult(value)}');
    }

    return solution.toString().trim();
  }

  /// Calculates determinant of a matrix recursively
  static double _determinant(List<List<double>> matrix) {
    int n = matrix.length;
    if (n == 1) return matrix[0][0];
    if (n == 2) {
      return matrix[0][0] * matrix[1][1] - matrix[0][1] * matrix[1][0];
    }

    double det = 0;
    for (int i = 0; i < n; i++) {
      List<List<double>> subMatrix = [];
      for (int j = 1; j < n; j++) {
        subMatrix.add([...matrix[j]]..removeAt(i));
      }
      det += (i % 2 == 0 ? 1 : -1) * matrix[0][i] * _determinant(subMatrix);
    }
    return det;
  }

  // ============== SPECIAL FUNCTIONS ==============

  /// Replaces ANS references with actual values
  static String _preprocessAnsReferences(
    String expr,
    Map<int, String> ansValues,
  ) {
    RegExp ansRegex = RegExp(r'ans(\d+)', caseSensitive: false);

    return expr.replaceAllMapped(ansRegex, (match) {
      String indexStr = match.group(1) ?? '';

      int? index = int.tryParse(indexStr);
      if (index == null) {
        return '(0)';
      }

      if (!ansValues.containsKey(index)) {
        return '(0)';
      }

      String? value = ansValues[index];

      if (value == null || value.isEmpty) {
        return '(0)';
      }

      if (double.tryParse(value) == null) {
        List<String> lines = value.split('\n');
        for (String line in lines) {
          RegExp numRegex = RegExp(r'=\s*(-?\d+\.?\d*)');
          Match? numMatch = numRegex.firstMatch(line);
          if (numMatch != null) {
            return '(${numMatch.group(1)})';
          }
        }
        return '(0)';
      }

      return '($value)';
    });
  }

  // ============== PERMUTATION & COMBINATION ==============

  static String _preprocessPermuCombination(String expr) {
    expr = _processPermComb(expr, 'perm', true);
    expr = _processPermComb(expr, 'comb', false);
    return expr;
  }

  static String _processPermComb(
    String expr,
    String funcName,
    bool isPermutation,
  ) {
    while (expr.contains('$funcName(')) {
      int startIndex = expr.indexOf('$funcName(');
      if (startIndex == -1) break;

      int openParen = startIndex + funcName.length;

      int closeParen = _findMatchingParen(expr, openParen);
      if (closeParen == -1) break;

      String content = expr.substring(openParen + 1, closeParen);

      int commaIndex = _findSeparatingComma(content);
      if (commaIndex == -1) break;

      String nExpr = content.substring(0, commaIndex).trim();
      String rExpr = content.substring(commaIndex + 1).trim();

      double? nValue = _evaluateSimpleExpression(nExpr);
      double? rValue = _evaluateSimpleExpression(rExpr);

      if (nValue == null || rValue == null) break;

      int n = nValue.toInt();
      int r = rValue.toInt();

      double result =
          isPermutation ? permutationDouble(n, r) : combinationDouble(n, r);

      String resultStr;
      if (result == result.roundToDouble() && result.abs() < 1e15) {
        resultStr = result.toInt().toString();
      } else {
        resultStr = result.toString();
      }

      expr =
          expr.substring(0, startIndex) +
          resultStr +
          expr.substring(closeParen + 1);
    }

    return expr;
  }

  static int _findMatchingParen(String expr, int openIndex) {
    if (openIndex >= expr.length || expr[openIndex] != '(') return -1;

    int depth = 1;
    for (int i = openIndex + 1; i < expr.length; i++) {
      if (expr[i] == '(') {
        depth++;
      } else if (expr[i] == ')') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  static int _findSeparatingComma(String content) {
    int depth = 0;
    for (int i = 0; i < content.length; i++) {
      if (content[i] == '(') {
        depth++;
      } else if (content[i] == ')') {
        depth--;
      } else if (content[i] == ',' && depth == 0) {
        return i;
      }
    }
    return -1;
  }

  static double? _evaluateSimpleExpression(String expr) {
    try {
      expr = expr.trim();
      while (expr.startsWith('(') && expr.endsWith(')')) {
        if (_findMatchingParen(expr, 0) == expr.length - 1) {
          expr = expr.substring(1, expr.length - 1).trim();
        } else {
          break;
        }
      }

      double? direct = double.tryParse(expr);
      if (direct != null) return direct;

      String preprocessed = _preprocessSimple(expr);
      return _evaluateExpression(preprocessed);
    } catch (e) {
      return null;
    }
  }

  static String _preprocessSimple(String expr) {
    expr = expr.replaceAll(' ', '');
    expr = expr.replaceAll('\u00B7', '*');
    expr = expr.replaceAll('\u00D7', '*');
    expr = expr.replaceAll('\u1D07', 'E');
    expr = expr.replaceAll('\u00B0', '*($pi/180)');
    expr = expr.replaceAll('rad', '*((1/$pi)*180)');

    expr = expr.replaceAllMapped(RegExp(r'([\d\)])?\u03C0'), (match) {
      String? before = match.group(1);
      if (before != null) {
        return '$before*($pi)';
      }
      return '($pi)';
    });

    expr = expr.replaceAllMapped(
      RegExp(r'([\d\)])?(?<![a-zA-Z])e(?![a-zA-Z])'),
      (match) {
        String? before = match.group(1);
        if (before != null) {
          return '$before*($e)';
        }
        return '($e)';
      },
    );

    expr = _processFactorials(expr);

    return expr;
  }

  // Keep old int versions for backward compatibility
  static int factorial(int n) {
    if (n <= 1) return 1;
    int result = 1;
    for (int i = 2; i <= n; i++) {
      result *= i;
    }
    return result;
  }

  static int permutation(int n, int r) {
    if (r > n) return 0;
    return factorial(n) ~/ factorial(n - r);
  }

  static int combination(int n, int r) {
    if (r > n) return 0;
    return factorial(n) ~/ (factorial(r) * factorial(n - r));
  }

  // New double versions for large numbers
  static double permutationDouble(int n, int r) {
    if (r > n || r < 0 || n < 0) return 0;

    double result = 1;
    for (int i = 0; i < r; i++) {
      result *= (n - i);
    }
    return result;
  }

  static double combinationDouble(int n, int r) {
    if (r > n || r < 0 || n < 0) return 0;

    if (r > n - r) {
      r = n - r;
    }

    double result = 1;
    for (int i = 0; i < r; i++) {
      result *= (n - i);
      result /= (i + 1);
    }
    return result;
  }

  /// Process factorials n!
  static String _processFactorials(String expr) {
    RegExp regex = RegExp(r'(\d+)!');
    return expr.replaceAllMapped(regex, (match) {
      int n = int.parse(match.group(1)!);
      return _factorial(n).toString();
    });
  }

  static int _factorial(int n) {
    if (n <= 1) return 1;
    int result = 1;
    for (int i = 2; i <= n; i++) {
      result *= i;
    }
    return result;
  }

  // ============== FORMATTING ==============
  // ============== FORMATTING ==============
  static String _formatResult(double num) {
    if (num.isNaN || num.isInfinite) return num.toString();

    // Check if it's effectively zero
    if (num.abs() < 1e-15) {
      return '0';
    }

    switch (numberFormat) {
      case NumberFormat.scientific:
        return _formatScientific(num);
      case NumberFormat.plain:
        return _formatPlain(num);
      case NumberFormat.automatic:
        return _formatAutomatic(num);
    }
  }

  /// Automatic format - scientific only for very large/small numbers
  static String _formatAutomatic(double num) {
    // Use scientific notation for very large or very small numbers
    if (num.abs() >= 1e6 || (num.abs() <= 1e-6 && num.abs() > 0)) {
      return _formatScientific(num);
    }

    // Check if it's effectively an integer
    if ((num - num.roundToDouble()).abs() < 1e-10) {
      return num.round().toString();
    }

    String formatted = num.toStringAsFixed(precision);
    // Remove trailing zeros
    if (formatted.contains('.')) {
      formatted = formatted.replaceAll(RegExp(r'0+$'), '');
      formatted = formatted.replaceAll(RegExp(r'\.$'), '');
    }
    return formatted;
  }

  /// Plain format - with commas, never scientific notation
  static String _formatPlain(double num) {
    // Check if it's effectively an integer
    if ((num - num.roundToDouble()).abs() < 1e-10) {
      return _addCommas(num.round().toString());
    }

    String formatted = num.toStringAsFixed(precision);
    // Remove trailing zeros
    if (formatted.contains('.')) {
      formatted = formatted.replaceAll(RegExp(r'0+$'), '');
      formatted = formatted.replaceAll(RegExp(r'\.$'), '');
    }

    // Split into integer and decimal parts
    List<String> parts = formatted.split('.');
    String integerPart = _addCommas(parts[0]);

    if (parts.length > 1 && parts[1].isNotEmpty) {
      return '$integerPart.${parts[1]}';
    }
    return integerPart;
  }

  /// Adds commas to an integer string (handles negative numbers)
  static String _addCommas(String numStr) {
    bool isNegative = numStr.startsWith('-');
    if (isNegative) {
      numStr = numStr.substring(1);
    }

    StringBuffer result = StringBuffer();
    int count = 0;

    for (int i = numStr.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        result.write(',');
      }
      result.write(numStr[i]);
      count++;
    }

    String reversed = result.toString().split('').reversed.join();
    return isNegative ? '-$reversed' : reversed;
  }

  /// Formats a number in scientific notation (e.g., 1.23E6)
  static String _formatScientific(double num) {
    // Use Dart's built-in exponential formatting
    String expStr = num.toStringAsExponential(precision);

    // Split into mantissa and exponent parts
    List<String> parts = expStr.toLowerCase().split('e');
    String mantissa = parts[0];
    String exponent = parts[1];

    // Remove trailing zeros from mantissa
    if (mantissa.contains('.')) {
      mantissa = mantissa.replaceAll(RegExp(r'0+$'), '');
      mantissa = mantissa.replaceAll(RegExp(r'\.$'), '');
    }
    // Format exponent (remove leading +)
    if (exponent.startsWith('+')) {
      exponent = exponent.substring(1);
    }
    // If exponent is 0, just return the mantissa
    if (exponent == '0') {
      return mantissa;
    }

    return '$mantissa\u1D07$exponent';
  }
}

// ============== EXPRESSION PARSER ==============

/// Recursive descent parser for mathematical expressions
class _ExpressionParser {
  final String expression;
  int _pos = 0;

  _ExpressionParser(this.expression);

  double parse() {
    double result = _parseAddSubtract();
    if (_pos < expression.length) {
      throw FormatException('Unexpected character at position $_pos');
    }
    return result;
  }

  double _parseAddSubtract() {
    double left = _parseMultiplyDivide();

    while (_pos < expression.length) {
      String op = _currentChar();
      if (op != '+' && op != '-') break;
      _pos++;
      double right = _parseMultiplyDivide();
      if (op == '+') {
        left += right;
      } else {
        left -= right;
      }
    }

    return left;
  }

  double _parseMultiplyDivide() {
    double left = _parsePower();

    while (_pos < expression.length) {
      String op = _currentChar();
      if (op != '*' && op != '/') break;
      _pos++;
      double right = _parsePower();
      if (op == '*') {
        left *= right;
      } else {
        left /= right;
      }
    }

    return left;
  }

  double _parsePower() {
    double base = _parseUnary();

    while (_pos < expression.length && _currentChar() == '^') {
      _pos++;
      double exponent = _parseUnary();
      base = pow(base, exponent).toDouble();
    }

    return base;
  }

  double _parseUnary() {
    if (_pos < expression.length) {
      if (_currentChar() == '-') {
        _pos++;
        return -_parseUnary();
      }
      if (_currentChar() == '+') {
        _pos++;
        return _parseUnary();
      }
    }
    return _parsePrimary();
  }

  double _parsePrimary() {
    // Parentheses
    if (_currentChar() == '(') {
      _pos++;
      double result = _parseAddSubtract();
      if (_currentChar() != ')') {
        throw FormatException('Missing closing parenthesis');
      }
      _pos++;
      return result;
    }

    // Functions
    String? func = _tryParseFunction();
    if (func != null) {
      if (_currentChar() != '(') {
        throw FormatException('Expected ( after function $func');
      }
      _pos++;
      double arg = _parseAddSubtract();
      if (_currentChar() != ')') {
        throw FormatException('Missing closing parenthesis for $func');
      }
      _pos++;
      return _applyFunction(func, arg);
    }

    // Number
    return _parseNumber();
  }

  String? _tryParseFunction() {
    const functions = [
      'sin',
      'cos',
      'tan',
      'asin',
      'acos',
      'atan',
      'log',
      'ln',
      'sqrt',
      'abs',
      'exp',
    ];
    for (String func in functions) {
      if (_pos + func.length <= expression.length &&
          expression.substring(_pos, _pos + func.length) == func) {
        _pos += func.length;
        return func;
      }
    }
    return null;
  }

  double _applyFunction(String func, double arg) {
    switch (func) {
      case 'sin':
        return sin(arg);
      case 'cos':
        return cos(arg);
      case 'tan':
        return tan(arg);
      case 'asin':
        return asin(arg);
      case 'acos':
        return acos(arg);
      case 'atan':
        return atan(arg);
      case 'log':
        return log(arg) / ln10;
      case 'ln':
        return log(arg);
      case 'sqrt':
        return sqrt(arg);
      case 'abs':
        return arg.abs();
      case 'exp':
        return exp(arg);
      default:
        throw FormatException('Unknown function: $func');
    }
  }

  double _parseNumber() {
    int start = _pos;

    if (_pos < expression.length &&
        (_currentChar() == '-' || _currentChar() == '+')) {
      _pos++;
    }

    while (_pos < expression.length && _isDigit(_currentChar())) {
      _pos++;
    }

    if (_pos < expression.length && _currentChar() == '.') {
      _pos++;
      while (_pos < expression.length && _isDigit(_currentChar())) {
        _pos++;
      }
    }

    if (_pos < expression.length &&
        (_currentChar() == 'e' || _currentChar() == 'E')) {
      _pos++;
      if (_pos < expression.length &&
          (_currentChar() == '+' || _currentChar() == '-')) {
        _pos++;
      }
      while (_pos < expression.length && _isDigit(_currentChar())) {
        _pos++;
      }
    }

    if (start == _pos) {
      throw FormatException('Expected number at position $_pos');
    }

    return double.parse(expression.substring(start, _pos));
  }

  String _currentChar() {
    if (_pos >= expression.length) return '';
    return expression[_pos];
  }

  bool _isDigit(String char) {
    return char.isNotEmpty && '0123456789'.contains(char);
  }
}

// ============== COMPLEX NUMBER CLASS ==============

class Complex {
  final double real;
  final double imag;

  Complex(this.real, this.imag);

  Complex operator +(Complex other) =>
      Complex(real + other.real, imag + other.imag);
  Complex operator -(Complex other) =>
      Complex(real - other.real, imag - other.imag);
  Complex operator *(Complex other) => Complex(
    real * other.real - imag * other.imag,
    real * other.imag + imag * other.real,
  );
  Complex operator /(Complex other) {
    double denom = other.real * other.real + other.imag * other.imag;
    return Complex(
      (real * other.real + imag * other.imag) / denom,
      (imag * other.real - real * other.imag) / denom,
    );
  }

  double get magnitude => sqrt(real * real + imag * imag);
  double get phase => atan2(imag, real);

  @override
  String toString() {
    String realStr = _formatNum(real);
    String imagStr = _formatNum(imag.abs());
    if (imag >= 0) {
      return "$realStr + ${imagStr}i";
    } else {
      return "$realStr - ${imagStr}i";
    }
  }

  String _formatNum(double num) {
    if ((num - num.roundToDouble()).abs() < 1e-10) {
      return num.round().toString();
    }
    String formatted = num.toStringAsFixed(MathSolverNew.precision);
    if (formatted.contains('.')) {
      formatted = formatted.replaceAll(RegExp(r'0+$'), '');
      formatted = formatted.replaceAll(RegExp(r'\.$'), '');
    }
    return formatted;
  }
}
