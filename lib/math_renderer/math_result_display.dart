import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'math_nodes.dart';
import 'math_text_style.dart';
import '../utils/constants.dart';

/// A read-only widget for displaying MathNode results (no editing, no cursor)
class MathResultDisplay extends StatelessWidget {
  final List<MathNode> nodes;
  final double fontSize;
  final Color textColor;
  final TextScaler textScaler;

  const MathResultDisplay({
    super.key,
    required this.nodes,
    this.fontSize = FONTSIZE,
    this.textColor = Colors.white,
    this.textScaler = TextScaler.noScaling,
  });

  /// Calculate estimated total height of a node list given a font size.
  static double calculateTotalHeight(List<MathNode> nodes, double fontSize) {
    if (nodes.isEmpty) return 0;
    final lines = _staticSplitIntoLines(nodes);
    double total = 0;
    for (int i = 0; i < lines.length; i++) {
      total += calculateLineHeight(lines[i], fontSize);
      if (i < lines.length - 1) {
        total += 4; // Padding(vertical: 2) between lines
      }
    }
    return total;
  }

  /// Calculate estimated height of a single line of nodes.
  static double calculateLineHeight(List<MathNode> nodes, double fontSize) {
    if (nodes.isEmpty) return fontSize;
    double maxAbove = 0;
    double maxBelow = 0;
    for (final node in nodes) {
      final (height, offset) = _staticGetNodeMetrics(node, fontSize);
      if (height > 0) {
        maxAbove = math.max(maxAbove, height - offset);
        maxBelow = math.max(maxBelow, offset);
      }
    }
    return maxAbove + maxBelow;
  }

  static List<List<MathNode>> _staticSplitIntoLines(List<MathNode> nodes) {
    List<List<MathNode>> lines = [];
    List<MathNode> currentLine = [];
    for (var node in nodes) {
      if (node is NewlineNode) {
        if (currentLine.isNotEmpty) {
          lines.add(List.from(currentLine));
          currentLine = [];
        }
      } else {
        currentLine.add(node);
      }
    }
    if (currentLine.isNotEmpty) lines.add(currentLine);
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return const SizedBox.shrink();
    }

    final lines = _splitIntoLines(nodes);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children:
          lines.map((line) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _renderNodeList(line, fontSize),
              ),
            );
          }).toList(),
    );
  }

  List<List<MathNode>> _splitIntoLines(List<MathNode> nodes) {
    List<List<MathNode>> lines = [];
    List<MathNode> currentLine = [];

    for (var node in nodes) {
      if (node is NewlineNode) {
        if (currentLine.isNotEmpty) {
          lines.add(List.from(currentLine));
          currentLine = [];
        }
      } else {
        currentLine.add(node);
      }
    }
    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }
    return lines;
  }

  List<Widget> _renderNodeList(List<MathNode> nodes, double fontSize) {
    if (nodes.isEmpty) return [];

    double maxAbove = 0;
    double maxBelow = 0;

    for (final node in nodes) {
      final (height, offset) = _getNodeMetrics(node, fontSize);
      if (height > 0) {
        maxAbove = math.max(maxAbove, height - offset);
        maxBelow = math.max(maxBelow, offset);
      }
    }

    return nodes.asMap().entries.map((e) {
      final node = e.value;
      final (height, offset) = _getNodeMetrics(node, fontSize);
      final topPadding = maxAbove - (height - offset);

      return Padding(
        padding: EdgeInsets.only(
          left: 1.5,
          right: 1.5,
          top: math.max(0, topPadding),
        ),
        child: _renderNode(node, fontSize),
      );
    }).toList();
  }

  Widget _renderNode(MathNode node, double fontSize) {
    if (node is LiteralNode) {
      if (node.text.isEmpty) {
        return const SizedBox.shrink();
      }
      return Text(
        MathTextStyle.toDisplayText(node.text),
        style: MathTextStyle.getStyle(fontSize).copyWith(color: textColor),
        textScaler: textScaler,
      );
    }

    if (node is ConstantNode) {
      return Text(
        MathTextStyle.toDisplayText(node.constant),
        style: MathTextStyle.getStyle(fontSize).copyWith(color: textColor),
        textScaler: textScaler,
      );
    }

    if (node is FractionNode) {
      return IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _renderNodeList(node.numerator, fontSize),
            ),
            Container(
              height: math.max(1.5, fontSize * 0.06),
              width: double.infinity,
              color: textColor,
              margin: EdgeInsets.symmetric(vertical: fontSize * 0.15),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _renderNodeList(node.denominator, fontSize),
            ),
          ],
        ),
      );
    }

    if (node is ExponentNode) {
      final double powerSize =
          fontSize < FONTSIZE * 0.85 ? fontSize : fontSize * 0.8;
      final double fixedOffset = fontSize * -0.5;

      final powerMetrics = _getListMetrics(node.power, powerSize);
      final double powerHeight = powerMetrics.$1;
      final double baseTopPadding = powerHeight + fixedOffset;

      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: baseTopPadding),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _renderNodeList(node.base, fontSize),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _renderNodeList(node.power, powerSize),
          ),
        ],
      );
    }

    if (node is RootNode) {
      final double indexSize = fontSize * 0.7;
      final double minRadicandHeight = fontSize * 1.2;

      Widget? indexWidget;
      if (!node.isSquareRoot) {
        indexWidget = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _renderNodeList(node.index, indexSize),
        );
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (indexWidget != null)
            Padding(
              padding: const EdgeInsets.only(right: 1),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [indexWidget, SizedBox(height: fontSize * 0.35)],
              ),
            ),
          IntrinsicHeight(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minRadicandHeight),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: fontSize * 0.6,
                    child: CustomPaint(
                      painter: _RadicalPainter(
                        color: textColor,
                        strokeWidth: math.max(1.5, fontSize * 0.06),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: textColor,
                          width: math.max(1.5, fontSize * 0.06),
                        ),
                      ),
                    ),
                    padding: EdgeInsets.only(
                      left: 3,
                      right: 4,
                      top: fontSize * 0.08,
                      bottom: 2,
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _renderNodeList(node.radicand, fontSize),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (node is LogNode) {
      final double baseSize = fontSize * 0.8;

      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            node.isNaturalLog ? 'ln' : 'log',
            style: MathTextStyle.getStyle(fontSize).copyWith(color: textColor),
            textScaler: textScaler,
          ),
          if (!node.isNaturalLog)
            Padding(
              padding: EdgeInsets.only(left: 1, top: fontSize * 0.5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _renderNodeList(node.base, baseSize),
              ),
            ),
          if (node.isNaturalLog) SizedBox(width: fontSize * 0.05),
          IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ScalableParenthesis(
                  isOpening: true,
                  fontSize: fontSize,
                  color: textColor,
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: fontSize * 0.08,
                    vertical: fontSize * 0.1,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _renderNodeList(node.argument, fontSize),
                  ),
                ),
                _ScalableParenthesis(
                  isOpening: false,
                  fontSize: fontSize,
                  color: textColor,
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (node is TrigNode) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            node.function,
            style: MathTextStyle.getStyle(fontSize).copyWith(color: textColor),
            textScaler: textScaler,
          ),
          IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ScalableParenthesis(
                  isOpening: true,
                  fontSize: fontSize,
                  color: textColor,
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: fontSize * 0.25,
                    vertical: fontSize * 0.1,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _renderNodeList(node.argument, fontSize),
                  ),
                ),
                _ScalableParenthesis(
                  isOpening: false,
                  fontSize: fontSize,
                  color: textColor,
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (node is ParenthesisNode) {
      return IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ScalableParenthesis(
              isOpening: true,
              fontSize: fontSize,
              color: textColor,
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: fontSize * 0.15,
                vertical: fontSize * 0.1,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _renderNodeList(node.content, fontSize),
              ),
            ),
            _ScalableParenthesis(
              isOpening: false,
              fontSize: fontSize,
              color: textColor,
            ),
          ],
        ),
      );
    }

    if (node is PermutationNode) {
      final double smallSize = fontSize * 0.8;

      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _renderNodeList(node.n, smallSize),
              ),
              SizedBox(height: fontSize * 0.8),
            ],
          ),
          Text(
            'P',
            style: MathTextStyle.getStyle(fontSize).copyWith(color: textColor),
            textScaler: textScaler,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: fontSize * 0.8),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _renderNodeList(node.r, smallSize),
              ),
            ],
          ),
        ],
      );
    }

    if (node is CombinationNode) {
      final double smallSize = fontSize * 0.8;

      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _renderNodeList(node.n, smallSize),
              ),
              SizedBox(height: fontSize * 1.0),
            ],
          ),
          Text(
            'C',
            style: MathTextStyle.getStyle(fontSize).copyWith(color: textColor),
            textScaler: textScaler,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: fontSize * 0.8),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _renderNodeList(node.r, smallSize),
              ),
            ],
          ),
        ],
      );
    }

    if (node is AnsNode) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'ans',
            style: MathTextStyle.getStyle(
              fontSize,
            ).copyWith(color: Colors.orangeAccent),
            textScaler: textScaler,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _renderNodeList(node.index, fontSize),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  static (double, double) _staticGetNodeMetrics(
    MathNode node,
    double fontSize,
  ) {
    if (node is LiteralNode) {
      return (fontSize * 1.2, fontSize * 0.6);
    }

    if (node is ConstantNode) {
      return (fontSize * 1.2, fontSize * 0.6);
    }

    if (node is ExponentNode) {
      final double powerSize =
          fontSize < FONTSIZE * 0.85 ? fontSize : fontSize * 0.8;
      final baseMetrics = _staticGetListMetrics(node.base, fontSize);
      final powerMetrics = _staticGetListMetrics(node.power, powerSize);
      final double baseHeight = baseMetrics.$1;
      final double baseRef = baseMetrics.$2;
      final double powerHeight = powerMetrics.$1;
      final double fixedOffset = fontSize * -0.5;
      final double totalHeight = baseHeight + fixedOffset + powerHeight;
      return (totalHeight, baseRef);
    }

    if (node is FractionNode) {
      final numMetrics = _staticGetListMetrics(node.numerator, fontSize);
      final denMetrics = _staticGetListMetrics(node.denominator, fontSize);
      final double barHeight = math.max(1.5, fontSize * 0.06);
      final double margin = fontSize * 0.15;
      final numHeight = math.max(numMetrics.$1, fontSize * 0.8);
      final denHeight = math.max(denMetrics.$1, fontSize * 0.8);
      final height = numHeight + margin + barHeight + margin + denHeight;
      final offset = denHeight + margin + barHeight / 2;
      return (height, offset);
    }

    if (node is RootNode) {
      final radicandMetrics = _staticGetListMetrics(node.radicand, fontSize);
      final double minHeight = fontSize * 1.2;
      final double topPad = fontSize * 0.08;
      final double bottomPad = 2.0;
      final height = math.max(
        minHeight,
        radicandMetrics.$1 + topPad + bottomPad,
      );
      return (height, bottomPad + radicandMetrics.$2);
    }

    if (node is ParenthesisNode) {
      final contentMetrics = _staticGetListMetrics(node.content, fontSize);
      final double vPadding = fontSize * 0.1;
      final height = math.max(fontSize, contentMetrics.$1 + vPadding * 2);
      final offset = vPadding + contentMetrics.$2;
      return (height, offset);
    }

    if (node is TrigNode) {
      final argMetrics = _staticGetListMetrics(node.argument, fontSize);
      final double vPadding = fontSize * 0.1;
      final height = math.max(fontSize, argMetrics.$1 + vPadding * 2);
      return (height, vPadding + argMetrics.$2);
    }

    if (node is LogNode) {
      final argMetrics = _staticGetListMetrics(node.argument, fontSize);
      final double vPadding = fontSize * 0.1;
      final double argAreaHeight = argMetrics.$1 + vPadding * 2;
      double subscriptExtent = 0;
      if (!node.isNaturalLog) {
        final baseSize = fontSize * 0.8;
        final baseMetrics = _staticGetListMetrics(node.base, baseSize);
        subscriptExtent =
            fontSize * 0.5 +
            math.max(baseMetrics.$1, baseSize * 0.7) -
            fontSize;
        subscriptExtent = math.max(0, subscriptExtent);
      }
      final height = math.max(fontSize, argAreaHeight) + subscriptExtent;
      return (height, subscriptExtent + vPadding + argMetrics.$2);
    }

    if (node is PermutationNode) {
      final double smallSize = fontSize * 0.8;
      final nMetrics = _staticGetListMetrics(node.n, smallSize);
      final rMetrics = _staticGetListMetrics(node.r, smallSize);

      final double nHeight = math.max(nMetrics.$1, smallSize * 0.7);
      final double rHeight = math.max(rMetrics.$1, smallSize * 0.7);

      final double nColumnHeight = nHeight + fontSize * 0.8;
      final double rColumnHeight = fontSize * 0.8 + rHeight;

      final double height = math.max(
        fontSize,
        math.max(nColumnHeight, rColumnHeight),
      );
      return (height, height / 2);
    }

    if (node is CombinationNode) {
      final double smallSize = fontSize * 0.8;
      final nMetrics = _staticGetListMetrics(node.n, smallSize);
      final rMetrics = _staticGetListMetrics(node.r, smallSize);

      final double nHeight = math.max(nMetrics.$1, smallSize * 0.7);
      final double rHeight = math.max(rMetrics.$1, smallSize * 0.7);

      final double nColumnHeight = nHeight + fontSize * 1.0;
      final double rColumnHeight = fontSize * 0.8 + rHeight;

      final double height = math.max(
        fontSize,
        math.max(nColumnHeight, rColumnHeight),
      );
      return (height, height / 2);
    }

    if (node is AnsNode) {
      final indexMetrics = _staticGetListMetrics(node.index, fontSize);
      final height = math.max(fontSize, indexMetrics.$1);
      return (height, height / 2);
    }

    return (fontSize, fontSize / 2);
  }

  static (double, double) _staticGetListMetrics(
    List<MathNode> nodes,
    double fontSize,
  ) {
    if (nodes.isEmpty) {
      return (fontSize, fontSize / 2);
    }

    if (nodes.length == 1 && nodes.first is LiteralNode) {
      if ((nodes.first as LiteralNode).text.isEmpty) {
        return (fontSize, fontSize / 2);
      }
    }

    double maxAbove = 0;
    double maxBelow = 0;

    for (final node in nodes) {
      final (height, offset) = _staticGetNodeMetrics(node, fontSize);
      if (height > 0) {
        maxAbove = math.max(maxAbove, height - offset);
        maxBelow = math.max(maxBelow, offset);
      }
    }

    if (maxAbove == 0 && maxBelow == 0) {
      return (fontSize, fontSize / 2);
    }

    return (maxAbove + maxBelow, maxBelow);
  }

  (double, double) _getNodeMetrics(MathNode node, double fontSize) {
    if (node is LiteralNode) {
      return (fontSize * 1.2, fontSize * 0.6);
    }

    if (node is ConstantNode) {
      return (fontSize * 1.2, fontSize * 0.6);
    }

    if (node is ExponentNode) {
      final double powerSize =
          fontSize < FONTSIZE * 0.85 ? fontSize : fontSize * 0.8;
      final baseMetrics = _getListMetrics(node.base, fontSize);
      final powerMetrics = _getListMetrics(node.power, powerSize);
      final double baseHeight = baseMetrics.$1;
      final double baseRef = baseMetrics.$2;
      final double powerHeight = powerMetrics.$1;
      final double fixedOffset = fontSize * -0.5;
      final double totalHeight = baseHeight + fixedOffset + powerHeight;
      return (totalHeight, baseRef);
    }

    if (node is FractionNode) {
      final numMetrics = _getListMetrics(node.numerator, fontSize);
      final denMetrics = _getListMetrics(node.denominator, fontSize);
      final double barHeight = math.max(1.5, fontSize * 0.06);
      final double margin = fontSize * 0.15;
      final numHeight = math.max(numMetrics.$1, fontSize * 0.8);
      final denHeight = math.max(denMetrics.$1, fontSize * 0.8);
      final height = numHeight + margin + barHeight + margin + denHeight;
      final offset = denHeight + margin + barHeight / 2;
      return (height, offset);
    }

    if (node is RootNode) {
      final radicandMetrics = _getListMetrics(node.radicand, fontSize);
      final double minHeight = fontSize * 1.2;
      final double topPad = fontSize * 0.08;
      final double bottomPad = 2.0;
      final height = math.max(
        minHeight,
        radicandMetrics.$1 + topPad + bottomPad,
      );
      return (height, bottomPad + radicandMetrics.$2);
    }

    if (node is ParenthesisNode) {
      final contentMetrics = _getListMetrics(node.content, fontSize);
      final double vPadding = fontSize * 0.1;
      final height = math.max(fontSize, contentMetrics.$1 + vPadding * 2);
      final offset = vPadding + contentMetrics.$2;
      return (height, offset);
    }

    if (node is TrigNode) {
      final argMetrics = _getListMetrics(node.argument, fontSize);
      final double vPadding = fontSize * 0.1;
      final height = math.max(fontSize, argMetrics.$1 + vPadding * 2);
      return (height, vPadding + argMetrics.$2);
    }

    if (node is LogNode) {
      final argMetrics = _getListMetrics(node.argument, fontSize);
      final double vPadding = fontSize * 0.1;
      final double argAreaHeight = argMetrics.$1 + vPadding * 2;
      double subscriptExtent = 0;
      if (!node.isNaturalLog) {
        final baseSize = fontSize * 0.8;
        final baseMetrics = _getListMetrics(node.base, baseSize);
        subscriptExtent =
            fontSize * 0.5 +
            math.max(baseMetrics.$1, baseSize * 0.7) -
            fontSize;
        subscriptExtent = math.max(0, subscriptExtent);
      }
      final height = math.max(fontSize, argAreaHeight) + subscriptExtent;
      return (height, subscriptExtent + vPadding + argMetrics.$2);
    }

    if (node is PermutationNode) {
      final double smallSize = fontSize * 0.8;
      final nMetrics = _getListMetrics(node.n, smallSize);
      final rMetrics = _getListMetrics(node.r, smallSize);

      final double nHeight = math.max(nMetrics.$1, smallSize * 0.7);
      final double rHeight = math.max(rMetrics.$1, smallSize * 0.7);

      final double nColumnHeight = nHeight + fontSize * 0.8;
      final double rColumnHeight = fontSize * 0.8 + rHeight;

      final double height = math.max(
        fontSize,
        math.max(nColumnHeight, rColumnHeight),
      );
      return (height, height / 2);
    }

    if (node is CombinationNode) {
      final double smallSize = fontSize * 0.8;
      final nMetrics = _getListMetrics(node.n, smallSize);
      final rMetrics = _getListMetrics(node.r, smallSize);

      final double nHeight = math.max(nMetrics.$1, smallSize * 0.7);
      final double rHeight = math.max(rMetrics.$1, smallSize * 0.7);

      final double nColumnHeight = nHeight + fontSize * 1.0;
      final double rColumnHeight = fontSize * 0.8 + rHeight;

      final double height = math.max(
        fontSize,
        math.max(nColumnHeight, rColumnHeight),
      );
      return (height, height / 2);
    }

    if (node is AnsNode) {
      final indexMetrics = _getListMetrics(node.index, fontSize);
      final height = math.max(fontSize, indexMetrics.$1);
      return (height, height / 2);
    }

    return (fontSize, fontSize / 2);
  }

  (double, double) _getListMetrics(List<MathNode> nodes, double fontSize) {
    if (nodes.isEmpty) {
      return (fontSize, fontSize / 2);
    }

    if (nodes.length == 1 && nodes.first is LiteralNode) {
      if ((nodes.first as LiteralNode).text.isEmpty) {
        return (fontSize, fontSize / 2);
      }
    }

    double maxAbove = 0;
    double maxBelow = 0;

    for (final node in nodes) {
      final (height, offset) = _getNodeMetrics(node, fontSize);
      if (height > 0) {
        maxAbove = math.max(maxAbove, height - offset);
        maxBelow = math.max(maxBelow, offset);
      }
    }

    if (maxAbove == 0 && maxBelow == 0) {
      return (fontSize, fontSize / 2);
    }

    return (maxAbove + maxBelow, maxBelow);
  }
}

/// Simple radical painter for read-only display
class _RadicalPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _RadicalPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final path = Path();
    double width = size.width;
    double height = size.height;

    double tickStartX = 0;
    double tickStartY = height * 0.55;
    double tickEndX = width * 0.25;
    double tickEndY = height * 0.6;
    double vBottomX = width * 0.5;
    double vBottomY = height - (strokeWidth / 2);
    double vTopX = width;
    double vTopY = strokeWidth / 2;

    path.moveTo(tickStartX, tickStartY);
    path.lineTo(tickEndX, tickEndY);
    path.lineTo(vBottomX, vBottomY);
    path.lineTo(vTopX, vTopY);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RadicalPainter oldDelegate) {
    return color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
  }
}

/// Scalable parenthesis for read-only display
class _ScalableParenthesis extends StatelessWidget {
  final bool isOpening;
  final double fontSize;
  final Color color;

  const _ScalableParenthesis({
    required this.isOpening,
    required this.fontSize,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: fontSize * 1),
      child: CustomPaint(
        size: Size(fontSize * 0.2, double.infinity),
        painter: _ParenthesisPainter(
          isOpening: isOpening,
          color: color,
          strokeWidth: math.max(1.5, fontSize * 0.06),
        ),
      ),
    );
  }
}

class _ParenthesisPainter extends CustomPainter {
  final bool isOpening;
  final Color color;
  final double strokeWidth;

  _ParenthesisPainter({
    required this.isOpening,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    final path = Path();
    double padding = size.height * 0.05;
    double bowAmount = size.width * 0.3;

    if (isOpening) {
      path.moveTo(size.width, padding);
      path.quadraticBezierTo(
        -bowAmount,
        size.height / 2,
        size.width,
        size.height - padding,
      );
    } else {
      path.moveTo(0, padding);
      path.quadraticBezierTo(
        size.width + bowAmount,
        size.height / 2,
        0,
        size.height - padding,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ParenthesisPainter oldDelegate) {
    return oldDelegate.isOpening != isOpening ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
