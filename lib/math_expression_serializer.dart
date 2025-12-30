import 'renderer.dart'; // or wherever your MathNode classes are

class MathExpressionSerializer {
  // Unicode characters used in the editor
  static const String _plusSign = '\u002B';
  static const String _minusSign = '\u2212';
  static const String _multiplySign = '\u00B7';

  /// Converts the expression tree to a PEMDAS-compliant string
  static String serialize(List<MathNode> expression) {
    final result = _serializeList(expression);
    return _cleanupExpression(result);
  }

  static String _serializeList(List<MathNode> nodes) {
    StringBuffer buffer = StringBuffer();
    for (int i = 0; i < nodes.length; i++) {
      buffer.write(_serializeNode(nodes[i]));
    }
    return buffer.toString();
  }

  static String _serializeNode(MathNode node) {
    if (node is LiteralNode) {
      return _normalizeLiteral(node.text);
    } else if (node is NewlineNode) {
      return '\n';
    } else if (node is FractionNode) {
      String num = _serializeList(node.numerator);
      String den = _serializeList(node.denominator);
      return '(($num)/($den))';
    } else if (node is ExponentNode) {
      String base = _serializeList(node.base);
      String power = _serializeList(node.power);
      if (_containsOperators(base)) {
        base = '($base)';
      }
      return '$base^($power)';
    } else if (node is ParenthesisNode) {
      String content = _serializeList(node.content);
      return '($content)';
    } else if (node is TrigNode) {
      String arg = _serializeList(node.argument);
      return '${node.function}($arg)';
    } else if (node is LogNode) {
      String arg = _serializeList(node.argument);
      if (node.isNaturalLog) {
        return 'ln($arg)';
      } else {
        String base = _serializeList(node.base);
        // log_n(x) = ln(x) / ln(n)
        return '(ln($arg)/ln($base))';
      }
    } else if (node is RootNode) {
      String radicand = _serializeList(node.radicand);
      if (node.isSquareRoot) {
        return 'sqrt($radicand)';
      } else {
        String index = _serializeList(node.index);
        return '(($radicand)^(1/($index)))';
      }
    } else if (node is PermutationNode) {
      String n = _serializeList(node.n);
      String r = _serializeList(node.r);
      return 'perm($n,$r)';  // Changed from '${n}P${r}'
    } else if (node is CombinationNode) {
      String n = _serializeList(node.n);
      String r = _serializeList(node.r);
      return 'comb($n,$r)';  // Changed from '${n}C${r}'
    } else if (node is AnsNode) {
      String idx = _serializeList(node.index);
      return 'ANS$idx';
    }
    return '';
  }
  
  /// Converts unicode operators to standard operators
  static String _normalizeLiteral(String text) {
    return text
        .replaceAll(_multiplySign, '*')
        .replaceAll(_minusSign, '-')
        .replaceAll(_plusSign, '+');
  }

  /// Checks if expression contains +, -, *, /
  static bool _containsOperators(String expr) {
    return expr.contains('+') || 
           expr.contains('-') || 
           expr.contains('*') || 
           expr.contains('/');
  }

  /// Cleans up the final expression
  static String _cleanupExpression(String expr) {
    // Remove unnecessary double parentheses
    String result = expr;
    
    // Handle implicit multiplication: 2(x+1) -> 2*(x+1), (x)(y) -> (x)*(y)
    result = _addImplicitMultiplication(result);
    
    // Remove leading + sign
    if (result.startsWith('+')) {
      result = result.substring(1);
    }
    
    return result;
  }

  /// Adds implicit multiplication where needed
  static String _addImplicitMultiplication(String expr) {
    StringBuffer result = StringBuffer();
    
    for (int i = 0; i < expr.length; i++) {
      String current = expr[i];
      result.write(current);
      
      if (i < expr.length - 1) {
        String next = expr[i + 1];
        
        bool needsMultiply = false;
        
        // Check if this is scientific notation (e.g., 2E5, 2e-3)
        bool isScientificNotation = false;
        if (_isDigit(current) && (next == 'E' || next == 'e')) {
          // Look ahead to see if it's followed by digit or +/-
          if (i + 2 < expr.length) {
            String afterE = expr[i + 2];
            if (_isDigit(afterE) || afterE == '+' || afterE == '-') {
              isScientificNotation = true;
            }
          }
        }
        
        // Check if next char is P or C (permutation/combination operator)
        bool isPermCombOperator = (next == 'P' || next == 'C') && 
                                  _isDigit(current) && 
                                  _hasDigitAfterOperator(expr, i + 1);
        
        if (_isDigit(current) && _isLetter(next) && !isPermCombOperator && !isScientificNotation) {
          needsMultiply = true;
        } else if (_isDigit(current) && next == '(') {
          needsMultiply = true;
        } else if (current == ')' && _isDigit(next)) {
          needsMultiply = true;
        } else if (current == ')' && _isLetter(next)) {
          needsMultiply = true;
        } else if (current == ')' && next == '(') {
          needsMultiply = true;
        } else if (_isLetter(current) && next == '(') {
          if (!_isFunction(expr, i)) {
            needsMultiply = true;
          }
        }
        
        if (needsMultiply) {
          result.write('*');
        }
      }
    }
    
    return result.toString();
  }
  
  /// Checks if there's a digit or opening parenthesis after P or C (to confirm it's a perm/comb operator)
  static bool _hasDigitAfterOperator(String expr, int operatorIndex) {
    if (operatorIndex + 1 < expr.length) {
      String nextChar = expr[operatorIndex + 1];
      return _isDigit(nextChar) || nextChar == '(';
    }
    return false;
  }
  
  static bool _isDigit(String char) {
    return char.isNotEmpty && '0123456789.'.contains(char);
  }

  static bool _isLetter(String char) {
    return char.isNotEmpty && RegExp(r'[a-zA-Z]').hasMatch(char);
  }

  static bool _isFunction(String expr, int index) {
    // Common function names to check
    const functions = ['sin', 'cos', 'tan', 'log', 'ln', 'sqrt', 'abs', 'perm', 'comb'];
    
    for (String func in functions) {
      if (index >= func.length - 1) {
        String potentialFunc = expr.substring(index - func.length + 1, index + 1);
        if (potentialFunc == func) {
          return true;
        }
      }
    }
    return false;
  }

  /// Converts expression to a format suitable for equation solving
  /// Returns the expression with proper operator precedence
  static String toSolverFormat(List<MathNode> expression) {
    return serialize(expression);
  }

  /// Extracts variable names from the expression
  static Set<String> extractVariables(List<MathNode> expression) {
    Set<String> variables = {};
    _extractVariablesFromList(expression, variables);
    return variables;
  }

  static void _extractVariablesFromList(List<MathNode> nodes, Set<String> variables) {
    for (final node in nodes) {
      _extractVariablesFromNode(node, variables);
    }
  }

  static void _extractVariablesFromNode(MathNode node, Set<String> variables) {
    if (node is LiteralNode) {
      // Find all letter sequences that are not part of numbers
      RegExp varRegex = RegExp(r'[a-zA-Z]+');
      for (Match match in varRegex.allMatches(node.text)) {
        String potential = match.group(0)!;
        // Exclude common function names
        if (!['sin', 'cos', 'tan', 'log', 'ln', 'sqrt', 'abs', 'P', 'C'].contains(potential)) {
          variables.add(potential);
        }
      }
    } else if (node is FractionNode) {
      _extractVariablesFromList(node.numerator, variables);
      _extractVariablesFromList(node.denominator, variables);
    } else if (node is ExponentNode) {
      _extractVariablesFromList(node.base, variables);
      _extractVariablesFromList(node.power, variables);
    } else if (node is ParenthesisNode) {
      _extractVariablesFromList(node.content, variables);
    } else if (node is LogNode) {
      _extractVariablesFromList(node.base, variables);
      _extractVariablesFromList(node.argument, variables);
    } else if (node is AnsNode) {
      // Don't extract variables from ANS index - it's just a reference number
      // But if someone puts a variable in there, we might want to ignore it
    }
  }

  /// Checks if the expression is an equation (contains =)
  static bool isEquation(List<MathNode> expression) {
    return serialize(expression).contains('=');
  }

  /// Splits an equation into LHS and RHS
  static List<String>? splitEquation(List<MathNode> expression) {
    String expr = serialize(expression);
    if (!expr.contains('=')) return null;
    
    List<String> parts = expr.split('=');
    if (parts.length != 2) return null;
    
    return [parts[0].trim(), parts[1].trim()];
  }
}