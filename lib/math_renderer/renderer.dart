import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'package:flutter/rendering.dart';
import 'expression_selection.dart';
import 'math_editor_controller.dart';
import 'cursor.dart';
import 'placeholder_box.dart';

abstract class MathNode {
  final String id;
  MathNode() : id = math.Random().nextInt(1 << 31).toString();
}

class LiteralNode extends MathNode {
  String text;
  LiteralNode({this.text = ""});
}

class FractionNode extends MathNode {
  List<MathNode> numerator;
  List<MathNode> denominator;
  FractionNode({List<MathNode>? num, List<MathNode>? den})
    : numerator = num ?? [LiteralNode()],
      denominator = den ?? [LiteralNode()];
}

class ExponentNode extends MathNode {
  List<MathNode> base;
  List<MathNode> power;
  ExponentNode({List<MathNode>? base, List<MathNode>? power})
    : base = base ?? [LiteralNode()],
      power = power ?? [LiteralNode()];
}

class LogNode extends MathNode {
  List<MathNode> base; // The subscript (n in log_n)
  List<MathNode> argument; // What we're taking log of
  bool isNaturalLog; // If true, it's ln (no base shown)

  LogNode({
    List<MathNode>? base,
    List<MathNode>? argument,
    this.isNaturalLog = false,
  }) : base = base ?? [LiteralNode(text: "10")],
       argument = argument ?? [LiteralNode()];
}

class TrigNode extends MathNode {
  final String function; // sin, cos, tan, asin, acos, atan, log, ln
  List<MathNode> argument;
  TrigNode({required this.function, List<MathNode>? argument})
    : argument = argument ?? [LiteralNode()];
}

class RootNode extends MathNode {
  List<MathNode> index; // The n in ⁿ√
  List<MathNode> radicand; // What's under the root
  final bool isSquareRoot; // If true, don't show index (it's 2)
  RootNode({
    List<MathNode>? index,
    List<MathNode>? radicand,
    this.isSquareRoot = false,
  }) : index = index ?? [LiteralNode(text: isSquareRoot ? "2" : "")],
       radicand = radicand ?? [LiteralNode()];
}

class PermutationNode extends MathNode {
  List<MathNode> n; // Top number
  List<MathNode> r; // Bottom number
  PermutationNode({List<MathNode>? n, List<MathNode>? r})
    : n = n ?? [LiteralNode()],
      r = r ?? [LiteralNode()];
}

class CombinationNode extends MathNode {
  List<MathNode> n; // Top number
  List<MathNode> r; // Bottom number
  CombinationNode({List<MathNode>? n, List<MathNode>? r})
    : n = n ?? [LiteralNode()],
      r = r ?? [LiteralNode()];
}

class NewlineNode extends MathNode {
  NewlineNode() : super();
}

class ParenthesisNode extends MathNode {
  List<MathNode> content;
  ParenthesisNode({List<MathNode>? content})
    : content = content ?? [LiteralNode()];
}

class AnsNode extends MathNode {
  List<MathNode> index; // The reference number (0, 1, 2, etc.)

  AnsNode({List<MathNode>? index}) : index = index ?? [LiteralNode()];
}

class MathTextStyle {
  static const String plusSign = '\u002B';
  static const String minusSign = '\u2212';
  static const String equalsSign = '=';

  static const String multiplyDot = '\u00B7';
  static const String multiplyTimes = '\u00D7';

  static String _multiplySign = '\u00D7';

  static String get multiplySign => _multiplySign;

  static void setMultiplySign(String sign) {
    _multiplySign = sign;
  }

  static const Set<String> _allMultiplySigns = {multiplyDot, multiplyTimes};

  static const Set<String> _paddedOperators = {
    plusSign,
    minusSign,
    multiplyDot,
    multiplyTimes,
    equalsSign,
  };

  static bool _isPaddedOperator(String char) {
    return _paddedOperators.contains(char);
  }

  static bool _isMultiplySign(String char) {
    return _allMultiplySigns.contains(char);
  }

  static TextStyle getStyle(double fontSize) {
    return TextStyle(
      fontSize: fontSize,
      height: 1.0,
      fontFamily: FONTFAMILY,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static String toDisplayText(String text) {
    if (text.isEmpty) return text;
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final char = text[i];

      String displayChar = char;
      if (_isMultiplySign(char)) {
        displayChar = _multiplySign;
      }

      if (_isPaddedOperator(char)) {
        if (i == 0) {
          buffer.write('$displayChar ');
        } else {
          buffer.write(' $displayChar ');
        }
      } else {
        buffer.write(displayChar);
      }
    }
    return buffer.toString();
  }

  static double measureText(
    String text,
    double fontSize,
    TextScaler textScaler,
  ) {
    if (text.isEmpty) return 0.0;
    final displayText = toDisplayText(text);

    final textSpan = TextSpan(text: displayText, style: getStyle(fontSize));
    final renderParagraph = RenderParagraph(
      textSpan,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    );
    renderParagraph.layout(const BoxConstraints());

    final width = renderParagraph.size.width;
    renderParagraph.dispose();
    return width;
  }

  static int _logicalToDisplayIndex(String text, int logicalIndex) {
    int displayIndex = 0;
    final clampedIndex = logicalIndex.clamp(0, text.length);

    for (int i = 0; i < clampedIndex; i++) {
      final char = text[i];
      if (_isPaddedOperator(char)) {
        if (i == 0) {
          displayIndex += 2; // char + trailing space
        } else {
          displayIndex += 3; // space + char + space
        }
      } else {
        displayIndex += 1;
      }
    }

    return displayIndex;
  }

  static double getCursorOffset(
    String text,
    int charIndex,
    double fontSize,
    TextScaler textScaler,
  ) {
    if (text.isEmpty || charIndex <= 0) return 0.0;

    final displayText = toDisplayText(text);
    final displayIndex = _logicalToDisplayIndex(
      text,
      charIndex,
    ).clamp(0, displayText.length);

    final textSpan = TextSpan(text: displayText, style: getStyle(fontSize));
    final renderParagraph = RenderParagraph(
      textSpan,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    );

    renderParagraph.layout(const BoxConstraints());

    final offset = renderParagraph.getOffsetForCaret(
      TextPosition(offset: displayIndex),
      Rect.zero,
    );

    renderParagraph.dispose();
    return offset.dx;
  }

  static int getCharIndexForOffset(
    String text,
    double xOffset,
    double fontSize,
    TextScaler textScaler,
  ) {
    if (text.isEmpty) return 0;

    final displayText = toDisplayText(text);

    final textSpan = TextSpan(text: displayText, style: getStyle(fontSize));
    final renderParagraph = RenderParagraph(
      textSpan,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    );

    renderParagraph.layout(const BoxConstraints());

    final position = renderParagraph.getPositionForOffset(
      Offset(xOffset, fontSize / 2),
    );

    renderParagraph.dispose();

    int displayOffset = position.offset.clamp(0, displayText.length);
    return displayToLogicalIndex(text, displayOffset);
  }

  static int displayToLogicalIndex(String text, int displayIndex) {
    if (displayIndex <= 0) return 0;

    int displayPos = 0;

    for (int logical = 0; logical < text.length; logical++) {
      final char = text[logical];
      int charWidth;

      if (_isPaddedOperator(char)) {
        charWidth = (logical == 0) ? 2 : 3;
      } else {
        charWidth = 1;
      }

      final prevDisplayPos = displayPos;
      displayPos += charWidth;

      if (displayIndex <= displayPos) {
        if (_isPaddedOperator(char)) {
          final midpoint = prevDisplayPos + ((logical == 0) ? 1 : 2);
          if (displayIndex <= midpoint) {
            return logical;
          } else {
            return logical + 1;
          }
        }
        return logical + 1;
      }
    }

    return text.length;
  }

  static int logicalToDisplayIndex(String text, int logicalIndex) {
    return _logicalToDisplayIndex(text, logicalIndex);
  }
}

class MathEditorInline extends StatefulWidget {
  final MathEditorController controller;
  final bool showCursor;
  final VoidCallback? onFocus;

  const MathEditorInline({
    super.key,
    required this.controller,
    this.showCursor = true,
    this.onFocus,
  });

  @override
  State<MathEditorInline> createState() => MathEditorInlineState();
}

class MathEditorInlineState extends State<MathEditorInline>
    with SingleTickerProviderStateMixin {
  late AnimationController _cursorBlinkController;
  late Animation<double> _cursorBlinkAnimation;
  final GlobalKey _containerKey = GlobalKey();
  int _lastStructureVersion = -1;

  OverlayEntry? _selectionOverlay;

  // Track double-tap position for paste menu

  Offset? _doubleTapPosition;
  Offset? _lastTapDownPosition; // Add this

  @override
  void initState() {
    super.initState();
    _cursorBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _cursorBlinkAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(_cursorBlinkController);

    widget.controller.setContainerKey(_containerKey);
    widget.controller.onSelectionCleared = _onSelectionCleared;
  }

  void _onSelectionCleared() {
    debugPrint('=== _onSelectionCleared callback fired ===');
    if (mounted) {
      _removeSelectionOverlay();
    }
  }

  @override
  void dispose() {
    _removeSelectionOverlay();
    _cursorBlinkController.dispose();
    widget.controller.onSelectionCleared = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MathEditorInline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.onSelectionCleared = null;
      widget.controller.onSelectionCleared = _onSelectionCleared;
      widget.controller.setContainerKey(_containerKey);
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    debugPrint('=== _handlePointerDown ===');
    widget.onFocus?.call();

    // Always try to clear selection on pointer down
    if (widget.controller.hasSelection) {
      debugPrint('Has selection, clearing...');
      widget.controller.clearSelection();
    }

    // Also directly remove overlay in case callback didn't work
    if (_selectionOverlay != null) {
      debugPrint('Has overlay, removing...');
      _removeSelectionOverlay();
    }
  }

  void _handleTapDown(TapDownDetails details) {
    _lastTapDownPosition = details.localPosition;
  }

  void _handleTap() {
    _processTap();
  }

  void _handleTapUp(TapUpDetails details) {
    if (_lastTapDownPosition != null) {
      _lastTapDownPosition = details.localPosition;
      _processTap();
    }
  }

  void _processTap() {
    if (_lastTapDownPosition == null) return;

    final RenderBox? containerBox =
        _containerKey.currentContext?.findRenderObject() as RenderBox?;
    if (containerBox == null) {
      widget.controller.tapAt(_lastTapDownPosition!);
      _lastTapDownPosition = null;
      return;
    }

    final RenderBox? gestureBox = context.findRenderObject() as RenderBox?;
    if (gestureBox == null) {
      widget.controller.tapAt(_lastTapDownPosition!);
      _lastTapDownPosition = null;
      return;
    }

    final Offset globalTapPos = gestureBox.localToGlobal(_lastTapDownPosition!);
    final Offset localToContainer = containerBox.globalToLocal(globalTapPos);
    widget.controller.tapAt(localToContainer);

    _lastTapDownPosition = null;
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    widget.onFocus?.call();

    final RenderBox? containerBox =
        _containerKey.currentContext?.findRenderObject() as RenderBox?;
    if (containerBox == null) return;

    final RenderBox? gestureBox = context.findRenderObject() as RenderBox?;
    if (gestureBox == null) return;

    final Offset globalTapPos = gestureBox.localToGlobal(details.localPosition);
    final Offset localToContainer = containerBox.globalToLocal(globalTapPos);

    _doubleTapPosition = localToContainer;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.tapAt(localToContainer);
      }
    });
  }

  void _handleDoubleTap() {
    if (MathEditorController.clipboard != null &&
        !MathEditorController.clipboard!.isEmpty) {
      _showPasteOnlyOverlay();
    }
  }

  void _handleLongPress(LongPressStartDetails details) {
    widget.onFocus?.call();

    final RenderBox? containerBox =
        _containerKey.currentContext?.findRenderObject() as RenderBox?;
    if (containerBox == null) return;

    final RenderBox? gestureBox = context.findRenderObject() as RenderBox?;
    if (gestureBox == null) return;

    final Offset globalPos = gestureBox.localToGlobal(details.localPosition);
    final Offset localToContainer = containerBox.globalToLocal(globalPos);

    widget.controller.selectAtPosition(localToContainer);

    if (widget.controller.hasSelection) {
      _showSelectionOverlay();
    }
  }

  void _showSelectionOverlay() {
    _removeSelectionOverlay();

    _selectionOverlay = OverlayEntry(
      builder:
          (context) => SelectionOverlayWidget(
            controller: widget.controller,
            containerKey: _containerKey,
            cursorLocalPosition: null,
            onCopy: _handleCopy,
            onCut: _handleCut,
            onPaste: _handlePaste,
            onDismiss: _handleDismissSelection,
          ),
    );

    Overlay.of(context).insert(_selectionOverlay!);
  }

  void _showPasteOnlyOverlay() {
    _removeSelectionOverlay();

    _selectionOverlay = OverlayEntry(
      builder:
          (context) => SelectionOverlayWidget(
            controller: widget.controller,
            containerKey: _containerKey,
            cursorLocalPosition: _doubleTapPosition,
            onCopy: null,
            onCut: null,
            onPaste: _handlePaste,
            onDismiss: _handleDismissPasteMenu,
          ),
    );

    Overlay.of(context).insert(_selectionOverlay!);
  }

  void _removeSelectionOverlay() {
    debugPrint('=== _removeSelectionOverlay called ===');
    _selectionOverlay?.remove();
    _selectionOverlay = null;
    _doubleTapPosition = null;
  }

  void _handleCopy() {
    widget.controller.copySelection();
    _handleDismissSelection();
  }

  void _handleCut() {
    widget.controller.cutSelection();
    _removeSelectionOverlay();
  }

  void _handlePaste() {
    widget.controller.pasteClipboard();
    _removeSelectionOverlay();
  }

  void _handleDismissSelection() {
    widget.controller.clearSelection();
    _removeSelectionOverlay();
  }

  void showPasteMenu() {
    if (MathEditorController.clipboard != null &&
        !MathEditorController.clipboard!.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showPasteOnlyOverlay();
        }
      });
    }
  }

  void _handleDismissPasteMenu() {
    _removeSelectionOverlay();
  }

  void clearOverlay() {
    _removeSelectionOverlay();
  }

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (_lastStructureVersion != widget.controller.structureVersion) {
          _lastStructureVersion = widget.controller.structureVersion;
          widget.controller.clearLayoutRegistry();
        }

        if (widget.controller.hasSelection && _selectionOverlay != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _selectionOverlay?.markNeedsBuild();
          });
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            return Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _handlePointerDown,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: _handleTapDown,
                onTap: _handleTap,
                onTapUp: _handleTapUp,
                onDoubleTapDown: _handleDoubleTapDown,
                onDoubleTap: _handleDoubleTap,
                onLongPressStart: _handleLongPress,
                child: Container(
                  // Fill the entire available width
                  width:
                      constraints.maxWidth.isFinite
                          ? constraints.maxWidth
                          : null,
                  // Add minimum height to ensure tappable area
                  constraints: BoxConstraints(
                    minHeight: 40, // Minimum tappable height
                  ),
                  alignment: Alignment.center,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: KeyedSubtree(
                      key: _containerKey,
                      child: AnimatedBuilder(
                        animation: _cursorBlinkAnimation,
                        builder: (context, _) {
                          return MathRenderer(
                            expression: widget.controller.expression,
                            cursor: widget.controller.cursor,
                            cursorOpacity:
                                widget.showCursor
                                    ? _cursorBlinkAnimation.value
                                    : 0.0,
                            rootKey: _containerKey,
                            controller: widget.controller,
                            structureVersion:
                                widget.controller.structureVersion,
                            textScaler: textScaler,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Add this method for low-level pointer handling (more reliable on tablets)
}

class MathRenderer extends StatelessWidget {
  final List<MathNode> expression;
  final EditorCursor cursor;
  final double cursorOpacity;
  final GlobalKey rootKey;
  final MathEditorController controller;
  final int structureVersion;
  final TextScaler textScaler;

  const MathRenderer({
    super.key,
    required this.expression,
    required this.cursor,
    required this.cursorOpacity,
    required this.rootKey,
    required this.controller,
    required this.structureVersion,
    required this.textScaler,
  });

  static const double _nodePadding = 0.0;

  @override
  Widget build(BuildContext context) {
    // Split expression into lines
    List<_LineInfo> lines = _splitIntoLines(expression);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children:
          lines.asMap().entries.map((entry) {
            // int lineIndex = entry.key;
            _LineInfo lineInfo = entry.value;

            return Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children:
                    lineInfo.nodes.asMap().entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: _renderNode(
                          e.value,
                          lineInfo.startIndex + e.key, // Use global index
                          expression, // Pass full expression for sibling reference
                          null,
                          null,
                          FONTSIZE,
                        ),
                      );
                    }).toList(),
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
      final active =
          cursor.parentId == parentId &&
          cursor.path == path &&
          cursor.index == index;
      return LiteralWidget(
        key: ValueKey('${node.id}_$structureVersion'),
        node: node,
        active: active,
        cursorOpacity: cursorOpacity,
        subIndex: cursor.subIndex,
        fontSize: fontSize,
        isLast: index == siblings.length - 1,
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

      return Padding(
        padding: const EdgeInsets.only(right: _nodePadding),
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
                        children:
                            node.numerator
                                .asMap()
                                .entries
                                .map(
                                  (e) => _renderNode(
                                    e.value,
                                    e.key,
                                    node.numerator,
                                    node.id,
                                    'num',
                                    fontSize,
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  )
                  : Row(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        node.numerator
                            .asMap()
                            .entries
                            .map(
                              (e) => _renderNode(
                                e.value,
                                e.key,
                                node.numerator,
                                node.id,
                                'num',
                                fontSize,
                              ),
                            )
                            .toList(),
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
                        children:
                            node.denominator
                                .asMap()
                                .entries
                                .map(
                                  (e) => _renderNode(
                                    e.value,
                                    e.key,
                                    node.denominator,
                                    node.id,
                                    'den',
                                    fontSize,
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  )
                  : Row(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        node.denominator
                            .asMap()
                            .entries
                            .map(
                              (e) => _renderNode(
                                e.value,
                                e.key,
                                node.denominator,
                                node.id,
                                'den',
                                fontSize,
                              ),
                            )
                            .toList(),
                  ),
            ],
          ),
        ),
      );
    }

    if (node is ExponentNode) {
      final double powerSize = fontSize * 0.8;
      final double powerRaise = fontSize * 0.35;

      final bool baseEmpty = _isContentEmpty(node.base);
      final bool powerEmpty = _isContentEmpty(node.power);

      // Build base widget
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
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children:
                        node.base
                            .asMap()
                            .entries
                            .map(
                              (e) => _renderNode(
                                e.value,
                                e.key,
                                node.base,
                                node.id,
                                'base',
                                fontSize,
                              ),
                            )
                            .toList(),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children:
                    node.base
                        .asMap()
                        .entries
                        .map(
                          (e) => _renderNode(
                            e.value,
                            e.key,
                            node.base,
                            node.id,
                            'base',
                            fontSize,
                          ),
                        )
                        .toList(),
              );

      // Build power widget
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
                    children:
                        node.power
                            .asMap()
                            .entries
                            .map(
                              (e) => _renderNode(
                                e.value,
                                e.key,
                                node.power,
                                node.id,
                                'pow',
                                powerSize,
                              ),
                            )
                            .toList(),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                children:
                    node.power
                        .asMap()
                        .entries
                        .map(
                          (e) => _renderNode(
                            e.value,
                            e.key,
                            node.power,
                            node.id,
                            'pow',
                            powerSize,
                          ),
                        )
                        .toList(),
              );

      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Base
          baseWidget,
          // Power - raised using Transform
          Transform.translate(
            offset: Offset(0, -powerRaise),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: fontSize * 0.15,
                vertical: fontSize * 0.1,
              ),
              child: powerWidget,
            ),
          ),
        ],
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children:
                        node.content
                            .asMap()
                            .entries
                            .map(
                              (e) => _renderNode(
                                e.value,
                                e.key,
                                node.content,
                                node.id,
                                'content',
                                fontSize,
                              ),
                            )
                            .toList(),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children:
                    node.content
                        .asMap()
                        .entries
                        .map(
                          (e) => _renderNode(
                            e.value,
                            e.key,
                            node.content,
                            node.id,
                            'content',
                            fontSize,
                          ),
                        )
                        .toList(),
              );

      return IntrinsicHeight(
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
      );
    }

    if (node is TrigNode) {
      final bool argEmpty = _isContentEmpty(node.argument);

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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children:
                        node.argument
                            .asMap()
                            .entries
                            .map(
                              (e) => _renderNode(
                                e.value,
                                e.key,
                                node.argument,
                                node.id,
                                'arg',
                                fontSize,
                              ),
                            )
                            .toList(),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children:
                    node.argument
                        .asMap()
                        .entries
                        .map(
                          (e) => _renderNode(
                            e.value,
                            e.key,
                            node.argument,
                            node.id,
                            'arg',
                            fontSize,
                          ),
                        )
                        .toList(),
              );

      return Padding(
        padding: const EdgeInsets.only(right: _nodePadding),
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
                    children:
                        node.radicand
                            .asMap()
                            .entries
                            .map(
                              (e) => _renderNode(
                                e.value,
                                e.key,
                                node.radicand,
                                node.id,
                                'radicand',
                                fontSize,
                              ),
                            )
                            .toList(),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                children:
                    node.radicand
                        .asMap()
                        .entries
                        .map(
                          (e) => _renderNode(
                            e.value,
                            e.key,
                            node.radicand,
                            node.id,
                            'radicand',
                            fontSize,
                          ),
                        )
                        .toList(),
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
                      children:
                          node.index
                              .asMap()
                              .entries
                              .map(
                                (e) => _renderNode(
                                  e.value,
                                  e.key,
                                  node.index,
                                  node.id,
                                  'index',
                                  indexSize,
                                ),
                              )
                              .toList(),
                    ),
                  ),
                )
                : Row(
                  mainAxisSize: MainAxisSize.min,
                  children:
                      node.index
                          .asMap()
                          .entries
                          .map(
                            (e) => _renderNode(
                              e.value,
                              e.key,
                              node.index,
                              node.id,
                              'index',
                              indexSize,
                            ),
                          )
                          .toList(),
                );
      }

      return Padding(
        padding: const EdgeInsets.only(right: _nodePadding),
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
                      children:
                          node.base
                              .asMap()
                              .entries
                              .map(
                                (e) => _renderNode(
                                  e.value,
                                  e.key,
                                  node.base,
                                  node.id,
                                  'base',
                                  baseSize,
                                ),
                              )
                              .toList(),
                    ),
                  ),
                )
                : Row(
                  mainAxisSize: MainAxisSize.min,
                  children:
                      node.base
                          .asMap()
                          .entries
                          .map(
                            (e) => _renderNode(
                              e.value,
                              e.key,
                              node.base,
                              node.id,
                              'base',
                              baseSize,
                            ),
                          )
                          .toList(),
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children:
                        node.argument
                            .asMap()
                            .entries
                            .map(
                              (e) => _renderNode(
                                e.value,
                                e.key,
                                node.argument,
                                node.id,
                                'arg',
                                fontSize,
                              ),
                            )
                            .toList(),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children:
                    node.argument
                        .asMap()
                        .entries
                        .map(
                          (e) => _renderNode(
                            e.value,
                            e.key,
                            node.argument,
                            node.id,
                            'arg',
                            fontSize,
                          ),
                        )
                        .toList(),
              );

      return Padding(
        padding: const EdgeInsets.only(right: _nodePadding),
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

            // Subscript base - uses Transform for vertical offset only
            // Width is still part of layout flow
            if (!node.isNaturalLog && baseWidget != null)
              Transform.translate(
                offset: Offset(0, fontSize * 0.6), // Vertical subscript offset
                child: Padding(
                  padding: EdgeInsets.only(
                    left: fontSize * 0.02, // Small gap after "log"
                    right: fontSize * 0.08, // Gap before parentheses
                  ),
                  child: baseWidget,
                ),
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
                    children:
                        node.n
                            .asMap()
                            .entries
                            .map(
                              (e) => _renderNode(
                                e.value,
                                e.key,
                                node.n,
                                node.id,
                                'n',
                                smallSize,
                              ),
                            )
                            .toList(),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                children:
                    node.n
                        .asMap()
                        .entries
                        .map(
                          (e) => _renderNode(
                            e.value,
                            e.key,
                            node.n,
                            node.id,
                            'n',
                            smallSize,
                          ),
                        )
                        .toList(),
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
                    children:
                        node.r
                            .asMap()
                            .entries
                            .map(
                              (e) => _renderNode(
                                e.value,
                                e.key,
                                node.r,
                                node.id,
                                'r',
                                smallSize,
                              ),
                            )
                            .toList(),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                children:
                    node.r
                        .asMap()
                        .entries
                        .map(
                          (e) => _renderNode(
                            e.value,
                            e.key,
                            node.r,
                            node.id,
                            'r',
                            smallSize,
                          ),
                        )
                        .toList(),
              );

      return Padding(
        padding: const EdgeInsets.only(right: _nodePadding),
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
                    children:
                        node.n
                            .asMap()
                            .entries
                            .map(
                              (e) => _renderNode(
                                e.value,
                                e.key,
                                node.n,
                                node.id,
                                'n',
                                smallSize,
                              ),
                            )
                            .toList(),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                children:
                    node.n
                        .asMap()
                        .entries
                        .map(
                          (e) => _renderNode(
                            e.value,
                            e.key,
                            node.n,
                            node.id,
                            'n',
                            smallSize,
                          ),
                        )
                        .toList(),
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
                    children:
                        node.r
                            .asMap()
                            .entries
                            .map(
                              (e) => _renderNode(
                                e.value,
                                e.key,
                                node.r,
                                node.id,
                                'r',
                                smallSize,
                              ),
                            )
                            .toList(),
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                children:
                    node.r
                        .asMap()
                        .entries
                        .map(
                          (e) => _renderNode(
                            e.value,
                            e.key,
                            node.r,
                            node.id,
                            'r',
                            smallSize,
                          ),
                        )
                        .toList(),
              );

      return Padding(
        padding: const EdgeInsets.only(right: _nodePadding),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // n (superscript position)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [nWidget, SizedBox(height: fontSize * 1)],
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
      return Padding(
        padding: const EdgeInsets.only(right: _nodePadding),
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
                children:
                    node.index
                        .asMap()
                        .entries
                        .map(
                          (e) => _renderNode(
                            e.value,
                            e.key,
                            node.index,
                            node.id,
                            'index',
                            fontSize, // <-- Same size, not smaller
                          ),
                        )
                        .toList(),
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
}

class LiteralWidget extends StatefulWidget {
  final LiteralNode node;
  final bool active;
  final double cursorOpacity;
  final int subIndex;
  final double fontSize;
  final bool isLast;
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
    required this.active,
    required this.cursorOpacity,
    required this.subIndex,
    required this.fontSize,
    required this.isLast,
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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reportLayoutIfNeeded(),
    );
  }

  @override
  void didUpdateWidget(covariant LiteralWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.structureVersion != widget.structureVersion ||
        oldWidget.node.id != widget.node.id ||
        oldWidget.node.text != widget.node.text ||
        oldWidget.parentId != widget.parentId ||
        oldWidget.path != widget.path ||
        oldWidget.index != widget.index ||
        oldWidget.fontSize != widget.fontSize) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _reportLayoutIfNeeded(),
      );
    }
  }

  void _reportLayoutIfNeeded() {
    if (!mounted) return;
    if (_lastReportedVersion == widget.structureVersion) return;
    _lastReportedVersion = widget.structureVersion;

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;

    final RenderBox? rootBox =
        widget.rootKey.currentContext?.findRenderObject() as RenderBox?;
    if (rootBox == null) return;

    final Offset globalPos = box.localToGlobal(Offset.zero);
    final Offset relativePos = rootBox.globalToLocal(globalPos);
    final rect = relativePos & box.size;

    // Get the RenderParagraph from the Text widget
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
        renderParagraph: renderParagraph, // ADD THIS
      ),
    );
  }

  double _getCursorOffsetFromRenderParagraph(
    String logicalText,
    String displayText,
  ) {
    if (logicalText.isEmpty || widget.subIndex <= 0) return 0.0;

    final displayIndex = MathTextStyle.logicalToDisplayIndex(
      logicalText,
      widget.subIndex,
    ).clamp(0, displayText.length);

    // Try to get RenderParagraph from the Text widget
    final renderObject = _textKey.currentContext?.findRenderObject();
    if (renderObject is RenderParagraph) {
      final offset = renderObject.getOffsetForCaret(
        TextPosition(offset: displayIndex),
        Rect.zero,
      );
      return offset.dx;
    }

    // Fallback to TextPainter (should rarely happen)
    final painter = TextPainter(
      text: TextSpan(
        text: displayText,
        style: MathTextStyle.getStyle(
          widget.fontSize,
        ).copyWith(color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
      textScaler: widget.textScaler,
    )..layout();

    final offset = painter.getOffsetForCaret(
      TextPosition(offset: displayIndex),
      Rect.zero,
    );
    painter.dispose();
    return offset.dx;
  }

  @override
  Widget build(BuildContext context) {
    final logicalText = widget.node.text;
    final showCursor = widget.active && widget.cursorOpacity > 0.5;

    final isEmpty = logicalText.isEmpty;
    final displayText = isEmpty ? "" : MathTextStyle.toDisplayText(logicalText);

    final cursorWidth = math.max(2.0, widget.fontSize * 0.06);

    double cursorOffset = 0.0;

    return StatefulBuilder(
      builder: (context, setInnerState) {
        if (showCursor && !isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final newOffset = _getCursorOffsetFromRenderParagraph(
              logicalText,
              displayText,
            );
            if (newOffset != cursorOffset && mounted) {
              setInnerState(() {
                cursorOffset = newOffset;
              });
            }
          });
        }

        if (isEmpty) {
          return SizedBox(
            width: cursorWidth,
            height: widget.fontSize,
            child:
                showCursor
                    ? Container(
                      width: cursorWidth,
                      height: widget.fontSize,
                      color: Colors.yellowAccent,
                    )
                    : null,
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Text(
              key: _textKey,
              displayText,
              style: MathTextStyle.getStyle(
                widget.fontSize,
              ).copyWith(color: Colors.white),
              textScaler: widget.textScaler,
            ),
            if (showCursor)
              Positioned(
                left: _getCursorOffsetFromRenderParagraph(
                  logicalText,
                  displayText,
                ),
                top: 0,
                bottom: 0,
                child: Container(
                  width: cursorWidth,
                  color: Colors.yellowAccent,
                ),
              ),
          ],
        );
      },
    );
  }
}

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

  ComplexNodeInfo({
    required this.node,
    required this.parentId,
    required this.path,
    required this.index,
  });
}

class NodeLayoutInfo {
  final Rect rect;
  final LiteralNode node;
  final String? parentId;
  final String? path;
  final int index;
  final double fontSize;
  final TextScaler textScaler;
  final RenderParagraph? renderParagraph; // ADD THIS

  NodeLayoutInfo({
    required this.rect,
    required this.node,
    required this.parentId,
    required this.path,
    required this.index,
    required this.fontSize,
    required this.textScaler,
    this.renderParagraph, // ADD THIS
  });
}


/// Helper class to track line info
class _LineInfo {
  final List<MathNode> nodes;
  final int startIndex;

  _LineInfo({required this.nodes, required this.startIndex});
}


