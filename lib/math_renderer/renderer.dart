import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../utils/constants.dart';
import 'math_editor_controller.dart';
import 'placeholder_box.dart';

// Re-export all related modules for backward compatibility
export 'math_nodes.dart';
export 'math_text_style.dart';
export 'math_editor_widgets.dart';

// Import the modules we depend on
import 'math_nodes.dart';
import 'math_text_style.dart';

/// Renders a math expression tree as Flutter widgets.
class MathRenderer extends StatelessWidget {
  final List<MathNode> expression;
  final GlobalKey rootKey;
  final MathEditorController controller;
  final int structureVersion;
  final TextScaler textScaler;

  const MathRenderer({
    super.key,
    required this.expression,
    required this.rootKey,
    required this.controller,
    required this.structureVersion,
    required this.textScaler,
  });

  @override
  Widget build(BuildContext context) {
    List<_LineInfo> lines = _splitIntoLines(expression);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children:
          lines.map((lineInfo) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: UnconstrainedBox(
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _renderNodeList(
                    lineInfo.nodes,
                    lineInfo.startIndex,
                    fontSize: FONTSIZE,
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  /// Splits expression into lines at NewlineNode boundaries
  List<_LineInfo> _splitIntoLines(List<MathNode> nodes) {
    List<_LineInfo> lines = [];
    List<MathNode> currentLine = [];
    int startIndex = 0;

    for (int i = 0; i < nodes.length; i++) {
      if (nodes[i] is NewlineNode) {
        // End current line
        if (currentLine.isEmpty) {
          currentLine.add(LiteralNode(text: ''));
        }
        lines.add(
          _LineInfo(nodes: List.from(currentLine), startIndex: startIndex),
        );
        currentLine = [];
        startIndex = i + 1;
      } else {
        currentLine.add(nodes[i]);
      }
    }

    // Add last line
    if (currentLine.isEmpty) {
      currentLine.add(LiteralNode(text: ''));
    }
    lines.add(_LineInfo(nodes: currentLine, startIndex: startIndex));

    return lines;
  }

  /// Helper to render a list of nodes with reference axis alignment
  List<Widget> _renderNodeList(
    List<MathNode> nodes,
    int startIndex, {
    required double fontSize,
    String? parentId,
    String? path,
    bool removeLeftPadding = false,
    bool removeRightPadding = false,
  }) {
    if (nodes.isEmpty) {
      return [];
    }

    // Calculate max extents for the list
    double maxAbove = 0;
    double maxBelow = 0;

    for (final node in nodes) {
      final (height, offset) = _getNodeMetrics(node, fontSize);
      if (height > 0) {
        maxAbove = math.max(maxAbove, height - offset);
        maxBelow = math.max(maxBelow, offset);
      }
    }

    // Find first and last non-empty node indices for edge padding
    int firstNonEmptyIndex = -1;
    int lastNonEmptyIndex = -1;

    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final bool isEmpty = node is LiteralNode && node.text.isEmpty;
      if (!isEmpty) {
        if (firstNonEmptyIndex == -1) firstNonEmptyIndex = i;
        lastNonEmptyIndex = i;
      }
    }

    // Render each node with appropriate top padding to align reference axes
    return nodes.asMap().entries.map((e) {
      final node = e.value;
      final int nodeIndex = e.key;
      final (height, offset) = _getNodeMetrics(node, fontSize);

      // Top padding = maxAbove - (this node's extent above its reference)
      final topPadding = maxAbove - (height - offset);

      // Check if this node is empty LiteralNode
      final bool isEmpty = node is LiteralNode && node.text.isEmpty;

      // Determine left/right padding
      final bool isFirstNonEmpty = nodeIndex == firstNonEmptyIndex;
      final bool isLastNonEmpty = nodeIndex == lastNonEmptyIndex;

      // Empty nodes get 0 padding; non-empty use edge detection
      final double leftPad =
          isEmpty ? 0.0 : ((removeLeftPadding && isFirstNonEmpty) ? 0.0 : 1.5);
      final double rightPad =
          isEmpty ? 0.0 : ((removeRightPadding && isLastNonEmpty) ? 0.0 : 1.5);

      return Padding(
        padding: EdgeInsets.only(
          left: leftPad,
          right: rightPad,
          top: math.max(0, topPadding),
        ),
        child: _renderNode(
          node,
          startIndex + e.key,
          nodes,
          parentId,
          path,
          fontSize,
        ),
      );
    }).toList();
  }

  Widget _wrapComposite({
    required Widget child,
    required MathNode node,
    required int index,
    required String? parentId,
    required String? path,
  }) {
    return _ComplexNodeWrapper(
      node: node,
      index: index,
      parentId: parentId,
      path: path,
      controller: controller,
      rootKey: rootKey,
      structureVersion: structureVersion,
      child: child,
    );
  }

  Widget _renderNode(
    MathNode node,
    int index,
    List<MathNode> siblings,
    String? parentId,
    String? path,
    double fontSize,
  ) {
    // Skip rendering NewlineNode (it's handled by line splitting)
    if (node is NewlineNode) {
      return const SizedBox.shrink();
    }

    if (node is LiteralNode) {
      return LiteralWidget(
        key: ValueKey('${node.id}_$structureVersion'),
        node: node,
        fontSize: fontSize,
        parentId: parentId,
        path: path,
        index: index,
        rootKey: rootKey,
        controller: controller,
        structureVersion: structureVersion,
        textScaler: textScaler,
      );
    }

    if (node is FractionNode) {
      final bool numEmpty = _isContentEmpty(node.numerator);
      final bool denEmpty = _isContentEmpty(node.denominator);

      return _wrapComposite(
        node: node,
        index: index,
        parentId: parentId,
        path: path,
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Numerator
              numEmpty
                  ? GestureDetector(
                    onTap:
                        () => controller.navigateTo(
                          parentId: node.id,
                          path: 'num',
                          index: 0,
                          subIndex: 0,
                        ),
                    child: PlaceholderBox(
                      fontSize: fontSize,
                      minWidth: fontSize * 1.0,
                      minHeight: fontSize * 0.8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _renderNodeList(
                          node.numerator,
                          0,
                          fontSize: fontSize,
                          parentId: node.id,
                          path: 'num',
                        ),
                      ),
                    ),
                  )
                  : Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _renderNodeList(
                      node.numerator,
                      0,
                      fontSize: fontSize,
                      parentId: node.id,
                      path: 'num',
                    ),
                  ),

              // Fraction line
              Container(
                height: math.max(1.5, fontSize * 0.06),
                width: double.infinity,
                color: Colors.white,
                margin: EdgeInsets.symmetric(vertical: fontSize * 0.15),
              ),

              // Denominator
              denEmpty
                  ? GestureDetector(
                    onTap:
                        () => controller.navigateTo(
                          parentId: node.id,
                          path: 'den',
                          index: 0,
                          subIndex: 0,
                        ),
                    child: PlaceholderBox(
                      fontSize: fontSize,
                      minWidth: fontSize * 1.0,
                      minHeight: fontSize * 0.8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _renderNodeList(
                          node.denominator,
                          0,
                          fontSize: fontSize,
                          parentId: node.id,
                          path: 'den',
                        ),
                      ),
                    ),
                  )
                  : Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _renderNodeList(
                      node.denominator,
                      0,
                      fontSize: fontSize,
                      parentId: node.id,
                      path: 'den',
                    ),
                  ),
            ],
          ),
        ),
      );
    }

    if (node is ExponentNode) {
      final double powerSize =
          fontSize < FONTSIZE * 0.85 ? fontSize : fontSize * 0.8;
      final bool baseEmpty = _isContentEmpty(node.base);
      final bool powerEmpty = _isContentEmpty(node.power);

      // Fixed offset - must match metrics!
      final double fixedOffset = fontSize * -0.5;

      Widget baseWidget =
          baseEmpty
              ? GestureDetector(
                onTap:
                    () => controller.navigateTo(
                      parentId: node.id,
                      path: 'base',
                      index: 0,
                      subIndex: 0,
                    ),
                child: PlaceholderBox(
                  fontSize: fontSize,
                  minWidth: fontSize * 0.7,
                  minHeight: fontSize * 0.9,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _renderNodeList(
                      node.base,
                      0,
                      fontSize: fontSize,
                      parentId: node.id,
                      path: 'base',
                      removeLeftPadding: true,
                      removeRightPadding: true,
                    ),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _renderNodeList(
                  node.base,
                  0,
                  fontSize: fontSize,
                  parentId: node.id,
                  path: 'base',
                  removeLeftPadding: true,
                  removeRightPadding: true,
                ),
              );

      Widget powerWidget =
          powerEmpty
              ? GestureDetector(
                onTap:
                    () => controller.navigateTo(
                      parentId: node.id,
                      path: 'pow',
                      index: 0,
                      subIndex: 0,
                    ),
                child: PlaceholderBox(
                  fontSize: powerSize,
                  minWidth: powerSize * 0.6,
                  minHeight: powerSize * 0.7,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _renderNodeList(
                      node.power,
                      0,
                      fontSize: powerSize,
                      parentId: node.id,
                      path: 'pow',
                      removeLeftPadding: true,
                      removeRightPadding: true,
                    ),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _renderNodeList(
                  node.power,
                  0,
                  fontSize: powerSize,
                  parentId: node.id,
                  path: 'pow',
                  removeLeftPadding: true,
                  removeRightPadding: true,
                ),
              );

      // Get power height for layout
      final powerMetrics = _getListMetrics(node.power, powerSize);
      final double powerHeight = powerMetrics.$1;

      // Base is pushed down by: powerHeight + fixedOffset
      final double baseTopPadding = powerHeight + fixedOffset;

      return _wrapComposite(
        node: node,
        index: index,
        parentId: parentId,
        path: path,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Base pushed down
            Padding(
              padding: EdgeInsets.only(top: baseTopPadding),
              child: baseWidget,
            ),
            // Power at top
            powerWidget,
          ],
        ),
      );
    }

    if (node is ParenthesisNode) {
      final bool contentEmpty = _isContentEmpty(node.content);

      Widget contentWidget =
          contentEmpty
              ? GestureDetector(
                onTap:
                    () => controller.navigateTo(
                      parentId: node.id,
                      path: 'content',
                      index: 0,
                      subIndex: 0,
                    ),
                child: PlaceholderBox(
                  fontSize: fontSize,
                  minWidth: fontSize * 0.8,
                  minHeight: fontSize * 0.9,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _renderNodeList(
                      node.content,
                      0,
                      fontSize: fontSize,
                      parentId: node.id,
                      path: 'content',
                    ),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _renderNodeList(
                  node.content,
                  0,
                  fontSize: fontSize,
                  parentId: node.id,
                  path: 'content',
                ),
              );

      return _wrapComposite(
        node: node,
        index: index,
        parentId: parentId,
        path: path,
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScalableParenthesis(
                isOpening: true,
                fontSize: fontSize,
                color: Colors.white,
                textScaler: textScaler,
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: fontSize * 0.15,
                  vertical: fontSize * 0.1,
                ),
                child: contentWidget,
              ),
              ScalableParenthesis(
                isOpening: false,
                fontSize: fontSize,
                color: Colors.white,
                textScaler: textScaler,
              ),
            ],
          ),
        ),
      );
    }

    if (node is TrigNode) {
      final bool argEmpty = _isContentEmpty(node.argument);

      Widget argWidget =
          argEmpty
              ? GestureDetector(
                onTap:
                    () => controller.navigateTo(
                      parentId: node.id,
                      path: 'arg',
                      index: 0,
                      subIndex: 0,
                    ),
                child: PlaceholderBox(
                  fontSize: fontSize,
                  minWidth: fontSize * 0.8,
                  minHeight: fontSize * 0.9,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _renderNodeList(
                      node.argument,
                      0,
                      fontSize: fontSize,
                      parentId: node.id,
                      path: 'arg',
                    ),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _renderNodeList(
                  node.argument,
                  0,
                  fontSize: fontSize,
                  parentId: node.id,
                  path: 'arg',
                ),
              );

      return _wrapComposite(
        node: node,
        index: index,
        parentId: parentId,
        path: path,
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Function name (sin, cos, etc.)
              Text(
                node.function,
                style: MathTextStyle.getStyle(
                  fontSize,
                ).copyWith(color: Colors.white),
                textScaler: textScaler,
              ),
              // Parentheses with content
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ScalableParenthesis(
                      isOpening: true,
                      fontSize: fontSize,
                      color: Colors.white,
                      textScaler: textScaler,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: fontSize * 0.25,
                        vertical: fontSize * 0.1,
                      ),
                      child: argWidget,
                    ),
                    ScalableParenthesis(
                      isOpening: false,
                      fontSize: fontSize,
                      color: Colors.white,
                      textScaler: textScaler,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (node is RootNode) {
      final double indexSize = fontSize * 0.7;
      final double minRadicandHeight = fontSize * 1.2;

      final bool radicandEmpty = _isContentEmpty(node.radicand);
      final bool indexEmpty = !node.isSquareRoot && _isContentEmpty(node.index);

      // Build radicand widget
      Widget radicandWidget =
          radicandEmpty
              ? GestureDetector(
                onTap:
                    () => controller.navigateTo(
                      parentId: node.id,
                      path: 'radicand',
                      index: 0,
                      subIndex: 0,
                    ),
                child: PlaceholderBox(
                  fontSize: fontSize,
                  minWidth: fontSize * 0.9,
                  minHeight: fontSize * 0.9,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _renderNodeList(
                      node.radicand,
                      0,
                      fontSize: fontSize,
                      parentId: node.id,
                      path: 'radicand',
                    ),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _renderNodeList(
                  node.radicand,
                  0,
                  fontSize: fontSize,
                  parentId: node.id,
                  path: 'radicand',
                ),
              );

      // Build index widget for nth roots
      Widget? indexWidget;
      if (!node.isSquareRoot) {
        indexWidget =
            indexEmpty
                ? GestureDetector(
                  onTap:
                      () => controller.navigateTo(
                        parentId: node.id,
                        path: 'index',
                        index: 0,
                        subIndex: 0,
                      ),
                  child: PlaceholderBox(
                    fontSize: indexSize,
                    minWidth: indexSize * 0.7,
                    minHeight: indexSize * 0.7,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _renderNodeList(
                        node.index,
                        0,
                        fontSize: indexSize,
                        parentId: node.id,
                        path: 'index',
                      ),
                    ),
                  ),
                )
                : Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _renderNodeList(
                    node.index,
                    0,
                    fontSize: indexSize,
                    parentId: node.id,
                    path: 'index',
                  ),
                );
      }

      return _wrapComposite(
        node: node,
        index: index,
        parentId: parentId,
        path: path,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Index for nth root
            if (indexWidget != null)
              Padding(
                padding: const EdgeInsets.only(right: 1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [indexWidget, SizedBox(height: fontSize * 0.35)],
                ),
              ),

            // Radical symbol + radicand
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
                        painter: RadicalSymbolPainter(
                          color: Colors.white,
                          strokeWidth: math.max(1.5, fontSize * 0.06),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Colors.white,
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
                      child: Center(child: radicandWidget),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (node is LogNode) {
      final double baseSize = fontSize * 0.8;

      final bool baseEmpty = !node.isNaturalLog && _isContentEmpty(node.base);
      final bool argEmpty = _isContentEmpty(node.argument);

      // Build base widget (only for non-natural log)
      Widget? baseWidget;
      if (!node.isNaturalLog) {
        baseWidget =
            baseEmpty
                ? GestureDetector(
                  onTap:
                      () => controller.navigateTo(
                        parentId: node.id,
                        path: 'base',
                        index: 0,
                        subIndex: 0,
                      ),
                  child: PlaceholderBox(
                    fontSize: baseSize,
                    minWidth: baseSize * 0.6,
                    minHeight: baseSize * 0.7,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _renderNodeList(
                        node.base,
                        0,
                        fontSize: baseSize,
                        parentId: node.id,
                        path: 'base',
                      ),
                    ),
                  ),
                )
                : Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _renderNodeList(
                    node.base,
                    0,
                    fontSize: baseSize,
                    parentId: node.id,
                    path: 'base',
                  ),
                );
      }

      // Build argument widget
      Widget argWidget =
          argEmpty
              ? GestureDetector(
                onTap:
                    () => controller.navigateTo(
                      parentId: node.id,
                      path: 'arg',
                      index: 0,
                      subIndex: 0,
                    ),
                child: PlaceholderBox(
                  fontSize: fontSize,
                  minWidth: fontSize * 0.8,
                  minHeight: fontSize * 0.9,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _renderNodeList(
                      node.argument,
                      0,
                      fontSize: fontSize,
                      parentId: node.id,
                      path: 'arg',
                    ),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _renderNodeList(
                  node.argument,
                  0,
                  fontSize: fontSize,
                  parentId: node.id,
                  path: 'arg',
                ),
              );

      return _wrapComposite(
        node: node,
        index: index,
        parentId: parentId,
        path: path,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // "log" or "ln" text
            Text(
              node.isNaturalLog ? 'ln' : 'log',
              style: MathTextStyle.getStyle(
                fontSize,
              ).copyWith(color: Colors.white),
              textScaler: textScaler,
            ),

            // Subscript base - layout-aware positioning
            if (!node.isNaturalLog && baseWidget != null)
              Padding(
                padding: EdgeInsets.only(left: 1, top: fontSize * 0.5),
                child: baseWidget,
              ),

            // Small gap for natural log
            if (node.isNaturalLog) SizedBox(width: fontSize * 0.05),

            // Parentheses with argument
            IntrinsicHeight(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ScalableParenthesis(
                    isOpening: true,
                    fontSize: fontSize,
                    color: Colors.white,
                    textScaler: textScaler,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: fontSize * 0.08,
                      vertical: fontSize * 0.1,
                    ),
                    child: argWidget,
                  ),
                  ScalableParenthesis(
                    isOpening: false,
                    fontSize: fontSize,
                    color: Colors.white,
                    textScaler: textScaler,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (node is PermutationNode) {
      final double smallSize = fontSize * 0.8;

      final bool nEmpty = _isContentEmpty(node.n);
      final bool rEmpty = _isContentEmpty(node.r);

      // Build n widget (top/superscript)
      Widget nWidget =
          nEmpty
              ? GestureDetector(
                onTap:
                    () => controller.navigateTo(
                      parentId: node.id,
                      path: 'n',
                      index: 0,
                      subIndex: 0,
                    ),
                child: PlaceholderBox(
                  fontSize: smallSize,
                  minWidth: smallSize * 0.6,
                  minHeight: smallSize * 0.7,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _renderNodeList(
                      node.n,
                      0,
                      fontSize: smallSize,
                      parentId: node.id,
                      path: 'n',
                    ),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _renderNodeList(
                  node.n,
                  0,
                  fontSize: smallSize,
                  parentId: node.id,
                  path: 'n',
                ),
              );

      // Build r widget (bottom/subscript)
      Widget rWidget =
          rEmpty
              ? GestureDetector(
                onTap:
                    () => controller.navigateTo(
                      parentId: node.id,
                      path: 'r',
                      index: 0,
                      subIndex: 0,
                    ),
                child: PlaceholderBox(
                  fontSize: smallSize,
                  minWidth: smallSize * 0.6,
                  minHeight: smallSize * 0.7,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _renderNodeList(
                      node.r,
                      0,
                      fontSize: smallSize,
                      parentId: node.id,
                      path: 'r',
                    ),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _renderNodeList(
                  node.r,
                  0,
                  fontSize: smallSize,
                  parentId: node.id,
                  path: 'r',
                ),
              );

      return _wrapComposite(
        node: node,
        index: index,
        parentId: parentId,
        path: path,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // n (superscript position)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [nWidget, SizedBox(height: fontSize * 0.8)],
            ),
            // P symbol
            Text(
              'P',
              style: MathTextStyle.getStyle(
                fontSize,
              ).copyWith(color: Colors.white),
              textScaler: textScaler,
            ),
            // r (subscript position)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [SizedBox(height: fontSize * 0.8), rWidget],
            ),
          ],
        ),
      );
    }

    if (node is CombinationNode) {
      final double smallSize = fontSize * 0.8;

      final bool nEmpty = _isContentEmpty(node.n);
      final bool rEmpty = _isContentEmpty(node.r);

      // Build n widget (top/superscript)
      Widget nWidget =
          nEmpty
              ? GestureDetector(
                onTap:
                    () => controller.navigateTo(
                      parentId: node.id,
                      path: 'n',
                      index: 0,
                      subIndex: 0,
                    ),
                child: PlaceholderBox(
                  fontSize: smallSize,
                  minWidth: smallSize * 0.6,
                  minHeight: smallSize * 0.7,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _renderNodeList(
                      node.n,
                      0,
                      fontSize: smallSize,
                      parentId: node.id,
                      path: 'n',
                    ),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _renderNodeList(
                  node.n,
                  0,
                  fontSize: smallSize,
                  parentId: node.id,
                  path: 'n',
                ),
              );

      // Build r widget (bottom/subscript)
      Widget rWidget =
          rEmpty
              ? GestureDetector(
                onTap:
                    () => controller.navigateTo(
                      parentId: node.id,
                      path: 'r',
                      index: 0,
                      subIndex: 0,
                    ),
                child: PlaceholderBox(
                  fontSize: smallSize,
                  minWidth: smallSize * 0.6,
                  minHeight: smallSize * 0.7,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _renderNodeList(
                      node.r,
                      0,
                      fontSize: smallSize,
                      parentId: node.id,
                      path: 'r',
                    ),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _renderNodeList(
                  node.r,
                  0,
                  fontSize: smallSize,
                  parentId: node.id,
                  path: 'r',
                ),
              );

      return _wrapComposite(
        node: node,
        index: index,
        parentId: parentId,
        path: path,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // n (superscript position)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [nWidget, SizedBox(height: fontSize * 1.0)],
            ),
            // C symbol
            Text(
              'C',
              style: MathTextStyle.getStyle(
                fontSize,
              ).copyWith(color: Colors.white),
              textScaler: textScaler,
            ),
            // r (subscript position)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [SizedBox(height: fontSize * 0.8), rWidget],
            ),
          ],
        ),
      );
    }

    if (node is AnsNode) {
      return _wrapComposite(
        node: node,
        index: index,
        parentId: parentId,
        path: path,
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // "ANS" text
              Text(
                'ans',
                style: MathTextStyle.getStyle(
                  fontSize,
                ).copyWith(color: Colors.orangeAccent),
                textScaler: textScaler,
              ),

              // Index - same size as regular text
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _renderNodeList(
                  node.index,
                  0,
                  fontSize: fontSize,
                  parentId: node.id,
                  path: 'index',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  /// Check if a list of nodes is effectively empty
  bool _isContentEmpty(List<MathNode> nodes) {
    if (nodes.isEmpty) return true;
    if (nodes.length == 1 && nodes.first is LiteralNode) {
      return (nodes.first as LiteralNode).text.isEmpty;
    }
    return false;
  }

  /// Returns (height, referenceOffset from bottom) for a node
  (double, double) _getNodeMetrics(MathNode node, double fontSize) {
    if (node is NewlineNode) {
      return (0, 0);
    }

    if (node is LiteralNode) {
      return (fontSize, fontSize / 2);
    }

    if (node is ExponentNode) {
      final double powerSize =
          fontSize < FONTSIZE * 0.85 ? fontSize : fontSize * 0.8;

      final baseMetrics = _getListMetrics(node.base, fontSize);
      final powerMetrics = _getListMetrics(node.power, powerSize);

      final double baseHeight = baseMetrics.$1;
      final double baseRef = baseMetrics.$2;
      final double powerHeight = powerMetrics.$1;

      // Fixed offset: how much of power sits above base top
      final double fixedOffset = fontSize * -0.5;

      // Total height = base + fixed offset above + power height
      final double totalHeight = baseHeight + fixedOffset + powerHeight;

      // Reference is base's reference (so bases align with siblings)
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
      // Reference at bar center, measured from bottom
      final offset = denHeight + margin + barHeight / 2;

      return (height, offset);
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
      return (height, height / 2);
    }

    if (node is RootNode) {
      final radicandMetrics = _getListMetrics(node.radicand, fontSize);
      final double minHeight = fontSize * 1.2;
      final height = math.max(minHeight, radicandMetrics.$1);
      return (height, height / 2);
    }

    if (node is LogNode) {
      final argMetrics = _getListMetrics(node.argument, fontSize);
      final double vPadding = fontSize * 0.1;

      // Argument area height
      final double argAreaHeight = argMetrics.$1 + vPadding * 2;

      // For non-natural log, subscript extends down
      double subscriptExtent = 0;
      if (!node.isNaturalLog) {
        final baseSize = fontSize * 0.8;
        final baseMetrics = _getListMetrics(node.base, baseSize);
        // Subscript pushed down by fontSize * 0.5, plus its own height
        // But capped by how much it extends below the argument area
        subscriptExtent =
            fontSize * 0.5 +
            math.max(baseMetrics.$1, baseSize * 0.7) -
            fontSize;
        subscriptExtent = math.max(0, subscriptExtent);
      }

      final height = math.max(fontSize, argAreaHeight) + subscriptExtent;
      return (height, height / 2);
    }

    if (node is PermutationNode) {
      final double smallSize = fontSize * 0.8;

      final nMetrics = _getListMetrics(node.n, smallSize);
      final rMetrics = _getListMetrics(node.r, smallSize);

      final double nHeight = math.max(nMetrics.$1, smallSize * 0.7);
      final double rHeight = math.max(rMetrics.$1, smallSize * 0.7);

      // Left column: nWidget + spacer
      final double nColumnHeight = nHeight + fontSize * 0.8;
      // Right column: spacer + rWidget
      final double rColumnHeight = fontSize * 0.8 + rHeight;

      // Row with center alignment: height = max of children
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

      // Left column: nWidget + spacer (fontSize * 1.0 for Combination)
      final double nColumnHeight = nHeight + fontSize * 1.0;
      // Right column: spacer + rWidget
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

  /// Returns (height, referenceOffset from bottom) for a list of nodes
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

/// Widget for rendering a literal text node.
class LiteralWidget extends StatefulWidget {
  final LiteralNode node;
  final double fontSize;
  final String? parentId;
  final String? path;
  final int index;
  final GlobalKey rootKey;
  final MathEditorController controller;
  final int structureVersion;
  final TextScaler textScaler;

  const LiteralWidget({
    super.key,
    required this.node,
    required this.fontSize,
    required this.parentId,
    required this.path,
    required this.index,
    required this.rootKey,
    required this.controller,
    required this.structureVersion,
    required this.textScaler,
  });

  @override
  State<LiteralWidget> createState() => _LiteralWidgetState();
}

class _LiteralWidgetState extends State<LiteralWidget> {
  int _lastReportedVersion = -1;
  final GlobalKey _textKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportLayout());
  }

  @override
  void didUpdateWidget(covariant LiteralWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.structureVersion != widget.structureVersion ||
        oldWidget.node.id != widget.node.id ||
        oldWidget.node.text != widget.node.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reportLayout());
    }
  }

  void _reportLayout() {
    if (!mounted) return;
    if (_lastReportedVersion == widget.structureVersion) return;
    _lastReportedVersion = widget.structureVersion;

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;

    final RenderBox? rootBox =
        widget.rootKey.currentContext?.findRenderObject() as RenderBox?;
    if (rootBox == null) return;

    final globalPos = box.localToGlobal(Offset.zero);
    final relativePos = rootBox.globalToLocal(globalPos);
    final rect = relativePos & box.size;

    RenderParagraph? renderParagraph;
    final renderObject = _textKey.currentContext?.findRenderObject();
    if (renderObject is RenderParagraph) {
      renderParagraph = renderObject;
    }

    widget.controller.registerNodeLayout(
      NodeLayoutInfo(
        rect: rect,
        node: widget.node,
        parentId: widget.parentId,
        path: widget.path,
        index: widget.index,
        fontSize: widget.fontSize,
        textScaler: widget.textScaler,
        renderParagraph: renderParagraph,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.node.text;

    if (text.isEmpty) {
      return SizedBox(
        width: math.max(2.0, widget.fontSize * 0.06),
        height: widget.fontSize,
      );
    }

    final displayText = MathTextStyle.toDisplayText(text);

    return Text(
      key: _textKey,
      displayText,
      style: MathTextStyle.getStyle(
        widget.fontSize,
      ).copyWith(color: Colors.white),
      textScaler: widget.textScaler,
    );
  }
}

/// Custom painter for the radical (square root) symbol.
class RadicalSymbolPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  RadicalSymbolPainter({required this.color, required this.strokeWidth});

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

    // Small horizontal tick at start
    double tickStartX = 0;
    double tickStartY = height * 0.55;
    double tickEndX = width * 0.25;
    double tickEndY = height * 0.6;

    // V bottom point
    double vBottomX = width * 0.5;
    double vBottomY = height - (strokeWidth / 2);

    // Top right of V (connects to vinculum)
    double vTopX = width;
    double vTopY = strokeWidth / 2;

    path.moveTo(tickStartX, tickStartY);
    path.lineTo(tickEndX, tickEndY);
    path.lineTo(vBottomX, vBottomY);
    path.lineTo(vTopX, vTopY);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant RadicalSymbolPainter oldDelegate) {
    return color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
  }
}

/// Wrapper for composite nodes to register their layout bounds
class _ComplexNodeWrapper extends StatefulWidget {
  final Widget child;
  final MathNode node;
  final int index;
  final String? parentId;
  final String? path;
  final MathEditorController controller;
  final GlobalKey rootKey;
  final int structureVersion;

  const _ComplexNodeWrapper({
    required this.child,
    required this.node,
    required this.index,
    required this.parentId,
    required this.path,
    required this.controller,
    required this.rootKey,
    required this.structureVersion,
  });

  @override
  State<_ComplexNodeWrapper> createState() => _ComplexNodeWrapperState();
}

class _ComplexNodeWrapperState extends State<_ComplexNodeWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _register());
  }

  @override
  void didUpdateWidget(covariant _ComplexNodeWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.structureVersion != widget.structureVersion ||
        oldWidget.node.id != widget.node.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _register());
    }
  }

  void _register() {
    if (!mounted) return;

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;

    final RenderBox? rootBox =
        widget.rootKey.currentContext?.findRenderObject() as RenderBox?;
    if (rootBox == null) return;

    final globalPos = box.localToGlobal(Offset.zero);
    final relativePos = rootBox.globalToLocal(globalPos);
    final rect = relativePos & box.size;

    widget.controller.registerComplexNodeLayout(
      ComplexNodeInfo(
        node: widget.node,
        parentId: widget.parentId,
        path: widget.path,
        index: widget.index,
        rect: rect,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// A scalable parenthesis widget that grows with content height.
class ScalableParenthesis extends StatelessWidget {
  final bool isOpening;
  final double fontSize;
  final Color color;
  final TextScaler textScaler;

  const ScalableParenthesis({
    super.key,
    required this.isOpening,
    required this.fontSize,
    this.color = Colors.white,
    required this.textScaler,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: fontSize * 1),
      child: CustomPaint(
        size: Size(fontSize * 0.2, double.infinity), // Reduced from 0.35
        painter: ParenthesisPainter(
          isOpening: isOpening,
          color: color,
          strokeWidth: math.max(1.5, fontSize * 0.06),
        ),
      ),
    );
  }
}

/// Custom painter for parenthesis curves.
class ParenthesisPainter extends CustomPainter {
  final bool isOpening;
  final Color color;
  final double strokeWidth;

  ParenthesisPainter({
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

    // Control the bow amount here (lower = less bow)
    // Original was -size.width for opening and 2 * size.width for closing
    double bowAmount =
        size.width * 0.3; // Adjust this value (0.0 = straight, 1.0 = more bow)

    if (isOpening) {
      path.moveTo(size.width, padding);
      path.quadraticBezierTo(
        -bowAmount, // Changed from -size.width
        size.height / 2,
        size.width,
        size.height - padding,
      );
    } else {
      path.moveTo(0, padding);
      path.quadraticBezierTo(
        size.width + bowAmount, // Changed from 2 * size.width
        size.height / 2,
        0,
        size.height - padding,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ParenthesisPainter oldDelegate) {
    return oldDelegate.isOpening != isOpening ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Information about a complex node's location in the tree
class ComplexNodeInfo {
  final MathNode node;
  final String? parentId;
  final String? path;
  final int index;
  final Rect rect;

  ComplexNodeInfo({
    required this.node,
    required this.parentId,
    required this.path,
    required this.index,
    required this.rect,
  });
}

/// Layout information for a literal node, used for cursor positioning.
class NodeLayoutInfo {
  final Rect rect;
  final LiteralNode node;
  final String? parentId;
  final String? path;
  final int index;
  final double fontSize;
  final TextScaler textScaler;
  final RenderParagraph? renderParagraph;

  // Cached display text - computed once
  String? _displayText;
  String get displayText =>
      _displayText ??= MathTextStyle.toDisplayText(node.text);

  NodeLayoutInfo({
    required this.rect,
    required this.node,
    required this.parentId,
    required this.path,
    required this.index,
    required this.fontSize,
    required this.textScaler,
    this.renderParagraph,
  });
}

/// Helper class to track line info
class _LineInfo {
  final List<MathNode> nodes;
  final int startIndex;

  _LineInfo({required this.nodes, required this.startIndex});
}

/// Overlay widget for rendering the blinking cursor.
class CursorOverlay extends SingleChildRenderObjectWidget {
  final CursorPaintNotifier notifier;
  final Animation<double> blinkAnimation;
  final bool showCursor;

  const CursorOverlay({
    super.key,
    required super.child,
    required this.notifier,
    required this.blinkAnimation,
    required this.showCursor,
  });

  @override
  RenderCursorOverlay createRenderObject(BuildContext context) {
    return RenderCursorOverlay(
      notifier: notifier,
      blinkAnimation: blinkAnimation,
      showCursor: showCursor,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCursorOverlay renderObject,
  ) {
    renderObject
      ..notifier = notifier
      ..blinkAnimation = blinkAnimation
      ..showCursor = showCursor;
  }
}

/// Render object for the cursor overlay.
class RenderCursorOverlay extends RenderProxyBox {
  RenderCursorOverlay({
    required CursorPaintNotifier notifier,
    required Animation<double> blinkAnimation,
    required bool showCursor,
  }) : _notifier = notifier,
       _blinkAnimation = blinkAnimation,
       _showCursor = showCursor {
    _notifier.onNeedsPaint = markNeedsPaint;
    _blinkAnimation.addListener(markNeedsPaint);
  }

  CursorPaintNotifier _notifier;
  set notifier(CursorPaintNotifier value) {
    if (_notifier == value) return;
    _notifier.onNeedsPaint = null;
    _notifier = value;
    _notifier.onNeedsPaint = markNeedsPaint;
    markNeedsPaint();
  }

  Animation<double> _blinkAnimation;
  set blinkAnimation(Animation<double> value) {
    if (_blinkAnimation == value) return;
    _blinkAnimation.removeListener(markNeedsPaint);
    _blinkAnimation = value;
    _blinkAnimation.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  bool _showCursor;
  set showCursor(bool value) {
    if (_showCursor == value) return;
    _showCursor = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    // Restore the callback when re-attached
    _notifier.onNeedsPaint = markNeedsPaint;
    _blinkAnimation.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _notifier.onNeedsPaint = null;
    _blinkAnimation.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Paint child first (the math expression)
    super.paint(context, offset);

    // Paint cursor on top
    if (_showCursor &&
        _blinkAnimation.value >= 0.5 &&
        _notifier.rect != Rect.zero) {
      final paint =
          Paint()
            ..color = Colors.yellowAccent
            ..style = PaintingStyle.fill;

      context.canvas.drawRect(_notifier.rect.shift(offset), paint);
    }
  }
}
