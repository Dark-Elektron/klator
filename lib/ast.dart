import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:klator/constants.dart';


void printMap(Map<dynamic, dynamic> map, {String indent = ''}) {
  map.forEach((key, value) {
    if (value is Map) {
      print('$indent$key: {');
      printMap(value, indent: '$indent\t');
      print('$indent}');
    } else {
      print('$indent$key: $value');
    }
  });
}

abstract class ExpressionNode {
  String kind = 'ExpressionNode';
  Map<String, dynamic> tree = {};
  List<dynamic> box = [];
  double width = 0;
  double height = 0;
  dynamic fontScale = 1;
  List<String> trail = [];

  @override
  String toString();
}

class NumberNode extends ExpressionNode {
  final num value;
  // List<Offset> box;
  List<dynamic> box;
  List<int> index;

  NumberNode(this.value, this.box, this.index){kind='NumberNode';}

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
    if ('+−-*\u00B7/\u00F7^(),'.contains(char)) {
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
  double currentY = 0;

  Parser(this.tokens);

  String? get current => pos < tokens.length ? tokens[pos] : null;
  bool get isAtEnd => pos >= tokens.length;

  String consume() => tokens[pos++];

    ExpressionNode parseExpression({double offsetX = 0, double offsetY = 0, double fontScale = 1}) {

        ExpressionNode node = parseAddSub(offsetX, offsetY, fontScale: fontScale);

        double width = getTreeSize(node.tree, 'width');
        double height = getTreeSize(node.tree, 'height');
        
        node.tree = {
        'value': node.tree.isEmpty ? node.toString() : node.tree,
        'kind': node.kind,
        // 'box': [Box(offsetX, offsetY, width, height), Box(currentX, currentY, width, height)],
        'box': [Box(offsetX, offsetY, width, height)],
        'width': width,
        'height': height
        };
        return node;
    }

    ExpressionNode parseAddSub(double offsetX, double offsetY, {double fontScale=1}) {

        ExpressionNode node = parseMulDiv(offsetX, offsetY, fontScale: fontScale);

        while (!isAtEnd && (current == '+' || current == '−')) {

            String token = consume();
            ExpressionNode op = OperatorNode(token, [pos-1]);
            
            final textPainter = textDimensions(token); //calculate operator size
            op.width = textPainter.width;
            op.height = textPainter.height;

            op.box = [Box(currentX, currentY, op.width, op.height)];
            currentX += textPainter.width;
            op.box.add(Box(currentX, currentY, op.width, op.height));

            if (isAtEnd) {
                ExpressionNode oldNode = node;
                node = BinaryOpNode(node, op, IncompleteNode(), [pos-1]);
                node.tree = _buildTree(oldNode, op, IncompleteNode());
                return node;
            }

            ExpressionNode right = parseMulDiv(currentX, currentY, fontScale: fontScale);
            ExpressionNode oldNode = node;
            //   List <dynamic> box = [];
            //   for (int i = 0; i < token.length; i++){
            //     box.add([currentX+i+currentX, 0+currentY, 1, 1]);
            //   }

            node = BinaryOpNode(oldNode, op, right, [pos-1]);
            node.tree = _buildTree(oldNode, op, right);
        }
        return node;
    }

    ExpressionNode parseMulDiv(double offsetX, double offsetY, {double fontScale=1}) {

    ExpressionNode node = parsePower(offsetX, offsetY, fontScale: fontScale);

    while (!isAtEnd && (current == '*' || current == '/' || current == '\u00F7' || current == '\u00B7')) {
      // String? currentOp = current;
      String token = consume();
      ExpressionNode op = OperatorNode(token, [pos-1]);
      
      final textPainter = textDimensions(token); //calculate operator size
      op.width = textPainter.width;
      op.height = textPainter.height;

      op.box = [Box(currentX, currentY, op.width, op.height)];
      currentX += textPainter.width;
      op.box.add(Box(currentX, currentY, op.width, op.height));

      if (isAtEnd) {
        ExpressionNode oldNode = node;
        node = BinaryOpNode(node, op, IncompleteNode(), [pos-1]);
        node.tree = _buildTree(oldNode, op, IncompleteNode());
        return node;
      }

      // save old node
      ExpressionNode oldNode = node;
      ExpressionNode right;


      if (token == '/' || token == '\u00F7') {
        
        right = parsePower(offsetX, currentY, fontScale: fontScale);
        currentX -= min(node.width, right.width) + op.width; // decrement currentX by the minimum of num and den

        // update nodes offset 
        for (var sublist in oldNode.box) {
            sublist.offsetY -= oldNode.height/2;
            if (oldNode.width < right.width) {
                sublist.offsetX += (right.width - oldNode.width)/2;
            }

            op.width = 0;
            op.height = 0;
            op.box = [];
        }
        
        for (var sublist in right.box) {
            sublist.offsetY += right.height/2;

            if (oldNode.width > right.width) {
                sublist.offsetX += (oldNode.width - right.width)/2;
            }
        }
      } else {
        right = parsePower(currentX, currentY, fontScale: fontScale);
      }
      
      node = BinaryOpNode(node, op, right, [pos-1]);
      node.tree = _buildTree(oldNode, op, right);
    }
    return node;
  }

    ExpressionNode parsePower(double offsetX, double offsetY, {double fontScale=1}) {

        ExpressionNode node = parsePrimary(offsetX, offsetY, fontScale: fontScale);

        while (!isAtEnd && current == '^') {
            String token = consume();

            ExpressionNode op = OperatorNode(token, [pos-1]);
            
            final textPainter = textDimensions(token); //calculate operator size
            op.width = textPainter.width;
            op.height = textPainter.height;

            op.box = [Box(currentX, currentY, op.width, op.height)];
            currentX += textPainter.width;
            op.box.add(Box(currentX, currentY, op.width, op.height));

            if (isAtEnd) {
                ExpressionNode oldNode = node;
                node = BinaryOpNode(node, op, IncompleteNode(), [pos-1]);
                node.tree = 
                node.tree = _buildTree(oldNode, op, IncompleteNode);
                    return node;
            }
            // save old node
            ExpressionNode oldNode = node;

            ExpressionNode right = parsePower(currentX, currentY, fontScale: 0.8);
            
            if (token == '^') {
                currentX -= op.width; // decrement currentX by the op width

                // update nodes y offset 
                for (var sublist in right.box) {
                    sublist.offsetY = offsetY;
                }

                op.width = 0;
                op.height = 0;
                op.box = [];
            }
        
            for (var sublist in right.box) {
                sublist.offsetY += right.height/2;

                if (oldNode.width > right.width) {
                    sublist.offsetX += (oldNode.width - right.width)/2;
                }
            }

            node = BinaryOpNode(node, op, right, [pos-1]);
            node.tree = _buildTree(oldNode, op, right);
        }
        return node;
    }

    ExpressionNode parsePrimary(double offsetX, double offsetY, {double fontScale=1}) {
        if (current == null) return IncompleteNode();

        if (isAlphaChar(current!)) {
        String id = consume();
    
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
          return parseNumber(offsetX, offsetY, fontScale: fontScale);
        }
    }

    ExpressionNode parseNumber(double offsetX, double offsetY, {double fontScale=1}) {
        String token = consume();
		if (token == '') {
			token = '[]';
		}
        List <dynamic> box = [];
        double nodeWidth = 0;
        
        for (int i = 0; i < token.length; i++){
            final textPainter = textDimensions(token[i], fontScale: fontScale);
            box.add(Box(offsetX+nodeWidth, 0, textPainter.width, textPainter.height));
            nodeWidth += textPainter.width; // increment parent node size
        }
        ExpressionNode node = NumberNode(num.tryParse(token) ?? 0, box, [pos-1]);

        currentX += nodeWidth;
        node.width = nodeWidth;
        node.height = textDimensions(token).height;
        node.fontScale = fontScale;
        return node;
    }

    TextPainter textDimensions(String char, {double fontScale=1}) {
        double fontSize = fontScale*FONTSIZE;
        return TextPainter(
					text: TextSpan(text: char, style: TextStyle(color: Colors.white, fontSize: fontSize)),
					textDirection: TextDirection.ltr,
				)..layout();
  }

    Map<String, dynamic> _buildTree(dynamic left, dynamic op, dynamic right) {
		
        double leftWidth  = left.tree.isEmpty ? left.width  : left.tree['width'];
        double opWidth    = op.tree.isEmpty   ? op.width    : op.tree['width'];
        double rightWidth = right.tree.isEmpty ? right.width : right.tree['width'];

        double leftHeight  = left.tree.isEmpty ? left.height  : left.tree['height'];
        double opHeight    = op.tree.isEmpty   ? op.height    : op.tree['height'];
        double rightHeight = right.tree.isEmpty ? right.height : right.tree['height'];

        double width;
        double height;
        double baseline; // The top (baseline) of the fraction; we'll force this to be 0.0.
        List<Box> box = [];

        if (op.toString() == '/') {
            // For division nodes:
            // Parent width is the maximum of numerator and denominator widths.
            width = max(leftWidth, rightWidth);
            // Parent height is the sum of numerator and denominator heights.
            height = leftHeight + rightHeight;
            // Top down: the highest point is 0.0 (a double).
            baseline = 0.0;

            // Adjust numerator: force its boxes to start at y = 0.0.
            if (left.tree.isEmpty) {
                for (var b in left.box) {
                    b.offsetY = 0.0;
                }
            } else if (left.tree.containsKey('box')) {
                for (var b in left.tree['box']) {
                    b.offsetY = 0.0;
                }
            }

            // Adjust denominator: push its boxes down by the height of the numerator.
            if (right.tree.isEmpty) {
                for (var b in right.box) {
                    b.offsetY = leftHeight;
                }
            } else if (right.tree.containsKey('box')) {
                for (var b in right.tree['box']) {
                    b.offsetY = leftHeight;
                }
            }

            // Build the parent's boxes with top = 0.0.
            Box leftBox = left.tree.isEmpty ? left.box[0] : left.tree['box'][0];
            Box rightBox0 = right.tree.isEmpty
                            ? right.box[0]
                            : right.tree['box'][0];

            box.add(Box(min(leftBox.offsetX, rightBox0.offsetX), 0.0, width, height));

            // Box rightBox = right.tree.isEmpty
            //                 ? right.box[right.box.length - 1]
            //                 : right.tree['box'][right.tree['box'].length - 1];
            // box.add(Box(max(leftBox.offsetX, rightBox.offsetX), 0.0, width, height));
        } else if (op.toString() == '^') {
            // For division nodes:
            // Parent width is the maximum of numerator and denominator widths.
            width = leftWidth + rightWidth;
            // Parent height is the sum of numerator and denominator heights.
            height = -0.5*leftHeight/2;
            // Top down: the highest point is 0.0 (a double).
            baseline = 0.0;

            // Adjust numerator: force its boxes to start at y = 0.0.
            if (left.tree.isEmpty) {
                for (var b in left.box) {
                    b.offsetY = 0.0;
                }
            } else if (left.tree.containsKey('box')) {
                for (var b in left.tree['box']) {
                    b.offsetY = 0.0;
                }
            }

            // Adjust denominator: push its boxes down by the height of the numerator.
            if (right.tree.isEmpty) {
                for (var b in right.box) {
                    b.offsetY = height;
                }
            } else if (right.tree.containsKey('box')) {
                for (var b in right.tree['box']) {
                    b.offsetY = height;
                }
            }

            // Build the parent's boxes with top = 0.0.
            Box leftBox = left.tree.isEmpty ? left.box[0] : left.tree['box'][0];
            Box rightBox0 = right.tree.isEmpty
                            ? right.box[0]
                            : right.tree['box'][0];

            box.add(Box(min(leftBox.offsetX, rightBox0.offsetX), 0.0, width, height));

            // Box rightBox = right.tree.isEmpty
            //                 ? right.box[right.box.length - 1]
            //                 : right.tree['box'][right.tree['box'].length - 1];
            // box.add(Box(max(leftBox.offsetX, rightBox.offsetX), 0.0, width, height));
        } else {
            // For non-division nodes, use your existing logic.
            width = leftWidth + opWidth + rightWidth;
            height = max(leftHeight, max(opHeight, rightHeight));
            Box leftBox = left.tree.isEmpty ? left.box[0] : left.tree['box'][0];
            baseline = leftBox.offsetY; // For non-fractions, baseline remains as given.
            box.add(Box(leftBox.offsetX, baseline, width, height));

            // Box rightBox = right.tree.isEmpty
            //                 ? right.box[right.box.length - 1]
            //                 : right.tree['box'][right.tree['box'].length - 1];
            // box.add(Box(rightBox.offsetX, baseline, width, height));
        }

		List<String> leftTrail = left.tree.isEmpty ? [...left.trail, 'value', 'left'] : [...left.tree['trail'], 'value', 'left'];
		List<String> opTrail = op.tree.isEmpty ? [...op.trail, 'value', 'op'] : [...op.tree['trail'], 'value', 'op'];
		List<String> rightTrail = right.tree.isEmpty ? [...right.trail, 'value', 'right'] : [...right.tree['trail'], 'value', 'right'];

		// update trail
		left.tree.isEmpty ? left.trail = leftTrail : left.tree['trail'] = leftTrail;
		op.tree.isEmpty ? op.trail = opTrail : op.tree['trail'] = opTrail;
		right.tree.isEmpty ? right.trail = rightTrail : right.tree['trail'] = rightTrail;

		
        print('trail old node ${left.trail}');
        return {
            'left': {
                'value': left.tree.isEmpty ? left.toString() : left.tree,
                'box': left.tree.isEmpty ? left.box : left.tree['box'],
                'kind': left.kind,
                'width': leftWidth,
                'height': leftHeight,
                'fontscale': left.fontScale,
				'trail': leftTrail
            },
            'op': {
                'value': op.toString(),
                'box': op.box,
                'kind': op.kind,
                'width': opWidth,
                'height': opHeight,
                'fontscale': op.fontScale,
				'trail': opTrail
            },
            "right": {
                'value': right.tree.isEmpty ? right.toString() : right.tree,
                'box': right.tree.isEmpty ? right.box : right.tree['box'],
                'kind': right.kind,
                'width': rightWidth,
                'height': rightHeight,
                'fontscale': right.fontScale,
				'trail': rightTrail
            },
            'kind': 'BinaryNode',
            'box': box,
            'width': width,
            'height': height,
            'baseline': baseline,
            'fontscale': [left.fontScale, right.fontScale],
			'trail': [...left.trail, 'value']
        };
        }


    double getTreeSize(dynamic nodeTree, String which){
            if (nodeTree['kind'] == 'BinaryNode') {
            if (which == 'width') {
                return nodeTree['left'][which] + nodeTree['op'][which] + nodeTree['right'][which];
            } else {
                return max(nodeTree['left'][which], max(nodeTree['op'][which], nodeTree['right'][which]));
            }
            } else {
            print('node tree here ${nodeTree['kind']}');
            return 0;
            }
        }

}

class Box {
	double offsetX;
	double offsetY;
	double width;
	double height;

	Box(this.offsetX, this.offsetY, this.width, this.height);
  
	bool inBox(pos) {
		bool leftRight = pos.dx >= offsetX && pos.dx <= offsetX + width;
		bool topBottom = pos.dy >= offsetY && pos.dy <= offsetY + height;
		
		if (leftRight && topBottom){
			return true;
		} else {
			return false;
		}
	}

  @override
  String toString() {
    return 'Box([$offsetX, $offsetY, $width, $height])';
  }
}

Box? findSmallestContainingBox(Map<String, dynamic> node, double dx, double dy, {List<String>? trail}) {
  trail ??= []; // If trail is null, assign a new empty list.
  // If there's no "box" property, nothing to check here.
  if (!node.containsKey("box")) return null;

  Box? bestBox;

  // Check all boxes at the current node.
  List<dynamic> boxList = node["box"] ?? [];
  for (var item in boxList) {
    if (item is Box && item.inBox(Offset(dx, dy))) {
      if (bestBox == null || (item.width * item.height) < (bestBox.width * bestBox.height)) {
        bestBox = item;
      }
    }
  }

  // Now, if the node has a "value" and it is a Map, iterate over its keys.
  if (node.containsKey("value") && node["value"] is Map<String, dynamic>) {
    var children = node["value"] as Map<String, dynamic>;
    for (var key in children.keys) {
      var child = children[key];
      // Only consider child nodes that are Maps and have a "box" property.
      if (child is Map<String, dynamic> && child.containsKey("box")) {
        Box? candidate = findSmallestContainingBox(child, dx, dy, trail: trail);
        if (candidate != null) {
          if (bestBox == null || (candidate.width * candidate.height) < (bestBox.width * bestBox.height)) {
            bestBox = candidate;
          }
        }
      }
    }
  }

    // If a best box is found, decide which edge (left or right) is closer to the given x-coordinate.
	print('trail: $trail');
    if (bestBox != null) {
        return getCorrectEdge(bestBox, dx, dy);
    }

  return null;
}

Box getCorrectEdge (Box box, double dx, double dy) {
    double leftEdge = box.offsetX;
    double rightEdge = box.offsetX + box.width;
    double distanceToLeft = (dx - leftEdge).abs();
    double distanceToRight = (rightEdge - dx).abs();
    
    // Return a new Box with zero width placed at the closer edge.
    if (distanceToLeft <= distanceToRight) {
      return Box(leftEdge, box.offsetY, 0, box.height);
    } else {
      return Box(rightEdge, box.offsetY, 0, box.height);
    }
}


void main() {
  List<String> expressions = [
    // "12 + ",
    // "2/5",
    // "((12 + 13)/2)/",
    // "3 + 4 * (2 - 1) /",
    // "sin(30) + cos(45)",
    // "2^3^2/6 - 90 + 56/89/9",
    // "2^3^2",
    '7/4/2'
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
