import 'package:flutter/material.dart';
import 'package:klator/constants.dart';
import 'dart:math';
import 'ast.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;

  const CustomTextField({super.key, required this.controller});

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField>
    with SingleTickerProviderStateMixin {
  late Box cursor = Box(0, 0, 0, 0);
  late final AnimationController _cursorBlinkController;
  late final Animation<double> _cursorBlinkAnimation;
  late final Map<String, dynamic> rootNode;
  late double mathTextEditorWidth;
  late double mathTextEditorHeight;

  @override
  void initState() {
    // List<String> tokens = tokenize('7/3487 + 90+7865 + 56^98');
    // List<String> tokens = tokenize('2+7\u00B7 4');
    List<String> tokens = tokenize('2 + 7/48');
    Parser parser = Parser(tokens);
    ExpressionNode ast = parser.parseExpression();
    print("AST: ${ast.toString()}\n");
    rootNode = ast.tree;
    mathTextEditorWidth = rootNode['width'];
    mathTextEditorHeight = rootNode['height'];
    printMap(rootNode);

    super.initState();
    _cursorBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    
    _cursorBlinkAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(_cursorBlinkController);
  }

  @override
  void dispose() {
    _cursorBlinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (TapDownDetails details) {
        setState(() {
          Offset position = details.localPosition; // Relative to the widget
          print('\n tapposition (${position.dx}, ${position.dy}) \n');
          Box? box = findSmallestContainingBox(
            rootNode,
            position.dx,
            position.dy,
          );
          print('found $box');
          box ??=
              rootNode['box'][0]; // If a best box is found, decide which edge (left or right) is closer to the given x-coordinate.

          box = getCorrectEdge(box!, position.dx, position.dy);
          cursor = box;
        });
      },
      child: AnimatedBuilder(
        animation: _cursorBlinkController,
        builder: (context, child) {
          return CustomPaint(
            painter: MathExpressionPainter(
              rootNode,
              cursor,
              _cursorBlinkAnimation.value > 0.5,
            ),
            foregroundPainter: BorderPainter(
              borderColor: Colors.grey,
              borderWidth: 2.0,
            ),
            size: Size(400, mathTextEditorHeight),
          );
        },
      ),
    );
  }
}

class MathExpressionPainter extends CustomPainter {
  final Map<String, dynamic> rootNode;
  final Box cursor;
  final bool showCursor;
  static const double boxWidth = 20;
  static const double boxHeight = 40;
  static const double boxPadding = 5;
  static const double parenthesisPadding = 2;

  MathExpressionPainter(this.rootNode, this.cursor, this.showCursor);

  @override
  void paint(Canvas canvas, Size size) {
    double totalExpressionWidth = rootNode['width'];
    double totalExpressionHeight = rootNode['height'];
    // print('expression width $totalExpressionWidth');
    // double startX = (size.width - totalExpressionWidth) / 2;
    double startX = 0;

    // _drawNode(canvas, rootNode, startX, size.height / 2);
    _drawNode(canvas, rootNode, startX, 17.5);

    if (showCursor) {
      final cursorPaint =
          Paint()
            ..color = Colors.yellow
            ..strokeWidth = 2.0;

      canvas.drawLine(
        Offset(
          startX + cursor.offsetX,
          17.5 + cursor.offsetY - cursor.height / 2,
        ),
        Offset(
          startX + cursor.offsetX,
          17.5 + cursor.offsetY + cursor.height / 2,
        ),
        cursorPaint,
      );
    }
  }

  double _drawNode(Canvas canvas, dynamic tree, double x, double y) {
    double startX = x;

    if (tree['kind'] == 'FunctionNode') {
      _drawText(canvas, tree["left"]['value'], startX, y);
      startX += boxWidth + boxPadding;
      _drawText(canvas, "(", startX, y);
      startX += parenthesisPadding;
      double enclosedWidth = _drawNode(canvas, tree["left"], startX, y);
      startX += enclosedWidth + parenthesisPadding;
      _drawText(canvas, ")", startX, y);
      startX += boxWidth / 2;

      return boxWidth + enclosedWidth + 2 * parenthesisPadding;
    }

    if (tree['kind'] == 'BinaryNode') {
      if (tree['value']['op']['value'] == '/') {
        dynamic left = tree['value']["left"];
        // dynamic op = tree['value']["op"];
        dynamic right = tree['value']["right"];

        double numeratorWidth = left['width'];
        double denominatorWidth = right['width'];
        double fractionWidth = max(numeratorWidth, denominatorWidth);

        _drawNode(
          canvas,
          tree['value']['left'],
          startX + (fractionWidth - numeratorWidth) / 2,
          y + left['box'][0].offsetY,
        );
        _drawNode(
          canvas,
          tree['value']['right'],
          startX + (fractionWidth - denominatorWidth) / 2,
          y + right['box'][0].offsetY,
        );

        final linePaint =
            Paint()
              ..color = Colors.white
              ..strokeWidth = 1.50;
        double divLineOffsetY =
            17.5 + right['box'][0].offsetY - right['box'][0].height / 2;
        canvas.drawLine(
          Offset(startX, divLineOffsetY),
          Offset(startX + fractionWidth, divLineOffsetY),
          linePaint,
        );

        return fractionWidth;
      } else if (tree['value']['op']['value'] == '^') {
        dynamic left = tree['value']["left"];
        // dynamic op = tree['value']["op"];
        dynamic right = tree['value']["right"];

        double numeratorWidth = left['width'];
        double denominatorWidth = right['width'];
        double fractionWidth = max(numeratorWidth, denominatorWidth);

        _drawNode(
          canvas,
          tree['value']['left'],
          startX,
          y + left['box'][0].offsetY,
        );
        startX += left['width'];

        _drawNode(
          canvas,
          tree['value']['right'],
          startX,
          y + right['box'][0].offsetY,
        );

        return fractionWidth;
      } else {
        dynamic left = tree['value']["left"];
        dynamic op = tree['value']["op"];
        dynamic right = tree['value']["right"];

        _drawNode(canvas, left, startX, y);
        startX += left['width'];

        _drawText(canvas, op['value'], startX, y);
        startX += op['width'];

        _drawNode(canvas, right, startX, y);
        startX += right['width'];
      }
    }

    if (tree['kind'] == 'NumberNode') {
      double fontSize = tree['fontscale'] * FONTSIZE;

      final textPainter = TextPainter(
        text: TextSpan(
          text: tree['value'],
          style: TextStyle(color: Colors.white, fontSize: fontSize),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      // textPainter.paint(canvas, Offset(startX, y - textPainter.height / 2));
      textPainter.paint(canvas, Offset(startX, y - tree['height'] / 2));
    }

    return 0;
  }

  void _drawText(Canvas canvas, String text, double x, double y) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white, fontSize: FONTSIZE),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(x, y - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }

  bool _isFunction(String value) {
    return value == 'sqrt' ||
        value == 'log' ||
        value == 'sin' ||
        value == 'cos';
  }
}

// class ExpressionNode {
//   String value;
//   ExpressionNode? left, right;
//   ExpressionNode(this.value, {this.left, this.right});
// }

// ExpressionNode buildExpressionTree() {
//   return ExpressionNode(
//     "+",
//     left: ExpressionNode(
//       "sqrt",
//       left: ExpressionNode(
//         "+",
//         left: ExpressionNode("16"),
//         right: ExpressionNode(
//           "/",
//           left: ExpressionNode("89"),
//           right: ExpressionNode("7"),
//         ),
//       ),
//     ),
//     right: ExpressionNode("65"),
//   );
// }
class BorderPainter extends CustomPainter {
  final Color borderColor;
  final double borderWidth;

  BorderPainter({this.borderColor = Colors.black, this.borderWidth = 2.0});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint =
        Paint()
          ..color = borderColor
          ..strokeWidth = borderWidth
          ..style = PaintingStyle.stroke;
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
