import 'dart:convert';

// Define the abstract syntax tree (AST) classes.
class Offset {
  double x, y;
  double dx, dy;

  Offset(this.x, this.y, this.dx, this.dy);
}

// void printMap(Map<dynamic, dynamic> map, {String indent = ''}) {
//   map.forEach((key, value) {
//     if (value is Map) {
//       print('$indent$key: {');
//       printMap(value, indent: '$indent  ');
//       print('$indent}');
//     } else {
//       print('$indent$key: $value');
//     }
//   });
// }

abstract class ExpressionNode {
  String kind = 'ExpressionNode';
  Map<String, dynamic> tree = {};
  List<dynamic> positions = [];
  @override
  String toString();
}

class NumberNode extends ExpressionNode {
  final num value;
  // List<Offset> positions;
  List<dynamic> positions;
  List<int> index;

  NumberNode(this.value, this.positions, this.index){kind='NumberNode';}

  @override
  String toString() => value.toString();
}

class BinaryOpNode extends ExpressionNode {
  final ExpressionNode operator;
  final ExpressionNode left;
  final ExpressionNode right;
  List<int> index;

  BinaryOpNode(this.left, this.operator, this.right, this.index){kind='BinaryNode';}

  @override
  String toString() => '($left $operator $right)';
}

class FunctionNode extends ExpressionNode {
  final String name;
  final List<ExpressionNode> arguments;
  List<int> index;


  FunctionNode(this.name, this.arguments, this.index){kind='FunctionNode';}
  @override
  String toString() => '$name(${arguments.join(", ")})';
}

// Node for incomplete expressions
class IncompleteNode extends ExpressionNode {
  final String expression;
  
  IncompleteNode([this.expression = ""]){kind='IncompleteNode';}
  @override
  String toString() => expression;
}

// Represents variables or constants (like 'x', 'pi', 'e').
class VariableNode extends ExpressionNode {
  final String name;
  List<int> index;

  VariableNode(this.name, this.index){kind='VariableNode';}

  @override
  String toString() => name;
}

class OperatorNode extends ExpressionNode {
  final String name;
  List<int> index;

  OperatorNode(this.name, this.index){kind='OperatorNode';}

  @override
  String toString() => name;
}

// Tokeniser: Converts the input string into a list of tokens.
List<String> tokenize(String expr) {
  List<String> tokens = [];
  int i = 0;
  while (i < expr.length) {
    var char = expr[i];
    if (char == ' ') {
      i++;
      continue;
    }
    if ('+-*\u00B7/\u00F7^(),'.contains(char)) {
      tokens.add(char);
      i++;
    } else if (isDigit(char) || char == '.') {
      int start = i;
      while (i < expr.length && (isDigit(expr[i]) || expr[i] == '.')) {
        i++;
      }
      tokens.add(expr.substring(start, i));
    } else if (isAlphaChar(char)) {
      int start = i;
      while (i < expr.length && isAlphaNumeric(expr[i])) {
        i++;
      }
      tokens.add(expr.substring(start, i));
    } else {
      throw Exception("Unknown token: $char");
    }
  }
  return tokens;
}

bool isDigit(String c) => '0123456789'.contains(c);
bool isAlphaChar(String c) => RegExp(r'[a-zA-Z]').hasMatch(c);
bool isAlphaNumeric(String c) => RegExp(r'[a-zA-Z0-9]').hasMatch(c);

class Parser {
  final List<String> tokens;
  int pos = 0;
  double currentX = 0;

  Parser(this.tokens);

  String? get current => pos < tokens.length ? tokens[pos] : null;
  bool get isAtEnd => pos >= tokens.length;

  String consume() => tokens[pos++];

  ExpressionNode parseExpression({double xOffset = 0, double yOffset = 0}) {
    ExpressionNode node = parseAddSub(xOffset, yOffset);
    node.tree = {
      'value': node.tree.isEmpty ? node.toString() : node.tree,
      'kind': node.kind
    };
    return node;
  }

  ExpressionNode parseAddSub(double xOffset, double yOffset) {
    ExpressionNode node = parseMulDiv(xOffset, yOffset);
    while (!isAtEnd && (current == '+' || current == '-')) {
      String token = consume();
      ExpressionNode op = OperatorNode(token, [pos-1]);

      if (isAtEnd) {
        ExpressionNode oldNode = node;
        node = BinaryOpNode(node, op, IncompleteNode(), [pos-1]);
        node.tree = {
        'left': {'value': oldNode.tree.isEmpty ? oldNode.toString() : oldNode.tree,
                            'positions': oldNode.positions,
                            'kind': oldNode.kind},
          'op': {'value': op.toString(),
                    'kind': op.kind},
          'right': {'value': IncompleteNode().toString(),
                                'kind': 'IncompleteNode'}
          };
        return node;
      }

      ExpressionNode right = parseMulDiv(xOffset, yOffset);
      // save old node
      ExpressionNode oldNode = node;
      
      List <dynamic> positions = [];
      for (int i = 0; i < token.length; i++){
        // positions.add(Offset(currentX+i, 0, 1, 1)); // to replace with x and y
        positions.add([currentX+i+xOffset, 0+yOffset, 1, 1]); // to replace with x and y
      }

      node = BinaryOpNode(oldNode, op, right, [pos-1]);
      
      node.tree = {
        'left': {'value': oldNode.tree.isEmpty ? oldNode.toString() : oldNode.tree,
                            'positions': oldNode.positions,
                            'kind': oldNode.kind},
        'op': {'value': op.toString(),
                  'positions': op.positions,
                  'kind': op.kind},
        "right": {'value': right.tree.isEmpty ? right.toString() : right.tree,
                              'positions': right.positions,
                              'kind': right.kind}
      };
    }
    return node;
  }

  ExpressionNode parseMulDiv(double xOffset, double yOffset) {
    ExpressionNode node = parsePower(xOffset, yOffset);
    while (!isAtEnd && (current == '*' || current == '/' || current == '\u00F7' || current == '\u00B7')) {
      // String? currentOp = current;
      String token = consume();
      ExpressionNode op = OperatorNode(token, [pos-1]);

      if (isAtEnd) {
        ExpressionNode oldNode = node;
        node = BinaryOpNode(node, op, IncompleteNode(), [pos-1]);
        node.tree = {
        'left': {'value': oldNode.tree.isEmpty ? oldNode.toString() : oldNode.tree,
                            'positions': oldNode.positions,
                            'kind': oldNode.kind},
          'op': {'value': op.toString(),
                    'kind': op.kind},
          'right': {'value': IncompleteNode().toString(),
                                'kind': 'IncompleteNode'}
          };
        return node;
      }

      // save old node
      ExpressionNode oldNode = node;
      ExpressionNode right;

      if (token == '/' || token == '\u00F7') {
        // update nodes y offset 
        for (var sublist in oldNode.positions) {
            sublist[1] += 0.1 + yOffset;  // Add 0.5 to every second element
        }
        
        // offset denominator
        yOffset -= 0.1;
        right = parsePower(xOffset, yOffset);
        for (var sublist in right.positions) {
            sublist[1] = yOffset;  // Add 0.5 to every second element
        }
      } else {
        right = parsePower(xOffset, yOffset);
      }
      node = BinaryOpNode(node, op, right, [pos-1]);
      
      node.tree = {
        'left': {'value': oldNode.tree.isEmpty ? oldNode.toString() : oldNode.tree,
                            'positions': oldNode.positions,
                            'kind': oldNode.kind},
        'op': {'value': op.toString(),
                  'positions': op.positions,
                  'kind': op.kind},
        "right": {'value': right.tree.isEmpty ? right.toString() : right.tree,
                              'positions': right.positions,
                              'kind': right.kind}
      };
    }
    return node;
  }

  ExpressionNode parsePower(double xOffset, double yOffset) {
    ExpressionNode node = parsePrimary(xOffset, yOffset);
    while (!isAtEnd && current == '^') {
      String token = consume();

      ExpressionNode op = OperatorNode(token, [pos-1]);
      if (isAtEnd) {

        ExpressionNode oldNode = node;
        node = BinaryOpNode(node, op, IncompleteNode(), [pos-1]);
        node.tree = {
        'left': {'value': oldNode.tree.isEmpty ? oldNode.toString() : oldNode.tree,
                            'positions': oldNode.positions,
                            'kind': oldNode.kind},
          'op': {'value': op.toString(),
                    'kind': op.kind},
          'right': {'value': IncompleteNode().toString(),
                                'kind': 'IncompleteNode'}
          };
        return node;
      }
      // save old node
      ExpressionNode oldNode = node;

      yOffset += 0.95;
      print('yOffset $yOffset ${oldNode.positions}');

      ExpressionNode right = parsePower(xOffset, yOffset);
      
      if (token == '^') {
        // update nodes y offset 
        for (var sublist in right.positions) {
            sublist[1] = yOffset;  // Add 0.5 to every second element
        }
      }

      node = BinaryOpNode(node, op, right, [pos-1]);
      
      node.tree = {
        'left': {'value': oldNode.tree.isEmpty ? oldNode.toString() : oldNode.tree,
                            'positions': oldNode.positions,
                            'kind': oldNode.kind},
        'op': {'value': op.toString(),
                  'positions': op.positions,
                  'kind': op.kind},
        "right": {'value': right.tree.isEmpty ? right.toString() : right.tree,
                              'positions': right.positions,
                              'kind': right.kind}
      };
    }
    return node;
  }

  ExpressionNode parsePrimary(double xOffset, double yOffset) {
    if (current == null) return IncompleteNode();

    if (isAlphaChar(current!)) {
      String id = consume();
      print(id);
  
      if (!isAtEnd && current == '(') {
        consume(); // consume '('
        List<ExpressionNode> args = [];
        if (current != ')') {
          args.add(parseExpression());
          while (!isAtEnd && current == ',') {
            consume();
            args.add(parseExpression());
          }
        }
        if (current == ')') {
          consume(); // consume ')'
        } else {
          return IncompleteNode();
        }
        ExpressionNode node = FunctionNode(id, args, [pos-1]);
        // Map<String, dynamic> argsTree = {};
        // for (int i = 0; i < args.length; i++) {
        //   argsTree[args[i].kind] = args[i].tree.isEmpty ? args[i].toString() : args[i].tree;
        // }
        node.tree = {
          'function': id.toString(),
          "parameter": args.isEmpty 
                       ? IncompleteNode() 
                       : (args.length == 1 ? (args[0].tree.isEmpty ? args[0].toString() : args[0].tree) : args[0].tree)
        };
        return node;
      } else {
        return VariableNode(id, [pos-1]);
      }
    } else if (current == '(') {
      consume(); // consume '('
      ExpressionNode node = parseExpression();
      
      if (current == ')') {
        consume(); // consume ')'
      } else {
        return IncompleteNode();
      }
      return node;
    } else {
      return parseNumber(xOffset, yOffset);
    }
  }

  ExpressionNode parseNumber(double xOffset, double yOffset) {
    String token = consume();
    List <dynamic> positions = [];
    for (int i = 0; i < token.length; i++){
      // positions.add(Offset(currentX+i, 0, 1, 1)); // to replace with x and y
      positions.add([currentX+i + xOffset, 0 + yOffset, 1, 1]); // to replace with x and y
    }
    currentX += token.length;
    ExpressionNode node = NumberNode(num.tryParse(token) ?? 0, positions, [pos-1]);
    print(node.positions);
    // node.positions = positions;

    return node;
  }
}

void main() {
  List<String> expressions = [
    // "123 + 2456",
    // '7/ + 90+7865 + 56^98',
    // "2/5",
    // "((12 + 13)/2)/",
    "3 + 4 * (2 - 1) /",
    // "sin(30) + cos(45)",
    // "2^3^2/6 - 90 + 56/89/9",
    // "2^3^2",
    // '2 + 7/4/2'
    // "log(100,10)",
    // "sqrt(16+89/7+90-6) + 65",
    // "x + y",
    // "45+25÷(21-6)\u00B72"
  ];

  for (var expr in expressions) {
    print("Expression: $expr");
    List<String> tokens = tokenize(expr);
    print(tokens);

    Parser parser = Parser(tokens);

    ExpressionNode ast = parser.parseExpression();
    print("AST: ${ast.toString()}\n");
    print(JsonEncoder.withIndent('    ').convert(ast.tree));
    print('');
  }
}
